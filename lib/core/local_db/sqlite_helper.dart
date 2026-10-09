import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

/// UUIDs dummy para Mocking MVP (US-1.3).
///
/// Mientras no existan los módulos de Auth y Turnos, se usan estas
/// constantes para satisfacer las restricciones de Foreign Key en
/// las tablas `orders` → `employees` y `orders` → `cash_sessions`.
const String dummyEmployeeId = '00000000-0000-0000-0000-000000000001';
const String dummySessionId = '00000000-0000-0000-0000-000000000002';
const String _dummyRoleId = '00000000-0000-0000-0000-000000000099';

class SQLiteHelper {
  // Patrón Singleton para mantener una sola instancia de la base de datos
  static final SQLiteHelper instance = SQLiteHelper._init();
  static Database? _database;

  SQLiteHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('club_erp.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // FASE 3: Creación de Esquemas (DDL)
  Future _createDB(Database db, int version) async {
    // Tabla Categorías: Cero IDs autoincrementales, UUIDs estrictos.
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabla Productos: current_price congelado y Relación con Categorías.
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        name TEXT NOT NULL,
        current_price REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Tabla Modificadores (Extras): Para la lógica de "Arma Pizza"
    await db.execute('''
      CREATE TABLE modifiers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // --- US-1.3: Tablas para Órdenes ---
    await _createOrderTables(db);

    // FASE 4: Ejecutar el Seeding inmediatamente después de crear las tablas
    await _seedInitialData(db);
  }

  /// Migración incremental para instalaciones existentes (v1 → v2).
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createOrderTables(db);
      await _seedDummyEmployeeAndSession(db);
      debugPrint('⬆️ SQLite migrada de v$oldVersion a v$newVersion (tablas de órdenes agregadas).');
    }
  }

  /// Crea las tablas de soporte para el módulo de ventas (US-1.3).
  ///
  /// Incluye `roles`, `employees` y `cash_sessions` como dependencias
  /// de FK, y las tablas core `orders` y `order_items`.
  Future _createOrderTables(Database db) async {
    // Tabla Roles (dependencia de employees)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    // Tabla Empleados (FK de orders.employee_id)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        role_id TEXT NOT NULL,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (role_id) REFERENCES roles (id)
      )
    ''');

    // Tabla Sesiones de Caja (FK de orders.cash_session_id)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_sessions (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        status TEXT NOT NULL CHECK (status IN ('OPEN', 'CLOSED')),
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id)
      )
    ''');

    // Tabla Órdenes (El corazón del POS)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        cash_session_id TEXT NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('PENDING', 'COMPLETED', 'CANCELED')),
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (employee_id) REFERENCES employees (id),
        FOREIGN KEY (cash_session_id) REFERENCES cash_sessions (id)
      )
    ''');

    // Tabla Ítems de Orden (Inmutabilidad Financiera: unit_price congelado)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        unit_price REAL NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
  }

  /// Inserta el rol, empleado y sesión de caja dummy para el MVP.
  Future _seedDummyEmployeeAndSession(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Rol dummy
    await db.insert('roles', {
      'id': _dummyRoleId,
      'name': 'Cajero MVP',
      'description': 'Rol temporal para el MVP sin módulo de Auth',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Empleado dummy
    await db.insert('employees', {
      'id': dummyEmployeeId,
      'role_id': _dummyRoleId,
      'name': 'Cajero POS (MVP)',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Sesión de caja dummy (siempre abierta)
    await db.insert('cash_sessions', {
      'id': dummySessionId,
      'employee_id': dummyEmployeeId,
      'opened_at': now,
      'status': 'OPEN',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    debugPrint('🔑 Dummy MVP seed: Rol, Empleado y Sesión de Caja inyectados.');
  }

  // FASE 4: Inyección de Datos Semilla
  Future _seedInitialData(Database db) async {
    // Verificamos si la tabla ya tiene datos para no duplicarlos
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories')
    );

    if (count == 0) {
      const uuid = Uuid();

      // Generamos UUIDs fijos en memoria para poder enlazarlos a los productos
      final dessertsCatId = uuid.v4();
      final fastFoodCatId = uuid.v4();
      final pizzaCatId = uuid.v4();
      final combosCatId = uuid.v4();

      // 1. Inyectar Categorías
      final categories = [
        {'id': dessertsCatId, 'name': 'Postres y Helados', 'is_active': 1},
        {'id': fastFoodCatId, 'name': 'Comida Rápida (Salchipapas)', 'is_active': 1},
        {'id': pizzaCatId, 'name': 'Pizzas', 'is_active': 1},
        {'id': combosCatId, 'name': 'Combos', 'is_active': 1},
      ];
      
      for (var c in categories) {
        await db.insert('categories', c);
      }

      // 2. Inyectar Productos (El Menú del Club de Piscina)
      final products = [
        // --- POSTRES Y HELADOS ---
        {'id': uuid.v4(), 'category_id': dessertsCatId, 'name': 'Fresas con crema 5oz', 'current_price': 2.50, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': dessertsCatId, 'name': 'Fresas con crema 9oz', 'current_price': 4.00, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': dessertsCatId, 'name': 'Fresas con crema 12oz', 'current_price': 6.00, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': dessertsCatId, 'name': '1 Barquilla con syrup', 'current_price': 1.50, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': dessertsCatId, 'name': '2 Barquillas con syrup', 'current_price': 2.50, 'is_active': 1},

        // --- COMIDA RÁPIDA (SALCHIPAPAS) ---
        {'id': uuid.v4(), 'category_id': fastFoodCatId, 'name': 'Salchipapa: Opción 1 (La Básica)', 'current_price': 2.50, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': fastFoodCatId, 'name': 'Salchipapa: Opción 2 (La Familiar)', 'current_price': 5.00, 'is_active': 1},

        // --- PIZZAS (Bases para el "Arma Pizza") ---
        {'id': uuid.v4(), 'category_id': pizzaCatId, 'name': 'Pizza Margarita Mediana (Base)', 'current_price': 3.99, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': pizzaCatId, 'name': 'Pizza Margarita Familiar (Base)', 'current_price': 6.99, 'is_active': 1},
        
        // --- COMBOS (PIZZAS CON BEBIDAS) ---
        {'id': uuid.v4(), 'category_id': combosCatId, 'name': 'Combo #1: 1 Pizza Fam + Refresco 1lt', 'current_price': 6.99, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': combosCatId, 'name': 'Combo #2: 2 Pizzas Fam + Refresco 2lt', 'current_price': 12.99, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': combosCatId, 'name': 'Combo #3: 3 Pizzas Fam + Refresco 2lt', 'current_price': 16.99, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': combosCatId, 'name': 'Combo 1: El Básico', 'current_price': 5.00, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': combosCatId, 'name': 'Combo 2: El Intermedio', 'current_price': 7.00, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': combosCatId, 'name': 'Combo 3: El Familiar', 'current_price': 10.00, 'is_active': 1},
      ];

      for (var p in products) {
        await db.insert('products', p);
      }

      // 3. Inyectar Modificadores (Los extras para las pizzas)
      final modifiers = [
        {'id': uuid.v4(), 'name': 'Extra Clase A: Cebolla', 'price': 1.00, 'is_active': 1},
        {'id': uuid.v4(), 'name': 'Extra Clase A: Pimentón', 'price': 1.00, 'is_active': 1},
        {'id': uuid.v4(), 'name': 'Extra Clase A: Tomate', 'price': 1.00, 'is_active': 1},
        {'id': uuid.v4(), 'name': 'Extra Clase A: Maíz', 'price': 1.00, 'is_active': 1},
        
        {'id': uuid.v4(), 'name': 'Extra Clase B: Jamón', 'price': 2.00, 'is_active': 1},
        {'id': uuid.v4(), 'name': 'Extra Clase B: Tocineta', 'price': 2.00, 'is_active': 1},
        {'id': uuid.v4(), 'name': 'Extra Clase B: Pepperoni', 'price': 2.00, 'is_active': 1},
        {'id': uuid.v4(), 'name': 'Extra Clase B: Champiñón', 'price': 2.00, 'is_active': 1},
      ];

      for (var m in modifiers) {
        await db.insert('modifiers', m);
      }

      // 4. Inyectar datos dummy MVP para satisfacer FK de órdenes
      await _seedDummyEmployeeAndSession(db);
      
      debugPrint("🎯 SQLite Seed Completado: 4 Categorías, 15 Productos, 8 Modificadores + Dummy MVP inyectados.");
    }
  }
}