import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================================
/// SUPABASE CONNECTOR — PUENTE DE AUTENTICACIÓN Y SUBIDA DE DATOS
/// ============================================================================
///
/// Responsabilidades:
/// 1. Extraer e inyectar el JWT de Supabase en PowerSync (fetchCredentials).
/// 2. Refrescar tokens expirados de forma proactiva.
/// 3. Subir mutaciones locales a Supabase con resiliencia ante fallos de red.
///
/// REGLA CRÍTICA DE uploadData():
///   Si ocurre un error de red, la excepción DEBE propagarse (rethrow).
///   Esto evita que batch.complete() descarte transacciones no sincronizadas.
///   PowerSync reintentará automáticamente con exponential backoff.
/// ============================================================================

class SupabaseConnector extends PowerSyncBackendConnector {
  final SupabaseClient supabase;

  /// URL de la instancia de PowerSync Cloud.
  static const String _powersyncUrl =
      'https://6ac969103b1803753bd05872.powersync.journeyapps.com';

  SupabaseConnector(this.supabase);

  // ---------------------------------------------------------------------------
  // AUTENTICACIÓN: Extracción e Inyección del JWT
  // ---------------------------------------------------------------------------

  /// Obtiene credenciales para conectarse a PowerSync usando el JWT de Supabase.
  ///
  /// Flujo:
  /// 1. Inspecciona la sesión actual de Supabase.
  /// 2. Si no hay sesión, retorna null (PowerSync queda en espera pasiva).
  /// 3. Si el token está expirado, intenta refrescarlo automáticamente.
  /// 4. Retorna las credenciales válidas para PowerSync.
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = supabase.auth.currentSession;

    if (session == null) {
      debugPrint(
        '⚠️ [SupabaseConnector] Sin sesión activa. '
        'PowerSync en espera de autenticación.',
      );
      return null;
    }

    // Verificar expiración del token y refrescar proactivamente.
    // session.isExpired compara expiresAt contra DateTime.now().
    String token = session.accessToken;

    if (session.isExpired) {
      debugPrint(
        '🔄 [SupabaseConnector] Token JWT expirado. Refrescando sesión...',
      );
      try {
        final response = await supabase.auth.refreshSession();
        final refreshedSession = response.session;

        if (refreshedSession == null) {
          debugPrint(
            '❌ [SupabaseConnector] No se pudo refrescar la sesión. '
            'Retornando null.',
          );
          return null;
        }

        token = refreshedSession.accessToken;
        debugPrint('✅ [SupabaseConnector] Token JWT refrescado exitosamente.');
      } catch (e) {
        debugPrint(
          '❌ [SupabaseConnector] Error al refrescar sesión: $e. '
          'PowerSync usará el token anterior si aún es válido.',
        );
        // Si no podemos refrescar, intentamos con el token actual.
        // PowerSync manejará el rechazo del servidor si es inválido.
      }
    }

    return PowerSyncCredentials(
      endpoint: _powersyncUrl,
      token: token,
    );
  }

  // ---------------------------------------------------------------------------
  // SUBIDA DE DATOS: Resiliencia ante Fallos de Red
  // ---------------------------------------------------------------------------

  /// Sube los cambios locales pendientes a Supabase.
  ///
  /// CORRECCIÓN CRÍTICA respecto a la versión anterior:
  /// - El bloque catch NUNCA debe atrapar silenciosamente errores de red
  ///   y continuar hacia batch.complete().
  /// - Si una operación falla, se RELANZA la excepción para que PowerSync
  ///   retenga la transacción en la cola local y la reintente con
  ///   exponential backoff cuando la conexión se restaure.
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (var op in transaction.crud) {
        final table = op.table;
        final data = Map<String, dynamic>.from(op.opData ?? {});

        // Asegurar que el id siempre viaje en el payload para upserts.
        if (op.op == UpdateType.put) {
          data['id'] = op.id;
          await supabase.from(table).upsert(data);
        } else if (op.op == UpdateType.patch) {
          await supabase.from(table).update(data).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          // NOTA: En este sistema usamos Soft Deletes.
          // Un DELETE desde PowerSync nunca debería llegar aquí si la app
          // respeta la regla de borrado lógico (deleted_at).
          // Pero si llega, lo ejecutamos para no bloquear la cola.
          await supabase.from(table).delete().eq('id', op.id);
        }
      }

      // Solo marcar como completado si TODAS las operaciones fueron exitosas.
      await transaction.complete();

      debugPrint(
        '✅ [SupabaseConnector] Transacción subida exitosamente '
        '(${transaction.crud.length} operaciones).',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ [SupabaseConnector] Error al subir datos: $e\n$stackTrace\n'
        'PowerSync retendrá la transacción y reintentará automáticamente.',
      );
      // RETHROW OBLIGATORIO: PowerSync reintentará con backoff exponencial.
      // La transacción permanece en la cola local de SQLite intacta.
      rethrow;
    }
  }
}
