# Informe Técnico: Implementación de Arquitectura Offline-First
## Club ERP System — Sincronización Supabase + PowerSync + Flutter

| Campo | Detalle |
|---|---|
| **Proyecto** | `club_erp_system` |
| **Módulo** | Núcleo de Base de Datos Local (`lib/core/local_db/`) |
| **Fecha** | 2026-10-13 |
| **Stack** | Flutter (Dart) + SQLite (PowerSync SDK 2.4) + Supabase 2.18.2 |
| **Paradigma** | Offline-First con SSOT en PostgreSQL |

---

## 1. Resumen Ejecutivo

Se implementó la capa de sincronización bidireccional entre la base de datos local SQLite (gestionada por PowerSync) y el backend PostgreSQL alojado en Supabase. La arquitectura garantiza que un terminal POS de punto de venta pueda operar al 100% sin conexión a internet — incluyendo creación de órdenes, turnos de caja y registros de pago — y que los datos se sincronicen automáticamente cuando la conectividad se restaure.

La implementación abarca tres archivos críticos del núcleo:
- **`schema.dart`** — Esquema declarativo local (12 tablas, indexación optimizada)
- **`powersync_helper.dart`** — Orquestador Singleton con control de ciclo de vida
- **`supabase_connector.dart`** — Puente de autenticación JWT y subida resiliente de datos

---

## 2. Arquitectura Backend Implementada

### 2.1 DDL en PostgreSQL (Supabase)

El equipo de Backend configuró Supabase como la **Única Fuente de Verdad (SSOT)** con las siguientes decisiones arquitectónicas:

| Decisión | Implementación |
|---|---|
| **Eliminación de `gen_random_uuid()`** | Se removió `DEFAULT gen_random_uuid()` de todas las columnas `id` en el DDL. El cliente Flutter es **obligado** a generar UUIDs v4 localmente antes de persistir cualquier registro. |
| **UUID v4 como PK universal** | Todas las 12 tablas usan `id UUID PRIMARY KEY` sin defaults de servidor. Esto elimina colisiones entre dispositivos offline. |
| **Soft Delete universal** | Todas las tablas usan `deleted_at TIMESTAMPTZ` en lugar de `DELETE` destructivos. |
| **Inmutabilidad financiera** | `order_items.unit_price`, `order_item_modifiers.unit_price` y `payments.exchange_rate` son copias congeladas al momento de la transacción. |

### 2.2 Retención Asimétrica de 15 Días (`is_archived`)

Una tarea programada en PostgreSQL vía `pg_cron` ejecuta periódicamente:

```sql
-- Pseudocódigo de la tarea pg_cron
UPDATE orders SET is_archived = TRUE 
WHERE created_at < NOW() - INTERVAL '15 days';
-- (Análogo para order_items, order_item_modifiers, payments, cash_sessions)
```

**Efecto en la sincronización:** Las reglas de filtrado YAML del puente PowerSync excluyen registros con `is_archived = TRUE` de la sincronización hacia los terminales POS locales, evitando la saturación de almacenamiento en dispositivos de caja.

**Tablas afectadas:**
- `cash_sessions`
- `orders`
- `order_items`
- `order_item_modifiers`
- `payments`

### 2.3 Reglas de Sincronización PowerSync (YAML)

El puente de PowerSync está configurado con un YAML estático que:
1. Filtra registros donde `is_archived = FALSE` (o `NULL`) para sincronización descendente.
2. Acepta escrituras ascendentes sin restricción — la cola CRUD local sube todos los cambios pendientes.
3. Define las 12 tablas como entidades sincronizadas bidireccionalmente.

---

## 3. Arquitectura Frontend Implementada

### 3.1 Esquema Local (`schema.dart`)

**Archivo:** `lib/core/local_db/schema.dart`

Se definieron 12 tablas en el SDK de PowerSync con simetría estricta respecto al DDL de producción:

| Tabla | Tipo | `is_archived` | Índices |
|---|---|---|---|
| `roles` | Catálogo | ❌ | — |
| `employees` | Catálogo | ❌ | — |
| `categories` | Catálogo | ❌ | — |
| `products` | Catálogo | ❌ | `category_id`, `is_active` |
| `modifiers` | Catálogo | ❌ | — |
| `exchange_rates` | Operativa | ❌ | — |
| `cash_sessions` | **Transaccional** | ✅ | `status`, `employee_id` |
| `orders` | **Transaccional** | ✅ | `status`, `employee_id`, `cash_session_id`, `is_archived`, `created_at` |
| `order_items` | **Transaccional** | ✅ | — |
| `order_item_modifiers` | **Transaccional** | ✅ | — |
| `payment_methods` | Catálogo | ❌ | — |
| `payments` | **Transaccional** | ✅ | `order_id`, `status`, `is_archived` |

**Reglas de mapeo aplicadas:**
- `TIMESTAMPTZ` → `Column.text()` (ISO-8601 UTC)
- `NUMERIC/DECIMAL` → `Column.real()` (IEEE 754 double)
- `BOOLEAN` → `Column.integer()` (0/1)
- `VARCHAR/TEXT` → `Column.text()`
- La columna `id` **nunca** se declara manualmente (PowerSync la inyecta automáticamente)

**Correcciones aplicadas respecto al esquema anterior:**
1. Eliminados `initial_balance` y `final_balance` de `cash_sessions` (no existían en el DDL).
2. Agregados a `cash_sessions`: `created_at`, `updated_at`, `deleted_at`, `is_archived`.
3. Agregados a `payments`: `exchange_rate`, `reference_number`, `status`, `created_at`, `updated_at`, `deleted_at`, `is_archived`.
4. Reemplazado `subtotal` por `unit_price` en `order_item_modifiers` (alineado con DDL).
5. Eliminado `subtotal` de `order_items` (el subtotal se calcula como `unit_price × quantity`).
6. Agregadas columnas `created_at`, `updated_at`, `deleted_at` a `order_items`.

### 3.2 Singleton `PowerSyncHelper` (`powersync_helper.dart`)

**Archivo:** `lib/core/local_db/powersync_helper.dart`

#### Patrón Singleton Implementado

```dart
class PowerSyncHelper {
  static final PowerSyncHelper instance = PowerSyncHelper._internal();
  factory PowerSyncHelper() => instance;
  PowerSyncHelper._internal();
}
```

#### Control de Inicialización Idempotente (Completer)

Se implementó un `Completer<void>` que garantiza:
- **Primera invocación de `initialize()`:** Ejecuta la inicialización completa.
- **Invocaciones subsecuentes:** Retornan el mismo `Future` ya completado (o en curso).
- **Invocaciones concurrentes:** Todas esperan al mismo `Completer`, evitando fugas de descriptores de archivo o apertura duplicada de SQLite.

#### Accesores con Guard de Estado

Los getters `database` y `supabase` lanzan `StateError` si se accede antes de `initialize()`, garantizando *fail-fast* en tiempo de desarrollo:

```dart
PowerSyncDatabase get database {
  if (!_isInitialized) throw StateError('No inicializado');
  return _db;
}
```

#### Stream de Observabilidad

Se exponen dos APIs para que los widgets de UI muestren el estado de sincronización:

```dart
Stream<SyncStatus> get statusStream => _db.statusStream;
SyncStatus get currentStatus => _db.currentStatus;
```

`SyncStatus` provee: `connected`, `connecting`, `downloading`, `uploading`, `synced`, `lastSyncedAt`, `anyError`.

#### Suscripción Reactiva a `onAuthStateChange`

El `PowerSyncHelper` registra un listener sobre los eventos de autenticación de Supabase:

| Evento | Acción |
|---|---|
| `signedIn` | `connector.prefetchCredentials()` — Fuerza obtención de JWT fresco |
| `tokenRefreshed` | `connector.prefetchCredentials()` — Actualiza credenciales en PowerSync |
| `signedOut` | `await db.disconnect()` — Desconecta sincronización ordenadamente |

### 3.3 Conector de Supabase (`supabase_connector.dart`)

**Archivo:** `lib/core/local_db/supabase_connector.dart`

#### Inyección Segura del JWT (`fetchCredentials`)

1. Verifica `supabase.auth.currentSession` — si es `null`, retorna `null` (PowerSync queda en espera pasiva sin excepciones).
2. Evalúa `session.isExpired` — si está expirado, invoca `supabase.auth.refreshSession()` para obtener un token fresco.
3. Si el refresco falla, intenta con el token actual y deja que PowerSync maneje el rechazo del servidor.

#### CORRECCIÓN CRÍTICA en `uploadData` (Bug Catastrófico Resuelto)

**Problema original:**
```dart
// ❌ CÓDIGO ANTERIOR — BUG CATASTRÓFICO
try {
  // ... operaciones de subida ...
} catch (e) {
  debugPrint('Error: $e'); // Atrapaba silenciosamente
}
await batch.complete(); // EJECUTABA SIEMPRE, incluso tras errores
```

**Problema:** Si la red fallaba durante la subida, el `catch` silencioso atrapaba la excepción pero `batch.complete()` se ejecutaba de todas formas, **descartando permanentemente las mutaciones locales no sincronizadas** de la cola CRUD de PowerSync.

**Corrección implementada:**
```dart
// ✅ CÓDIGO NUEVO — RESILIENCIA CORRECTA
try {
  for (var op in transaction.crud) {
    // ... operaciones de subida ...
  }
  await transaction.complete(); // SOLO si todo fue exitoso
} catch (e, stackTrace) {
  debugPrint('Error: $e');
  rethrow; // PowerSync retiene la transacción y reintenta con backoff
}
```

**Cambio adicional:** Se migró de `getCrudBatch()` a `getNextCrudTransaction()` para garantizar atomicidad transaccional — todas las operaciones del lote se suben o ninguna se marca como completada.

### 3.4 Estrategia de Seeding Offline

El método `_seedInitialData()` en `PowerSyncHelper`:
1. Verifica atómicamente si la DB está virgen: `SELECT count(*) FROM roles`.
2. Genera **exclusivamente** UUIDs v4 con `Uuid().v4()` — cero valores estáticos.
3. Incluye timestamps `created_at` y `updated_at` en formato ISO-8601 UTC.
4. Inserta 2 roles (`CAJERA`, `ENCARGADA`) y 2 empleados con PIN de prueba.

---

## 4. Matriz de Resiliencia ante Contingencias

| Escenario | Comportamiento del Sistema | Impacto en el Usuario |
|---|---|---|
| **(a) Corte total de internet** | PowerSync opera al 100% offline. Todas las órdenes, pagos y turnos se persisten en SQLite local. La cola CRUD acumula mutaciones pendientes. `db.connect()` queda en reintento pasivo sin bloquear la UI. | **Cero impacto.** El terminal POS sigue operativo. Los datos se sincronizan cuando regrese la conexión. |
| **(b) JWT expirado a mitad de jornada** | `fetchCredentials()` detecta `session.isExpired` e invoca `refreshSession()` automáticamente. Si el refresco falla por falta de red, PowerSync retiene la cola y reintenta. El listener de `tokenRefreshed` fuerza `prefetchCredentials()` cuando Supabase renueva el token. | **Transparente.** La sincronización se reanuda automáticamente sin intervención del usuario. |
| **(c) Caída del servidor Supabase** | `uploadData()` falla al intentar subir a Supabase. La excepción se relanza (`rethrow`). PowerSync retiene la transacción en la cola local y aplica **exponential backoff** automático para reintentos. Datos locales permanecen intactos. | **Cero impacto en operaciones locales.** La sincronización se reanuda cuando Supabase vuelva. |
| **(d) Reconexión tras corte prolongado** | PowerSync detecta conectividad restaurada. Descarga cambios del servidor (registros nuevos de otros terminales). Sube toda la cola CRUD acumulada en orden FIFO. `statusStream` emite `uploading: true` → `synced: true`. | El terminal se actualiza automáticamente. Los widgets que observen `statusStream` reflejan el progreso de sincronización. |
| **(e) Doble inicialización (hot reload)** | El `Completer<void>` en `initialize()` previene re-apertura de la DB. Invocaciones subsecuentes retornan inmediatamente. | **Sin impacto.** No hay fugas de descriptores de archivo ni estados duplicados. |

---

## 5. Conclusión y Próximos Pasos

### Lo Construido
Se consolidó exitosamente la capa de infraestructura Offline-First del Club ERP System, con:
- Esquema local alineado al 100% con el DDL de producción (12 tablas, 5 con retención asimétrica).
- Singleton robusto con inicialización idempotente y fail-fast.
- Conector con gestión proactiva de JWT y subida resiliente de datos.
- Eliminación de un bug catastrófico que descartaba silenciosamente transacciones no sincronizadas.

### Próximos Pasos Recomendados

1. **Repositorios de Datos (`lib/features/*/data/`):**
   - Implementar `OrderRepositoryImpl`, `PaymentRepositoryImpl`, `CashSessionRepositoryImpl` usando `PowerSyncHelper.instance.database` como fuente de datos.
   - Toda escritura debe generar `Uuid().v4()` para el `id` y `DateTime.now().toUtc().toIso8601String()` para timestamps.
   - Borrados deben ser lógicos: `UPDATE SET deleted_at = ?`.

2. **Variables de Entorno:**
   - Extraer `url`, `publishableKey` y `powersyncUrl` a un archivo `.env` o configuración por entorno (`flutter_dotenv`), eliminando las credenciales hardcodeadas.

3. **Widget de Estado de Sincronización:**
   - Consumir `PowerSyncHelper.instance.statusStream` en un widget de la barra de estado para mostrar iconos de conectividad (🟢 Online / 🔴 Offline / 🔄 Sincronizando).

4. **Testing:**
   - Escribir tests unitarios para `SupabaseConnector.uploadData()` verificando que excepciones de red propaguen correctamente (nunca `batch.complete()` tras fallo).
   - Tests de integración para el flujo completo: escritura offline → reconexión → sincronización.

5. **Módulo QR P2P (Contingencia Offline):**
   - Implementar el flujo de validación criptográfica de pagos mediante códigos QR con HMAC SHA-256, según lo descrito en `AI_CONTEXT.md`.

---

> **Documento generado automáticamente como parte del entregable contractual del flujo de implementación de arquitectura Offline-First.**
