import 'package:powersync/powersync.dart';

/// ============================================================================
/// ESQUEMA LOCAL DE POWERSYNC — SINCRONIZADO CON EL DDL DE PRODUCCIÓN
/// ============================================================================
///
/// REGLAS FUNDAMENTALES:
/// 1. PowerSync inyecta automáticamente una columna `id` (TEXT/UUID) como PK.
///    NUNCA declarar Column.text('id') manualmente.
/// 2. Los booleanos de PostgreSQL se mapean a INTEGER 0/1 en SQLite.
/// 3. TIMESTAMPTZ se almacena como TEXT en formato ISO-8601 UTC.
/// 4. NUMERIC/DECIMAL se mapea a REAL (double de 64 bits IEEE 754).
/// 5. Las tablas transaccionales incluyen `is_archived` para la retención
///    asimétrica de 15 días gestionada por pg_cron en el servidor.
/// ============================================================================

const schema = Schema([
  // ---------------------------------------------------------------------------
  // 1. MÓDULO DE USUARIOS Y ROLES
  // ---------------------------------------------------------------------------
  Table('roles', [
    Column.text('name'),
    Column.text('description'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),

  Table('employees', [
    Column.text('role_id'),
    Column.text('name'),
    Column.text('pin_code'),
    Column.integer('is_active'), // BOOLEAN → INTEGER 0/1
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),

  // ---------------------------------------------------------------------------
  // 2. MÓDULO DE CATÁLOGO Y EXTRAS (MENÚ)
  // ---------------------------------------------------------------------------
  Table('categories', [
    Column.text('name'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),

  Table(
    'products',
    [
      Column.text('category_id'),
      Column.text('name'),
      Column.real('current_price'), // NUMERIC(10,2) → REAL
      Column.integer('is_active'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
    ],
    indexes: [
      Index('idx_products_category', [IndexedColumn('category_id')]),
      Index('idx_products_active', [IndexedColumn('is_active')]),
    ],
  ),

  Table('modifiers', [
    Column.text('name'),
    Column.real('price'), // NUMERIC(10,2) → REAL
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),

  // ---------------------------------------------------------------------------
  // 3. MÓDULO DE OPERACIONES BÁSICAS (CAJA Y TASA DE CAMBIO)
  // ---------------------------------------------------------------------------
  Table('exchange_rates', [
    Column.real('rate_value'), // NUMERIC(15,4) → REAL
    Column.text('created_by'), // FK → employees.id
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),

  /// cash_sessions: Tabla TRANSACCIONAL — incluye `is_archived`
  Table(
    'cash_sessions',
    [
      Column.text('employee_id'), // FK → employees.id
      Column.text('opened_at'),
      Column.text('closed_at'),
      Column.text('status'), // CHECK ('OPEN', 'CLOSED')
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
      Column.integer('is_archived'), // Retención asimétrica 15 días
    ],
    indexes: [
      Index('idx_cash_sessions_status', [IndexedColumn('status')]),
      Index('idx_cash_sessions_employee', [IndexedColumn('employee_id')]),
    ],
  ),

  // ---------------------------------------------------------------------------
  // 4. MÓDULO DE VENTAS (EL CORAZÓN)
  // ---------------------------------------------------------------------------

  /// orders: Tabla TRANSACCIONAL — incluye `is_archived`
  Table(
    'orders',
    [
      Column.text('employee_id'), // FK → employees.id
      Column.text('cash_session_id'), // FK → cash_sessions.id
      Column.real('total_amount'), // NUMERIC(15,2) → REAL
      Column.text('status'), // CHECK ('PENDING', 'COMPLETED', 'CANCELED')
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
      Column.integer('is_archived'), // Retención asimétrica 15 días
    ],
    indexes: [
      Index('idx_orders_status', [IndexedColumn('status')]),
      Index('idx_orders_employee', [IndexedColumn('employee_id')]),
      Index('idx_orders_session', [IndexedColumn('cash_session_id')]),
      Index('idx_orders_archived', [IndexedColumn('is_archived')]),
      Index('idx_orders_created', [IndexedColumn('created_at')]),
    ],
  ),

  /// order_items: Tabla TRANSACCIONAL — incluye `is_archived`
  Table(
    'order_items',
    [
      Column.text('order_id'), // FK → orders.id
      Column.text('product_id'), // FK → products.id
      Column.integer('quantity'), // CHECK (quantity > 0)
      Column.real('unit_price'), // Copia inmutable del current_price
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
      Column.integer('is_archived'), // Retención asimétrica 15 días
    ],
  ),

  /// order_item_modifiers: Tabla TRANSACCIONAL — incluye `is_archived`
  Table(
    'order_item_modifiers',
    [
      Column.text('order_item_id'), // FK → order_items.id
      Column.text('modifier_id'), // FK → modifiers.id
      Column.integer('quantity'),
      Column.real('unit_price'), // Copia inmutable del price del modifier
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
      Column.integer('is_archived'), // Retención asimétrica 15 días
    ],
  ),

  // ---------------------------------------------------------------------------
  // 5. MÓDULO DE PAGOS (CONCILIACIÓN Y MULTIMONEDA)
  // ---------------------------------------------------------------------------
  Table('payment_methods', [
    Column.text('name'),
    Column.integer('is_active'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('deleted_at'),
  ]),

  /// payments: Tabla TRANSACCIONAL — incluye `is_archived`
  Table(
    'payments',
    [
      Column.text('order_id'), // FK → orders.id
      Column.text('payment_method_id'), // FK → payment_methods.id
      Column.real('amount'), // NUMERIC(15,2) → REAL
      Column.text('currency'), // CHECK ('USD', 'VES')
      Column.real('exchange_rate'), // NUMERIC(15,4) — Tasa congelada al momento del pago
      Column.text('reference_number'), // Referencia de pago móvil o POS
      Column.text('status'), // CHECK ('PENDING_VALIDATION', 'APROBADO_VISUALMENTE', 'CONCILIADO')
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.text('deleted_at'),
      Column.integer('is_archived'), // Retención asimétrica 15 días
    ],
    indexes: [
      Index('idx_payments_order', [IndexedColumn('order_id')]),
      Index('idx_payments_status', [IndexedColumn('status')]),
      Index('idx_payments_archived', [IndexedColumn('is_archived')]),
    ],
  ),
]);
