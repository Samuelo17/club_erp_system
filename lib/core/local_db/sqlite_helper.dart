import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

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
      version: 1,
      onCreate: _createDB,
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

    // FASE 4: Ejecutar el Seeding inmediatamente después de crear las tablas
    await _seedInitialData(db);
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
      final foodCatId = uuid.v4();
      final drinksCatId = uuid.v4();
      final snacksCatId = uuid.v4();

      // 1. Inyectar Categorías
      final categories = [
        {'id': foodCatId, 'name': 'Comidas', 'is_active': 1},
        {'id': drinksCatId, 'name': 'Bebidas', 'is_active': 1},
        {'id': snacksCatId, 'name': 'Snacks', 'is_active': 1},
      ];
      
      for (var c in categories) {
        await db.insert('categories', c);
      }

      // 2. Inyectar Productos de Prueba
      final products = [
        // Comidas
        {'id': uuid.v4(), 'category_id': foodCatId, 'name': 'Hamburguesa Doble', 'current_price': 8.50, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': foodCatId, 'name': 'Pizza Margherita', 'current_price': 12.00, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': foodCatId, 'name': 'Club House', 'current_price': 9.00, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': foodCatId, 'name': 'Tacos al Pastor (3)', 'current_price': 7.50, 'is_active': 1},
        // Bebidas
        {'id': uuid.v4(), 'category_id': drinksCatId, 'name': 'Refresco de Limón', 'current_price': 1.50, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': drinksCatId, 'name': 'Cerveza Artesanal', 'current_price': 3.00, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': drinksCatId, 'name': 'Agua Mineral 500ml', 'current_price': 1.00, 'is_active': 1},
        // Snacks
        {'id': uuid.v4(), 'category_id': snacksCatId, 'name': 'Papas Rústicas', 'current_price': 4.00, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': snacksCatId, 'name': 'Tequeños (5 und)', 'current_price': 4.50, 'is_active': 1},
        {'id': uuid.v4(), 'category_id': snacksCatId, 'name': 'Empanada de Queso', 'current_price': 1.50, 'is_active': 1},
      ];

      for (var p in products) {
        await db.insert('products', p);
      }
      
      debugPrint("🎯 SQLite Seed Completado: 3 Categorías y 10 Productos inyectados.");
    }
  }
}