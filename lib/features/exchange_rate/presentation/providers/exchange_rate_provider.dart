import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:club_erp_system/features/exchange_rate/domain/entities/exchange_rate.dart';
import 'package:club_erp_system/features/exchange_rate/domain/repositories/exchange_rate_repository.dart';
import 'package:club_erp_system/features/exchange_rate/domain/usecases/save_exchange_rate_usecase.dart';
import 'package:club_erp_system/features/exchange_rate/domain/usecases/watch_latest_exchange_rate_usecase.dart';

/// ============================================================================
/// EXCHANGE RATE PROVIDER — ESTADO REACTIVO DE LA TASA DE CAMBIO
/// ============================================================================
///
/// Responsabilidades:
/// 1. Suscribirse al Stream reactivo de PowerSync (db.watch) para recibir
///    actualizaciones en tiempo real de la tasa activa.
/// 2. Exponer la tasa actual para que el POS y el Dashboard la consuman.
/// 3. Permitir que la Encargada registre una nueva tasa (INSERT inmutable).
///
/// REACTIVIDAD OFFLINE-FIRST:
///   Cuando la Encargada guarda una tasa nueva en su dispositivo, PowerSync
///   sincroniza la fila y db.watch() en el dispositivo de la Cajera emite
///   automáticamente. El Provider recibe el evento, actualiza _currentRate
///   y ejecuta notifyListeners(). El POS se redibuja sin tocar la pantalla.
/// ============================================================================

class ExchangeRateProvider extends ChangeNotifier {
  final SaveExchangeRateUseCase _saveUseCase;
  final WatchLatestExchangeRateUseCase _watchUseCase;

  ExchangeRate? _currentRate;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  StreamSubscription<ExchangeRate?>? _watchSubscription;

  ExchangeRateProvider({
    required ExchangeRateRepository repository,
  })  : _saveUseCase = SaveExchangeRateUseCase(repository),
        _watchUseCase = WatchLatestExchangeRateUseCase(repository) {
    _startWatching();
  }

  // ---------------------------------------------------------------------------
  // ACCESORES PÚBLICOS
  // ---------------------------------------------------------------------------

  /// La tasa de cambio activa actualmente (la más reciente sin soft delete).
  ExchangeRate? get currentRate => _currentRate;

  /// Valor numérico de la tasa activa.
  /// Retorna 0.0 si no hay ninguna tasa registrada todavía.
  double get rateValue => _currentRate?.rateValue ?? 0.0;

  /// `true` si hay una tasa activa disponible.
  bool get hasRate => _currentRate != null;

  /// `true` mientras se carga la primera lectura del Stream.
  bool get isLoading => _isLoading;

  /// `true` mientras se persiste una nueva tasa.
  bool get isSaving => _isSaving;

  /// Mensaje de error legible para mostrar en la UI, o `null` si no hay error.
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // SUSCRIPCIÓN REACTIVA (OFFLINE-FIRST)
  // ---------------------------------------------------------------------------

  /// Inicia la escucha del Stream de la tasa más reciente.
  ///
  /// Cada vez que se inserta una nueva tasa (local o por sync remoto),
  /// el Stream emite y este Provider se actualiza automáticamente.
  void _startWatching() {
    _watchSubscription = _watchUseCase.call().listen(
      (rate) {
        _currentRate = rate;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('❌ [ExchangeRateProvider] Error en watch: $error');
        _isLoading = false;
        _errorMessage = 'Error al observar la tasa de cambio.';
        notifyListeners();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // REGISTRO DE NUEVA TASA
  // ---------------------------------------------------------------------------

  /// Registra una nueva tasa de cambio (INSERT inmutable).
  ///
  /// [value]: Valor numérico de la tasa (ej. 81.45).
  /// [employeeId]: UUID del empleado/encargada que registra la tasa.
  ///
  /// Retorna `true` si el guardado fue exitoso, `false` si falló.
  Future<bool> registerRate(double value, String employeeId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      const uuid = Uuid();
      final now = DateTime.now().toUtc();

      final rate = ExchangeRate(
        id: uuid.v4(),
        rateValue: value,
        createdBy: employeeId,
        createdAt: now,
        updatedAt: now,
      );

      await _saveUseCase.call(rate);

      _isSaving = false;
      notifyListeners();

      debugPrint(
        '✅ [ExchangeRateProvider] Tasa registrada exitosamente: '
        '$value VES/USD',
      );
      return true;
    } catch (e) {
      _isSaving = false;
      _errorMessage = e is ArgumentError
          ? e.message.toString()
          : 'Error al guardar la tasa: $e';
      notifyListeners();
      debugPrint('❌ [ExchangeRateProvider] Error al registrar tasa: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // CICLO DE VIDA
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _watchSubscription?.cancel();
    _watchSubscription = null;
    super.dispose();
  }
}
