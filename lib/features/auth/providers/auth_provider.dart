// lib/features/auth/providers/auth_provider.dart
//
// Estado y lógica de negocio para la autenticación por PIN de 4 dígitos.
// Implementado con Riverpod (Notifier) sin generación de código para
// simplicidad, siguiendo Clean Architecture (lógica separada de la UI).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE ESTADO DE AUTENTICACIÓN
// ─────────────────────────────────────────────────────────────────────────────

/// Posibles estados del flujo de autenticación.
enum AuthStatus {
  /// Estado inicial: esperando ingreso de PIN.
  idle,
  /// Consultando la base de datos para validar el PIN.
  loading,
  /// PIN validado. [AuthState.currentRole] contiene el rol autenticado.
  authenticated,
  /// El PIN ingresado no corresponde a ningún rol activo.
  error,
}

/// Estado inmutable del proceso de autenticación por PIN.
class AuthState {
  /// Dígitos del PIN actualmente ingresados (máx. 4 caracteres).
  final String pin;
  final AuthStatus status;
  /// Mensaje de error a mostrar en la UI (ej. "PIN incorrecto").
  final String? errorMessage;
  /// Rol autenticado en la sesión actual. Nulo hasta que el login sea exitoso.
  final Role? currentRole;

  const AuthState({
    this.pin = '',
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.currentRole,
  });

  /// Crea una copia del estado con los campos especificados modificados.
  AuthState copyWith({
    String? pin,
    AuthStatus? status,
    String? errorMessage,
    Role? currentRole,
    bool clearError = false,
    bool clearRole = false,
  }) {
    return AuthState(
      pin: pin ?? this.pin,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      currentRole: clearRole ? null : currentRole ?? this.currentRole,
    );
  }

  /// Verdadero cuando el PIN tiene exactamente 4 dígitos ingresados.
  bool get isPinComplete => pin.length == 4;
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER: Controlador de la lógica de autenticación
// ─────────────────────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Estado inicial limpio al construir el provider
    return const AuthState();
  }

  /// Obtiene la instancia de la base de datos del provider global.
  AppDatabase get _db => ref.read(databaseProvider);

  // ── Acciones del teclado numérico ─────────────────────────────────────────

  /// Agrega un dígito al PIN. Valida automáticamente al llegar a 4 dígitos.
  ///
  /// No hace nada si el PIN ya tiene 4 dígitos o si está cargando.
  Future<void> appendDigit(String digit) async {
    // Bloquear entrada durante la validación o si el PIN ya está completo
    if (state.status == AuthStatus.loading || state.isPinComplete) return;

    final newPin = state.pin + digit;
    state = state.copyWith(
      pin: newPin,
      status: AuthStatus.idle,
      clearError: true,
    );

    // Auto-validar al completar los 4 dígitos
    if (newPin.length == 4) {
      await _validatePin(newPin);
    }
  }

  /// Elimina el último dígito del PIN ingresado.
  void deleteDigit() {
    if (state.status == AuthStatus.loading) return;
    if (state.pin.isEmpty) return;

    state = state.copyWith(
      pin: state.pin.substring(0, state.pin.length - 1),
      status: AuthStatus.idle,
      clearError: true,
    );
  }

  /// Resetea completamente el PIN y limpia cualquier error.
  void clearPin() {
    state = const AuthState();
  }

  // ── Validación de PIN contra la base de datos local ───────────────────────

  /// Consulta Drift para validar el PIN ingresado.
  ///
  /// En éxito: emite [AuthStatus.authenticated] con el [Role] correspondiente.
  /// En fallo: emite [AuthStatus.error] y limpia el PIN tras un delay visual.
  Future<void> _validatePin(String pin) async {
    // Mostrar indicador de carga brevemente (para feedback táctil)
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final role = await _db.findRoleByPin(pin);

      if (role != null) {
        // ✅ PIN correcto: transición a estado autenticado
        state = state.copyWith(
          status: AuthStatus.authenticated,
          currentRole: role,
          clearError: true,
        );
      } else {
        // ❌ PIN incorrecto: mostrar error y limpiar con delay
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'PIN incorrecto. Intenta de nuevo.',
        );

        // Esperar el tiempo de la animación de error antes de limpiar
        await Future.delayed(const Duration(milliseconds: 800));
        clearPin();
      }
    } catch (e) {
      // Error inesperado (ej. base de datos no disponible)
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Error al verificar PIN. Intenta de nuevo.',
      );
      await Future.delayed(const Duration(milliseconds: 800));
      clearPin();
    }
  }

  // ── Cierre de sesión ───────────────────────────────────────────────────────

  /// Cierra la sesión actual y retorna al estado inicial.
  void logout() {
    state = const AuthState();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER GLOBAL
// ─────────────────────────────────────────────────────────────────────────────

/// Provider principal de autenticación. Toda la app usa este para
/// verificar si hay una sesión activa y cuál es el rol autenticado.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
