import '../entities/employee.dart';

abstract class AuthRepository {
  /// Intenta iniciar sesión usando un código PIN.
  /// Retorna el [Employee] si el PIN es correcto y está activo.
  /// Retorna null si no se encuentra.
  Future<Employee?> loginWithPin(String pin);
}
