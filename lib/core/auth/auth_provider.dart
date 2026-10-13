import 'package:flutter/foundation.dart';
import '../../features/auth/domain/entities/employee.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  
  Employee? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({required AuthRepository authRepository})
      // ignore: prefer_initializing_formals
      : _authRepository = authRepository;

  Employee? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final employee = await _authRepository.loginWithPin(pin);
      if (employee != null) {
        _currentUser = employee;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'PIN incorrecto o empleado inactivo';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al iniciar sesión: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
