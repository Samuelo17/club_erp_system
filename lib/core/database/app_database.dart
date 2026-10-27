// lib/core/database/app_database.dart
//
// Definición principal de la base de datos local usando Drift (SQLite).
// Implementa la arquitectura Offline-First con campos de auditoría y
// sincronización en cada tabla del dominio.
//
// Para regenerar el código generado, ejecutar:
//   dart run build_runner build --delete-conflicting-outputs

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES DE SINCRONIZACIÓN (syncStatus)
// ─────────────────────────────────────────────────────────────────────────────
/// Los posibles estados de sincronización de un registro local.
class SyncStatus {
  static const String synced = 'synced';
  static const String pendingInsert = 'pending_insert';
  static const String pendingUpdate = 'pending_update';
  static const String pendingDelete = 'pending_delete';
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLA: Roles
// Almacena los roles operativos y sus PINs de acceso de 4 dígitos.
// ─────────────────────────────────────────────────────────────────────────────
class Roles extends Table {
  // Clave Primaria: UUID generado localmente como texto
  TextColumn get id => text()();
  TextColumn get name => text()();
  // PIN de 4 dígitos (almacenado como texto para preservar ceros a la izquierda)
  TextColumn get pin => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // ── Campos de control Offline-First ──────────────────────────────────────
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus =>
      text().withDefault(Constant(SyncStatus.pendingInsert))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLA: PaymentMethods
// Catálogo dinámico de métodos de pago con flags para UI condicional.
// ─────────────────────────────────────────────────────────────────────────────
class PaymentMethods extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  // Si true, la UI mostrará un input para seleccionar banco
  BoolColumn get requiresBank => boolean().withDefault(const Constant(false))();
  // Si true, la UI mostrará un input para ingresar número de referencia
  BoolColumn get requiresReference =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // ── Campos de control Offline-First ──────────────────────────────────────
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus =>
      text().withDefault(Constant(SyncStatus.pendingInsert))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLA: ExchangeRate
// Historial de tasas USD -> VES. Registra quién realizó cada cambio.
// ─────────────────────────────────────────────────────────────────────────────
class ExchangeRates extends Table {
  TextColumn get id => text()();
  // Valor de la tasa (ej: 36.50 VES por 1 USD)
  RealColumn get rate => real()();
  // FK al rol que registró este cambio de tasa (usualmente 'Encargada')
  TextColumn get createdByRoleId =>
      text().references(Roles, #id)();

  // ── Campos de control Offline-First ──────────────────────────────────────
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus =>
      text().withDefault(Constant(SyncStatus.pendingInsert))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLA: Categories
// Clasificación del menú (ej. Bebidas, Comida, Licores).
// ─────────────────────────────────────────────────────────────────────────────
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // ── Campos de control Offline-First ──────────────────────────────────────
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus =>
      text().withDefault(Constant(SyncStatus.pendingInsert))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLA: Products
// Ítems del menú. Precio base en USD para conversión multimoneda.
// ─────────────────────────────────────────────────────────────────────────────
class Products extends Table {
  TextColumn get id => text()();
  // FK a la categoría del producto
  TextColumn get categoryId =>
      text().references(Categories, #id)();
  TextColumn get name => text()();
  // Precio base en dólares (la UI calcula VES usando exchangeRateProvider)
  RealColumn get priceUsd => real()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();

  // ── Campos de control Offline-First ──────────────────────────────────────
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus =>
      text().withDefault(Constant(SyncStatus.pendingInsert))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLA: Orders (Comandas)
// Cabecera del pedido. Guarda la tasa exacta usada al momento de creación.
// ─────────────────────────────────────────────────────────────────────────────
class Orders extends Table {
  TextColumn get id => text()();
  // FK al rol que creó la orden (la Cajera)
  TextColumn get createdByRoleId =>
      text().references(Roles, #id)();
  // Estados posibles: 'pending', 'in_progress', 'ready', 'paid', 'cancelled'
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();
  // Monto total en USD calculado al momento del cierre
  RealColumn get totalUsd => real().withDefault(const Constant(0.0))();
  // FK a la tasa de cambio vigente al crear la orden (para auditoría)
  TextColumn get exchangeRateId =>
      text().references(ExchangeRates, #id).nullable()();

  // ── Campos de control Offline-First ──────────────────────────────────────
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus =>
      text().withDefault(Constant(SyncStatus.pendingInsert))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLA: OrderItems
// Líneas de detalle de cada comanda. Registra precio unitario al momento.
// ─────────────────────────────────────────────────────────────────────────────
class OrderItems extends Table {
  TextColumn get id => text()();
  // FK a la orden padre
  TextColumn get orderId =>
      text().references(Orders, #id)();
  // FK al producto (guarda el unitPriceUsd por si cambia el precio luego)
  TextColumn get productId =>
      text().references(Products, #id)();
  IntColumn get qty => integer().withDefault(const Constant(1))();
  // Precio unitario en USD al momento de la orden (snapshot)
  RealColumn get unitPriceUsd => real()();

  // ── Campos de control Offline-First ──────────────────────────────────────
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus =>
      text().withDefault(Constant(SyncStatus.pendingInsert))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLA: Payments
// Registro de pagos por orden. Soporta pagos múltiples y multimoneda.
// ─────────────────────────────────────────────────────────────────────────────
class Payments extends Table {
  TextColumn get id => text()();
  // FK a la orden que se está pagando
  TextColumn get orderId =>
      text().references(Orders, #id)();
  // FK al método de pago usado (determina los inputs dinámicos de la UI)
  TextColumn get paymentMethodId =>
      text().references(PaymentMethods, #id)();
  RealColumn get amountUsd => real()();
  // Monto en Bolívares calculado con la tasa vigente
  RealColumn get amountVes => real()();
  // Número de referencia (requerido según requiresReference del PaymentMethod)
  TextColumn get reference => text().nullable()();
  // Banco emisor (requerido según requiresBank del PaymentMethod)
  TextColumn get bank => text().nullable()();
  // Estados posibles: 'pending', 'approved', 'rejected'
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();

  // ── Campos de control Offline-First ──────────────────────────────────────
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus =>
      text().withDefault(Constant(SyncStatus.pendingInsert))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS PARA EL SISTEMA DE COCINA (KDS)
// ─────────────────────────────────────────────────────────────────────────────

/// Detalle de un ítem de comanda para visualización en cocina.
class KdsOrderItemData {
  final String id;
  final String productId;
  final String productName;
  final int qty;
  final double unitPriceUsd;

  const KdsOrderItemData({
    required this.id,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPriceUsd,
  });
}

/// Comanda completa con cabecera y lista de productos para el KDS.
class KdsOrderData {
  final Order order;
  final List<KdsOrderItemData> items;

  KdsOrderData({
    required this.order,
    required this.items,
  });
}

/// Registro de un pago junto con los datos de su método de pago correspondiente.
class PaymentWithMethod {
  final Payment payment;
  final PaymentMethod method;

  const PaymentWithMethod({
    required this.payment,
    required this.method,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DATABASE: AppDatabase
// Clase principal que registra todas las tablas y gestiona las migraciones.
// ─────────────────────────────────────────────────────────────────────────────
@DriftDatabase(tables: [
  Roles,
  PaymentMethods,
  ExchangeRates,
  Categories,
  Products,
  Orders,
  OrderItems,
  Payments,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedInitialData();
          await _seedCatalogData();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Sprint Día 2: Datos del catálogo (categorías, productos, tasa)
            await _seedCatalogData();
          }
        },
      );

  /// Inserta los datos base necesarios para la operación del sistema.
  /// Roles con PINs fijos para el entorno de desarrollo/producción inicial.
  Future<void> _seedInitialData() async {
    final now = DateTime.now();

    // ── Roles Operativos ─────────────────────────────────────────────────
    // Nota: los campos requeridos sin withDefault() van como String directo.
    // Los campos con withDefault() van envueltos en Value<T>.
    await batch((b) {
      b.insertAll(roles, [
        RolesCompanion.insert(
          id: 'role-cajera-001',
          name: 'Cajera',
          pin: '1111',
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        RolesCompanion.insert(
          id: 'role-cocinero-001',
          name: 'Cocinero',
          pin: '2222',
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        RolesCompanion.insert(
          id: 'role-encargada-001',
          name: 'Encargada',
          pin: '3333',
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
      ]);
    });

    // ── Métodos de Pago por Defecto ──────────────────────────────────────
    await batch((b) {
      b.insertAll(paymentMethods, [
        PaymentMethodsCompanion.insert(
          id: 'pm-efectivo-001',
          name: 'Efectivo USD',
          requiresBank: const Value(false),
          requiresReference: const Value(false),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        PaymentMethodsCompanion.insert(
          id: 'pm-pagomovil-001',
          name: 'Pago Móvil',
          requiresBank: const Value(true),
          requiresReference: const Value(true),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        PaymentMethodsCompanion.insert(
          id: 'pm-pos-001',
          name: 'POS (Tarjeta)',
          requiresBank: const Value(false),
          requiresReference: const Value(true),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        PaymentMethodsCompanion.insert(
          id: 'pm-divisas-001',
          name: 'Efectivo Divisas',
          requiresBank: const Value(false),
          requiresReference: const Value(false),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
      ]);
    });
  }

  /// Inserta datos del catálogo: categorías, productos y tasa de cambio.
  /// Ejecutado tanto en onCreate (DB nueva) como en onUpgrade (v1 → v2).
  Future<void> _seedCatalogData() async {
    final now = DateTime.now();

    // ── Categorías del Menú ────────────────────────────────────────────
    await batch((b) {
      b.insertAll(categories, [
        CategoriesCompanion.insert(
          id: 'cat-bebidas-001',
          name: 'Bebidas',
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        CategoriesCompanion.insert(
          id: 'cat-comida-001',
          name: 'Comida',
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        CategoriesCompanion.insert(
          id: 'cat-licores-001',
          name: 'Licores',
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        CategoriesCompanion.insert(
          id: 'cat-postres-001',
          name: 'Postres',
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
      ]);
    });

    // ── Productos del Menú ─────────────────────────────────────────────
    await batch((b) {
      b.insertAll(products, [
        // ── Bebidas ──
        ProductsCompanion.insert(
          id: 'prod-cola-001',
          categoryId: 'cat-bebidas-001',
          name: 'Coca-Cola',
          priceUsd: 2.00,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-jugo-001',
          categoryId: 'cat-bebidas-001',
          name: 'Jugo Natural',
          priceUsd: 3.00,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-agua-001',
          categoryId: 'cat-bebidas-001',
          name: 'Agua Mineral',
          priceUsd: 1.50,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-limon-001',
          categoryId: 'cat-bebidas-001',
          name: 'Limonada Frozen',
          priceUsd: 3.50,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        // ── Comida ──
        ProductsCompanion.insert(
          id: 'prod-hamburguesa-001',
          categoryId: 'cat-comida-001',
          name: 'Hamburguesa Clásica',
          priceUsd: 8.50,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-pizza-001',
          categoryId: 'cat-comida-001',
          name: 'Pizza Margarita',
          priceUsd: 10.00,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-sandwich-001',
          categoryId: 'cat-comida-001',
          name: 'Club Sándwich',
          priceUsd: 7.00,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-papas-001',
          categoryId: 'cat-comida-001',
          name: 'Papas Fritas',
          priceUsd: 4.00,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-tequenos-001',
          categoryId: 'cat-comida-001',
          name: 'Tequeños (6 uds.)',
          priceUsd: 5.00,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        // ── Licores ──
        ProductsCompanion.insert(
          id: 'prod-cerveza-001',
          categoryId: 'cat-licores-001',
          name: 'Cerveza Nacional',
          priceUsd: 3.50,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-whisky-001',
          categoryId: 'cat-licores-001',
          name: 'Whisky (Copa)',
          priceUsd: 12.00,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-mojito-001',
          categoryId: 'cat-licores-001',
          name: 'Mojito',
          priceUsd: 8.00,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        // ── Postres ──
        ProductsCompanion.insert(
          id: 'prod-brownie-001',
          categoryId: 'cat-postres-001',
          name: 'Brownie con Helado',
          priceUsd: 6.00,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
        ProductsCompanion.insert(
          id: 'prod-cheesecake-001',
          categoryId: 'cat-postres-001',
          name: 'Cheesecake',
          priceUsd: 5.50,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
      ]);
    });

    // ── Tasa de Cambio Inicial (USD → VES) ─────────────────────────────
    await batch((b) {
      b.insertAll(exchangeRates, [
        ExchangeRatesCompanion.insert(
          id: 'rate-initial-001',
          rate: 36.50,
          createdByRoleId: 'role-encargada-001',
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.synced),
        ),
      ]);
    });
  }

  // ── QUERIES DE AUTENTICACIÓN ─────────────────────────────────────────────

  /// Busca un rol activo por su PIN. Retorna null si no existe.
  Future<Role?> findRoleByPin(String pin) {
    return (select(roles)
          ..where(
            (r) =>
                r.pin.equals(pin) &
                r.isActive.equals(true) &
                r.isDeleted.equals(false),
          ))
        .getSingleOrNull();
  }

  // ── QUERIES DE TASA DE CAMBIO ────────────────────────────────────────────

  /// Obtiene la tasa de cambio más reciente como Stream reactivo.
  Stream<ExchangeRate?> watchLatestExchangeRate() {
    return (select(exchangeRates)
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  // ── QUERIES DE COMANDAS (para KDS) ──────────────────────────────────────

  /// Escucha en tiempo real las órdenes de cocina (status 'pending' o 'cooking')
  /// junto con cada uno de sus ítems y el nombre del producto correspondiente
  /// obtenido mediante un JOIN con la tabla Products.
  Stream<List<KdsOrderData>> watchKdsOrders() {
    final query = select(orders).join([
      leftOuterJoin(orderItems, orderItems.orderId.equalsExp(orders.id)),
      leftOuterJoin(products, products.id.equalsExp(orderItems.productId)),
    ])
      ..where(
        orders.isDeleted.equals(false) &
            orders.status.isIn(['pending', 'cooking']),
      )
      ..orderBy([OrderingTerm.asc(orders.createdAt)]);

    return query.watch().map((rows) {
      final grouped = <String, KdsOrderData>{};

      for (final row in rows) {
        final orderRow = row.readTable(orders);
        final itemRow = row.readTableOrNull(orderItems);
        final productRow = row.readTableOrNull(products);

        if (!grouped.containsKey(orderRow.id)) {
          grouped[orderRow.id] = KdsOrderData(
            order: orderRow,
            items: [],
          );
        }

        if (itemRow != null && productRow != null) {
          grouped[orderRow.id]!.items.add(
                KdsOrderItemData(
                  id: itemRow.id,
                  productId: itemRow.productId,
                  productName: productRow.name,
                  qty: itemRow.qty,
                  unitPriceUsd: itemRow.unitPriceUsd,
                ),
              );
        }
      }

      return grouped.values.toList();
    });
  }

  /// Actualiza el estado de una comanda en Drift (ej. 'pending' -> 'cooking' -> 'ready').
  Future<int> updateOrderStatus(String orderId, String newStatus) {
    return (update(orders)..where((o) => o.id.equals(orderId))).write(
      OrdersCompanion(
        status: Value(newStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Escucha en tiempo real las órdenes activas (no pagadas ni canceladas).
  Stream<List<Order>> watchActiveOrders() {
    return (select(orders)
          ..where(
            (o) =>
                o.isDeleted.equals(false) &
                o.status.isNotIn(['paid', 'cancelled']),
          )
          ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
        .watch();
  }

  // ── QUERIES DE CATÁLOGO (POS) ──────────────────────────────────────────

  /// Escucha las categorías activas en tiempo real.
  Stream<List<Category>> watchActiveCategories() {
    return (select(categories)
          ..where((c) => c.isActive.equals(true) & c.isDeleted.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  /// Escucha todos los productos disponibles en tiempo real.
  Stream<List<Product>> watchAvailableProducts() {
    return (select(products)
          ..where((p) => p.isAvailable.equals(true) & p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  // ── QUERIES DE MÉTODOS DE PAGO ──────────────────────────────────────────

  /// Escucha en tiempo real el catálogo de métodos de pago activos.
  Stream<List<PaymentMethod>> watchActivePaymentMethods() {
    return (select(paymentMethods)
          ..where((pm) => pm.isActive.equals(true) & pm.isDeleted.equals(false))
          ..orderBy([(pm) => OrderingTerm.asc(pm.name)]))
        .watch();
  }

  // ── TRANSACCIONES DE CHECKOUT (VENTAS) ───────────────────────────────────

  /// Inserta atómicamente una orden con sus líneas de detalle y sus pagos.
  /// Si ocurre un fallo en cualquier paso, la transacción se revierte por completo.
  Future<void> createOrderWithItemsAndPayments({
    required OrdersCompanion order,
    required List<OrderItemsCompanion> items,
    required List<PaymentsCompanion> payments,
  }) async {
    await transaction(() async {
      await into(orders).insert(order);
      await batch((b) {
        b.insertAll(orderItems, items);
        b.insertAll(this.payments, payments);
      });
    });
  }

  // ── GESTIÓN ADMINISTRATIVA: TASA DE CAMBIO ───────────────────────────────

  /// Registra una nueva tasa de cambio en la base de datos (mantiene historial completo).
  Future<void> insertExchangeRate({
    required String id,
    required double rate,
    required String createdByRoleId,
  }) async {
    final now = DateTime.now();
    await into(exchangeRates).insert(
      ExchangeRatesCompanion.insert(
        id: id,
        rate: rate,
        createdByRoleId: createdByRoleId,
        createdAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value(SyncStatus.pendingInsert),
      ),
    );
  }

  /// Escucha el historial reciente de tasas de cambio.
  Stream<List<ExchangeRate>> watchExchangeRatesHistory({int limit = 5}) {
    return (select(exchangeRates)
          ..where((r) => r.isDeleted.equals(false))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
          ..limit(limit))
        .watch();
  }

  // ── GESTIÓN ADMINISTRATIVA: MENÚ (CRUD) ──────────────────────────────────

  /// Escucha todas las categorías no eliminadas (incluyendo inactivas para gestión).
  Stream<List<Category>> watchAllCategories() {
    return (select(categories)
          ..where((c) => c.isDeleted.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  /// Inserta una nueva categoría.
  Future<void> createCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  /// Actualiza una categoría existente.
  Future<void> updateCategory(CategoriesCompanion category) =>
      (update(categories)..where((c) => c.id.equals(category.id.value)))
          .write(category);

  /// Realiza borrado lógico de una categoría.
  Future<void> softDeleteCategory(String categoryId) {
    return (update(categories)..where((c) => c.id.equals(categoryId))).write(
      CategoriesCompanion(
        isDeleted: const Value(true),
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Escucha todos los productos no eliminados (incluyendo agotados para gestión).
  Stream<List<Product>> watchAllProducts() {
    return (select(products)
          ..where((p) => p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  /// Inserta un nuevo producto.
  Future<void> createProduct(ProductsCompanion product) =>
      into(products).insert(product);

  /// Actualiza un producto existente (nombre, precio, categoría, disponibilidad).
  Future<void> updateProduct(ProductsCompanion product) =>
      (update(products)..where((p) => p.id.equals(product.id.value)))
          .write(product);

  /// Realiza borrado lógico de un producto.
  Future<void> softDeleteProduct(String productId) {
    return (update(products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(
        isDeleted: const Value(true),
        isAvailable: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── GESTIÓN ADMINISTRATIVA: VALIDACIÓN DE PAGOS ──────────────────────────

  /// Escucha en tiempo real todos los pagos que requieren validación manual (ej. Pago Móvil).
  Stream<List<Payment>> watchPendingPayments() {
    return (select(payments)
          ..where(
            (p) =>
                p.isDeleted.equals(false) &
                p.status.equals('pending_validation'),
          )
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  /// Actualiza el estado de un pago a 'approved' en Drift.
  Future<int> approvePayment(String paymentId) {
    return (update(payments)..where((p) => p.id.equals(paymentId))).write(
      PaymentsCompanion(
        status: const Value('approved'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── GESTIÓN DE CAJA: ARQUEO DE PAGOS DEL DÍA ────────────────────────────

  /// Escucha en tiempo real todos los pagos registrados durante el día actual
  /// con estado 'approved' o 'pending_validation', junto con su método de pago.
  Stream<List<PaymentWithMethod>> watchPaymentsToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = select(payments).join([
      innerJoin(
        paymentMethods,
        paymentMethods.id.equalsExp(payments.paymentMethodId),
      ),
    ])
      ..where(
        payments.isDeleted.equals(false) &
            payments.status.isIn(['approved', 'pending_validation']) &
            payments.createdAt.isBiggerOrEqualValue(startOfDay),
      )
      ..orderBy([OrderingTerm.desc(payments.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return PaymentWithMethod(
          payment: row.readTable(payments),
          method: row.readTable(paymentMethods),
        );
      }).toList();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONEXIÓN NATIVA SQLITE
// Abre la base de datos en el directorio de documentos de la aplicación.
// ─────────────────────────────────────────────────────────────────────────────
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'happy_house.db'));
    return NativeDatabase.createInBackground(file);
  });
}
