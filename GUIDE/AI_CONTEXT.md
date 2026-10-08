# Contexto Maestro y Reglas de Arquitectura (Para Agentes IA)

## 🤖 Instrucciones para la IA
Si eres un agente de Inteligencia Artificial (Copilot, Cursor, Antigravity, etc.) leyendo este archivo: tu objetivo es actuar como un **Arquitecto de Software Senior y Desarrollador Flutter Experto**. Debes apegarte estrictamente a las reglas descritas en este documento antes de proponer, modificar o generar cualquier bloque de código.

---

## 1. Visión General del Proyecto
*   **Nombre del Proyecto:** Club ERP System (`club_erp_system`).
*   **Objetivo Inicial (MVP):** Un sistema de Punto de Venta (POS) y gestión de cocina para un club de piscina.
*   **Escalabilidad:** Está diseñado para convertirse a largo plazo en un ERP completo (membresías, inventario, administración).
*   **Entorno Operativo Crítico:** El sistema operará en Venezuela. Debe soportar **transacciones multimoneda** (USD y VES) y, lo más importante, debe tolerar **cortes de luz e internet prolongados**. 
*   **Paradigma Principal:** Estrictamente **Offline-First**.

---

## 2. Stack Tecnológico
*   **Frontend y Móvil:** Flutter (Dart).
*   **Base de Datos Local (Motor Offline):** SQLite.
*   **Backend y Cloud DB:** Supabase (PostgreSQL).
*   **Sincronización:** PowerSync (Se encarga de sincronizar SQLite con Supabase automáticamente).
*   **Criptografía y Contingencia:** Paquetes nativos `qr_flutter`, `mobile_scanner` y `crypto` (HMAC SHA-256) para validación de pagos P2P sin internet.

---

## 3. Arquitectura del Código (Feature-First Clean Architecture)
El proyecto no organiza los archivos por tipo (no hay una carpeta global de "screens" o "models"). Se organiza por **Módulos de Negocio (Features)**.

*   `lib/core/`: Contiene infraestructura compartida, clientes de base de datos (`local_db`), utilidades, manejo de errores y temas (`UI_STYLE_GUIDE.md`).
*   `lib/features/`: Contiene los módulos independientes (ej. `pos`, `kitchen`, `admin`).
    *   Cada feature debe tener estrictamente 3 capas:
        *   `domain/` (entities, abstract repositories, use cases).
        *   `data/` (models, repository implementations, datasources locales y remotos).
        *   `presentation/` (pages, widgets, state management).

**Regla de IA:** Siempre debes implementar la lógica empezando por `Domain`, luego `Data`, y finalmente `Presentation`.

---

## 4. Reglas de Base de Datos y Lógica de Negocio (INQUEBRANTABLES)

1.  **Solo UUIDs v4:** Está estrictamente prohibido usar IDs autoincrementales (`1, 2, 3`). Todas las llaves primarias de las entidades deben ser UUIDs generados localmente para evitar colisiones al sincronizar la base de datos offline con la nube.
2.  **Inmutabilidad Financiera:** Las tablas y modelos transaccionales (como `OrderItem` o `Payment`) deben guardar una copia del precio exacto del producto y de la **tasa de cambio activa** en el instante exacto de la compra. Si la tasa o el precio base cambian en el futuro, las órdenes pasadas NO deben verse afectadas.
3.  **Relación de Pagos (1:N):** Una orden (`Order`) puede tener múltiples pagos (`Payments`) asociados. No existen columnas estáticas como `monto_efectivo` en la orden; todo pago es un registro individual con su propio método de pago (Efectivo, Pago Móvil, POS).
4.  **Soft Deletes (Borrado Lógico):** Nunca utilices comandos o métodos que hagan `DELETE` físico en la base de datos. Toda entidad que lo requiera usará un campo `deleted_at`.
5.  **Manejo de Estados Offline (Saga Pattern Manual):** Los pagos móviles procesados sin internet deben guardarse con el estado `PENDING_VALIDATION` o `APROBADO_VISUALMENTE`.

---

## 5. Contingencia Offline (El Puente QR P2P)
Si el cajero registra un "Pago Móvil" pero no hay internet para enviarlo a Supabase, el sistema no se detiene.
1.  El módulo genera un código QR que contiene un payload JSON muy comprimido con los datos de la transacción (claves cortas: `"id"`, `"m"`, `"r"`).
2.  El payload va firmado con un hash HMAC SHA-256 utilizando un Secret Key del archivo `.env`.
3.  La encargada, desde su dispositivo, escanea el QR. Su app verifica la firma criptográfica para evitar fraudes y aprueba el pago localmente hasta que regrese la conexión.