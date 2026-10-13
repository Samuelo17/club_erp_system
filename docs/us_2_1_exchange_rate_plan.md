# Plan de Implementación: US-2.1 — Gestor de Tasa de Cambio Diaria

> **Historia de Usuario:** US-2.1 (Gestor de Tasa de Cambio Diaria)  
> **Rol:** Encargada / Administrador  
> **Acción:** Registrar la tasa de cambio oficial/operativa del día.  
> **Valor:** Que la caja (POS) calcule con total precisión los montos en bolívares (VES), preservando el historial inmutable para auditorías y transacciones pasadas.  
> **Arquitectura:** Clean Architecture (Feature-First) + Offline-First (PowerSync + SQLite).  
> **Guía de Estilos:** [UI_STYLE_GUIDE.md](../GUIDE/UI_STYLE_GUIDE.md).

---

## 1. Visión y Flujo Arquitectónico

```
                       ┌─────────────────────────┐
                       │   Encargada (Admin/UI)  │
                       └────────────┬────────────┘
                                    │ Registra nueva tasa (INSERT)
                                    ▼
                       ┌─────────────────────────┐
                       │  exchange_rates (SQLite)│
                       └────────────┬────────────┘
                                    │ db.watch() (Stream reactivo local)
                                    ▼
                       ┌─────────────────────────┐
                       │  ExchangeRateProvider   │
                       └────────────┬────────────┘
                                    │ notifyListeners()
                                    ▼
       ┌────────────────────────────────────────────────────────┐
       │                 POS / Terminal de Cobro                 │
       │  • Catálogo muestra precios en VES (USD × Tasa)        │
       │  • Carrito y Checkout recalculan total en VES al vuelo │
       └────────────────────────────────────────────────────────┘
```

---

## 2. Estrategia de Reactividad y State Management (Offline-First)

En una arquitectura Offline-First no dependemos de llamadas de red ni de WebSockets remotos para actualizar la interfaz. Aprovechamos la reactividad nativa de **PowerSync**:

1. **`db.watch(...)` sobre SQLite:**
   PowerSync expone el método reactivo `watch(sql, parameters)` que emite una nueva lista de filas cada vez que la tabla `exchange_rates` sufre cualquier cambio (inserción local o sincronización en background).
2. **Suscripción Reactiva en `ExchangeRateProvider`:**
   El provider escucha el Stream proveniente del caso de uso `WatchLatestExchangeRateUseCase`. Al emitirse una nueva tasa, actualiza su estado interno y ejecuta `notifyListeners()`.
3. **Consumo Desacoplado en el POS:**
   Tanto la barra de resumen del carrito (`CartSummaryBar`), los modales de cobro y el encabezado del terminal consumen `ExchangeRateProvider`. En el instante en que la encargada guarda una tasa, el POS reacciona **sin recargar la pantalla y sin conexión a internet**.

---

## 3. Desglose Arquitectónico por Capas (Clean Architecture)

El módulo se organizará dentro del paquete `lib/features/exchange_rate/`:

### A. Capa de Dominio (`domain/`)
*Lógica pura de negocio, agnóstica a frameworks y librerías externas.*

* **Entidad `ExchangeRate` (`domain/entities/exchange_rate.dart`):**
  * `id`: String (UUIDv4).
  * `rateValue`: double (Valor numérico positivo de la tasa, ej. `81.4500`).
  * `createdBy`: String (UUID del empleado/encargada que registró la tasa).
  * `createdAt`: DateTime (Marca de tiempo UTC).
  * `updatedAt`: DateTime? (Opcional para auditoría).
* **Contrato del Repositorio (`domain/repositories/exchange_rate_repository.dart`):**
  * `Future<void> saveExchangeRate(ExchangeRate rate)`: Inserta un nuevo registro.
  * `Future<ExchangeRate?> getLatestExchangeRate()`: Lectura puntual.
  * `Stream<ExchangeRate?> watchLatestExchangeRate()`: Flujo continuo reactivo.
* **Casos de Uso (`domain/usecases/`):**
  * `SaveExchangeRateUseCase`: Valida que `rateValue > 0` y que `createdBy` no esté vacío antes de delegar al repositorio.
  * `GetLatestExchangeRateUseCase`: Consulta la última tasa registrada.
  * `WatchLatestExchangeRateUseCase`: Expone el Stream reactivo de la tasa activa.

---

### B. Capa de Datos (`data/`)
*Persistencia física en SQLite mediante el orquestador PowerSync.*

* **Modelo `ExchangeRateModel` (`data/models/exchange_rate_model.dart`):**
  * Hereda o mapea hacia `ExchangeRate`.
  * Serialización: `fromMap(Map<String, dynamic>)` y `toMap()`.
  * Normalización: Conversión precisa de tipos SQLite (`REAL` $\leftrightarrow$ `double`, `TEXT` ISO-8601 $\leftrightarrow$ `DateTime`).
* **Implementación del Repositorio (`data/repositories_impl/exchange_rate_repository_impl.dart`):**
  * **Regla Inquebrantable de Inmutabilidad:** Solo se ejecutan operaciones `INSERT INTO exchange_rates ...`. **Nunca `UPDATE`**, garantizando auditoría histórica inmutable.
  * **Generación de ID en Cliente:** Se genera un `Uuid().v4()` por cada tasa registrada.
  * **Query Principal:**
    ```sql
    SELECT id, rate_value, created_by, created_at, updated_at 
    FROM exchange_rates 
    WHERE deleted_at IS NULL 
    ORDER BY created_at DESC 
    LIMIT 1;
    ```
  * **Stream Reactivo:** Conecta `db.watch(...)` usando la misma query descrita.

---

### C. Capa de Presentación (`presentation/`)
*Interfaz de usuario táctil ergonómica y gestión de estado con Provider.*

* **State Management (`presentation/providers/exchange_rate_provider.dart`):**
  * Expone:
    * `currentRate`: `ExchangeRate?` (tasa activa).
    * `rateValue`: `double` (valor numérico directo, con fallback por defecto si no hay registro aún).
    * `isLoading`: `bool`.
    * `isSaving`: `bool`.
    * `errorMessage`: `String?`.
  * Métodos:
    * `init()`: Inicia la suscripción reactiva a `watchLatestExchangeRateUseCase`.
    * `registerRate(double value, String employeeId)`: Ejecuta el caso de uso para guardar la nueva tasa.
* **Dashboard de la Encargada (`presentation/pages/exchange_rate_dashboard_page.dart`):**
  * **Fondo y Tarjetas:** Fondo gris claro (`#F5F5F7`), tarjetas de información blancas (`#FFFFFF`) con bordes redondeados (`borderRadius: 12.0`) y sombras suaves (`boxShadow`).
  * **Tarjeta de Tasa Actual:** Muestra con tipografía grande y negrita la tasa vigente y la hora/fecha del último registro.
  * **Formulario Táctil:**
    * Input numérico decimal grande, adaptado a teclado virtual numérico (`TextInputType.numberWithOptions(decimal: true)`).
    * Botón de acción principal: **Naranja Vibrante (`#FFFF8C00`)** con texto blanco en negrita, altura táctil mínima de 52px y animación de guardado.

---

## 4. Inventario Exacto de Archivos

### Archivos Nuevos a Crear:
```text
lib/features/exchange_rate/
├── domain/
│   ├── entities/
│   │   └── exchange_rate.dart
│   ├── repositories/
│   │   └── exchange_rate_repository.dart
│   └── usecases/
│       ├── get_latest_exchange_rate_usecase.dart
│       ├── watch_latest_exchange_rate_usecase.dart
│       └── save_exchange_rate_usecase.dart
├── data/
│   ├── models/
│   │   └── exchange_rate_model.dart
│   └── repositories_impl/
│       └── exchange_rate_repository_impl.dart
└── presentation/
    ├── providers/
    │   └── exchange_rate_provider.dart
    └── pages/
        └── exchange_rate_dashboard_page.dart
```

### Archivos Existentes a Modificar:
1. `lib/main.dart`:
   * Registrar `ExchangeRateProvider` en el `MultiProvider` global.
2. `lib/features/pos/presentation/pages/pos_page.dart`:
   * Incorporar en el `AppBar` un chip indicador con la tasa actual y acceso directo al Dashboard de Tasa para la Encargada.
3. `lib/features/pos/presentation/widgets/cart_summary_bar.dart` (y modales asociados):
   * Reflejar la conversión dual dinámica: **USD $XX.XX / Bs. XXX.XX** utilizando la tasa provista en tiempo real por el `ExchangeRateProvider`.

---

## 5. Fases de Ejecución Paso a Paso

* [x] **Fase 1: Capa de Dominio**
  * Crear la entidad `ExchangeRate`.
  * Definir la interfaz abstracta `ExchangeRateRepository`.
  * Implementar los tres casos de uso (`GetLatest`, `WatchLatest`, `Save`).
* [x] **Fase 2: Capa de Datos**
  * Crear `ExchangeRateModel` con deserialización segura de SQLite.
  * Implementar `ExchangeRateRepositoryImpl` integrando `PowerSyncHelper.instance.database` y `db.watch()`.
* [x] **Fase 3: Gestión de Estado (Provider)**
  * Crear `ExchangeRateProvider` con escucha reactiva del Stream.
  * Registrar la inyección en `lib/main.dart`.
* [x] **Fase 4: Pantalla Dashboard (Encargada)**
  * Construir `ExchangeRateDashboardPage` cumpliendo la guía de estilos visuales.
* [x] **Fase 5: Integración Reactiva con el POS**
  * Mostrar el chip de tasa en `PosPage`.
  * Conectar el cálculo en Bolívares en el carrito de compras.
