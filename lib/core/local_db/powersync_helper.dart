import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'schema.dart';
import 'supabase_connector.dart';

/// ============================================================================
/// POWERSYNC HELPER — SINGLETON ORQUESTADOR DE BASE DE DATOS OFFLINE-FIRST
/// ============================================================================
///
/// Patrón: Singleton estricto con control de doble inicialización (Completer).
///
/// Responsabilidades:
/// 1. Inicializar Supabase y PowerSync de forma idempotente.
/// 2. Abrir la base de datos local SQLite con fail-fast ante errores de FS.
/// 3. Registrar un listener reactivo sobre onAuthStateChange para mantener
///    la sincronización alineada con el estado de autenticación.
/// 4. Exponer un Stream de SyncStatus para observabilidad en la UI.
/// 5. Ejecutar el seed de datos iniciales offline de contingencia.
///
/// REGLAS DE INICIALIZACIÓN:
/// - initialize() es idempotente: si se invoca múltiples veces (hot reload,
///   reinicio de widgets), el Completer garantiza que solo se ejecute una vez.
/// - db.connect() NO bloquea el hilo principal. Si no hay red al arrancar,
///   PowerSync queda en cola de reintento pasivo sin bloquear la UI.
/// ============================================================================

class PowerSyncHelper {
  // -------------------------------------------------------------------------
  // SINGLETON
  // -------------------------------------------------------------------------
  static final PowerSyncHelper instance = PowerSyncHelper._internal();

  factory PowerSyncHelper() => instance;

  PowerSyncHelper._internal();

  // -------------------------------------------------------------------------
  // ESTADO INTERNO
  // -------------------------------------------------------------------------
  late final PowerSyncDatabase _db;
  late final SupabaseClient _supabase;
  late final SupabaseConnector _connector;

  /// Completer para garantizar inicialización única e idempotente.
  /// Si initialize() se invoca más de una vez, las llamadas subsecuentes
  /// simplemente esperan a que el primer Completer termine.
  Completer<void>? _initCompleter;

  /// Bandera para verificar si ya se completó la inicialización.
  bool _isInitialized = false;

  // -------------------------------------------------------------------------
  // SUSCRIPCIÓN A CAMBIOS DE AUTH
  // -------------------------------------------------------------------------
  StreamSubscription<AuthState>? _authSubscription;

  // -------------------------------------------------------------------------
  // ACCESORES PÚBLICOS
  // -------------------------------------------------------------------------

  /// Acceso a la base de datos PowerSync local.
  /// Lanza [StateError] si se accede antes de inicializar.
  PowerSyncDatabase get database {
    if (!_isInitialized) {
      throw StateError(
        'PowerSyncHelper no inicializado. '
        'Llama a PowerSyncHelper.instance.initialize() primero.',
      );
    }
    return _db;
  }

  /// Acceso al cliente de Supabase.
  SupabaseClient get supabase {
    if (!_isInitialized) {
      throw StateError(
        'PowerSyncHelper no inicializado. '
        'Llama a PowerSyncHelper.instance.initialize() primero.',
      );
    }
    return _supabase;
  }

  /// Stream de estado de sincronización para observabilidad en la UI.
  /// Permite que widgets muestren si el terminal está online, sincronizando
  /// cambios, o en modo offline aislado.
  Stream<SyncStatus> get statusStream => _db.statusStream;

  /// Estado actual de sincronización (snapshot puntual).
  SyncStatus get currentStatus => _db.currentStatus;

  /// Indica si la inicialización ya se completó exitosamente.
  bool get isInitialized => _isInitialized;

  // -------------------------------------------------------------------------
  // INICIALIZACIÓN PRINCIPAL (IDEMPOTENTE)
  // -------------------------------------------------------------------------

  /// Inicializa Supabase y PowerSync.
  ///
  /// Esta función es idempotente gracias al uso de [Completer]:
  /// - Primera invocación: ejecuta la inicialización completa.
  /// - Invocaciones subsecuentes: retorna inmediatamente el Future completado.
  ///
  /// Si la inicialización del filesystem o SQLite falla, la app falla de
  /// forma ruidosa (fail-fast) para evitar estados corruptos silenciosos.
  Future<void> initialize() async {
    // Retorno rápido si ya está inicializado.
    if (_isInitialized) return;

    // Protección contra condiciones de carrera: si initialize() es invocado
    // concurrentemente, todas las llamadas esperan al mismo Completer.
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      debugPrint('🚀 [PowerSyncHelper] Inicializando Supabase y PowerSync...');

      // ---- PASO 1: Inicializar Supabase ----
      await Supabase.initialize(
        url: 'https://xgvabksnzidgpbejfyrj.supabase.co',
        publishableKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhndmFia3NuemlkZ3BiZWpmeXJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0ODQ4OTYsImV4cCI6MjEwNzA2MDg5Nn0.ktOlKBThVo3zmEdI-eB3u4n9KzRpE1cge7XAZZGx9b8',
      );
      _supabase = Supabase.instance.client;

      // Login anónimo para que PowerSync obtenga un token JWT inicial.
      // Resiliente ante Offline: no bloquea ni aborta el arranque si no hay red
      // o si el login anónimo no está habilitado en la consola de Supabase.
      if (_supabase.auth.currentSession == null) {
        try {
          await _supabase.auth
              .signInAnonymously()
              .timeout(const Duration(seconds: 3));
          debugPrint('🔑 [PowerSyncHelper] Sesión anónima iniciada con éxito.');
        } catch (e) {
          debugPrint(
            '⚠️ [PowerSyncHelper] No se pudo obtener sesión anónima de red ($e). '
            'Continuando en modo Offline-First con base de datos local SQLite.',
          );
        }
      }

      // ---- PASO 2: Inicializar PowerSyncDatabase local ----
      final dir = await getApplicationDocumentsDirectory();
      final path = join(dir.path, 'club_erp_powersync.db');

      _db = PowerSyncDatabase(
        schema: schema,
        path: path,
      );

      // FAIL-FAST: Si SQLite no puede abrirse (permisos, FS corrupto),
      // la excepción se propaga y la app NO arranca en estado silenciosamente
      // corrupto. Esto es intencional.
      await _db.initialize();

      debugPrint(
        '💾 [PowerSyncHelper] Base de datos local abierta en: $path',
      );

      // ---- PASO 3: Seed de datos iniciales (Offline-First) ----
      await _seedInitialData();

      // ---- PASO 4: Conectar PowerSync con Supabase ----
      _connector = SupabaseConnector(_supabase);

      // connect() NO bloquea el hilo principal. Si no hay internet,
      // PowerSync queda en cola de reintento pasivo sin afectar la UI.
      _db.connect(connector: _connector);

      // ---- PASO 5: Suscripción reactiva a cambios de Auth ----
      _registerAuthListener();

      _isInitialized = true;
      _initCompleter!.complete();

      debugPrint(
        '✅ [PowerSyncHelper] Inicialización completa. '
        'Terminal POS operativo (Offline-First).',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '💥 [PowerSyncHelper] ERROR FATAL durante inicialización: '
        '$e\n$stackTrace',
      );
      _initCompleter!.completeError(e, stackTrace);
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // SUSCRIPCIÓN REACTIVA A CAMBIOS DE AUTH
  // -------------------------------------------------------------------------

  /// Registra un listener sobre `onAuthStateChange` para mantener la
  /// sincronización alineada con el estado de autenticación.
  ///
  /// Eventos manejados:
  /// - signedIn / tokenRefreshed → Forzar prefetch de credenciales para
  ///   que PowerSync reanude sincronización inmediatamente.
  /// - signedOut → Desconectar ordenadamente la sincronización.
  void _registerAuthListener() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;

        switch (event) {
          case AuthChangeEvent.signedIn:
            debugPrint(
              '🔑 [PowerSyncHelper] Evento: signedIn. '
              'Forzando prefetch de credenciales.',
            );
            _connector.prefetchCredentials();
            break;

          case AuthChangeEvent.tokenRefreshed:
            debugPrint(
              '🔄 [PowerSyncHelper] Evento: tokenRefreshed. '
              'Actualizando credenciales de PowerSync.',
            );
            _connector.prefetchCredentials();
            break;

          case AuthChangeEvent.signedOut:
            debugPrint(
              '🚪 [PowerSyncHelper] Evento: signedOut. '
              'Desconectando sincronización de PowerSync.',
            );
            await _db.disconnect();
            break;

          default:
            // Otros eventos (passwordRecovery, userUpdated, etc.)
            // no requieren acción sobre la sincronización.
            break;
        }
      },
      onError: (error) {
        debugPrint(
          '❌ [PowerSyncHelper] Error en listener de auth: $error',
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // SEED DE DATOS INICIALES (CONTINGENCIA OFFLINE)
  // -------------------------------------------------------------------------

  /// Inserta datos semilla si la base de datos local está virgen.
  ///
  /// Verificación atómica: `SELECT count(*) FROM roles`.
  /// IDs generados exclusivamente con Uuid().v4() — NUNCA secuencias
  /// ni valores estáticos hardcodeados.
  Future<void> _seedInitialData() async {
    final rs = await _db.execute('SELECT count(*) as count FROM roles');
    final count = rs.first['count'] as int;

    if (count > 0) {
      debugPrint(
        '📦 [PowerSyncHelper] Base de datos ya contiene datos. '
        'Seed omitido.',
      );
      return;
    }

    debugPrint('🌱 [PowerSyncHelper] Sembrando datos iniciales...');

    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();

    // ---- Roles ----
    final roleCajeraId = uuid.v4();
    final roleEncargadaId = uuid.v4();

    await _db.execute(
      'INSERT INTO roles(id, name, description, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, ?)',
      [roleCajeraId, 'CAJERA', 'Operador de caja', now, now],
    );
    await _db.execute(
      'INSERT INTO roles(id, name, description, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, ?)',
      [roleEncargadaId, 'ENCARGADA', 'Supervisor de turno', now, now],
    );

    // ---- Empleados ----
    final employee1Id = uuid.v4();
    final employee2Id = uuid.v4();

    await _db.execute(
      'INSERT INTO employees(id, role_id, name, pin_code, is_active, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, ?, ?, ?)',
      [employee1Id, roleCajeraId, 'María (Cajera)', '1234', 1, now, now],
    );
    await _db.execute(
      'INSERT INTO employees(id, role_id, name, pin_code, is_active, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, ?, ?, ?)',
      [employee2Id, roleEncargadaId, 'Carmen (Encargada)', '5678', 1, now, now],
    );

    debugPrint(
      '✅ [PowerSyncHelper] Seed completado: '
      '2 Roles, 2 Empleados inyectados.',
    );
  }

  // -------------------------------------------------------------------------
  // CICLO DE VIDA: LIMPIEZA
  // -------------------------------------------------------------------------

  /// Desconecta PowerSync y libera recursos.
  /// Usar al cerrar la aplicación o en tests.
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _db.disconnect();
    debugPrint('🧹 [PowerSyncHelper] Recursos liberados.');
  }
}
