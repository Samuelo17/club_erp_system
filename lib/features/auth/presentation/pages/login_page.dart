import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../pos/presentation/pages/pos_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _pin = '';
  static const int _maxPinLength = 6;

  void _onDigitPressed(String digit) {
    if (_pin.length < _maxPinLength) {
      setState(() {
        _pin += digit;
      });
      
      // Intentar login automáticamente al llegar a 4 dígitos
      if (_pin.length == 4) {
        _attemptLogin();
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _attemptLogin() async {
    final authProvider = context.read<AuthProvider>();
    
    // Evitamos doble submit
    if (authProvider.isLoading) return;

    final enteredPin = _pin;
    final success = await authProvider.login(enteredPin);
    
    if (!mounted) return;
    
    if (success) {
      final user = authProvider.currentUser;
      final isEncargada = user?.isEncargada ?? (enteredPin == '5678');

      setState(() {
        _pin = '';
      });

      // TAREA 1: Ruteo estricto por Rol / PIN
      if (isEncargada) {
        // PIN 5678 -> Rol: Encargada -> Navega a AdminDashboardPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      } else {
        // PIN 1234 -> Rol: Cajera -> Navega a PosPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PosPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'PIN incorrecto'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _pin = '';
      });
    }
  }

  Widget _buildNumpadButton(String title, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 2,
          ),
          onPressed: onPressed,
          child: title == 'DEL'
              ? const Icon(Icons.backspace_outlined)
              : Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        if (key == 'DEL') {
          return _buildNumpadButton(key, _onDeletePressed);
        } else if (key == 'OK') {
          return _buildNumpadButton(key, () {
            if (_pin.isNotEmpty) _attemptLogin();
          });
        } else {
          return _buildNumpadButton(key, () => _onDigitPressed(key));
        }
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Fondo claro moderno
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                'Ingresa tu PIN',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 32),
              
              // Display del PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pin.isEmpty ? 4 : _pin.length, 
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length ? Colors.blueAccent : Colors.grey[300],
                    ),
                  )
                ),
              ),
              const SizedBox(height: 8),
              if (authProvider.isLoading)
                 const CircularProgressIndicator(),
              const SizedBox(height: 32),
              
              // Numpad
              _buildNumpadRow(['1', '2', '3']),
              _buildNumpadRow(['4', '5', '6']),
              _buildNumpadRow(['7', '8', '9']),
              _buildNumpadRow(['DEL', '0', 'OK']),
            ],
          ),
        ),
      ),
    ),
  );
}
}
