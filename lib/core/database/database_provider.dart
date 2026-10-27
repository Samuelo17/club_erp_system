// lib/core/database/database_provider.dart
//
// Expone la instancia singleton de AppDatabase como un Provider de Riverpod.
// Toda la app accede a la base de datos a través de este provider.
//
// USO:
//   final db = ref.read(databaseProvider);
//   final db = ref.watch(databaseProvider); // Para reaccionar a cambios

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Provider global que expone la instancia única de la base de datos local.
///
/// Drift gestiona el pool de conexiones internamente; es seguro usar
/// una sola instancia en toda la aplicación.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();

  // Cierra la conexión a la base de datos cuando el provider sea destruido
  // (en condiciones normales, esto ocurre cuando la app se cierra).
  ref.onDispose(db.close);

  return db;
});
