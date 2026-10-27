// lib/features/auth/presentation/auth_screen.dart
//
// Pantalla de autenticación por PIN de 4 dígitos.
// Diseño optimizado para tablets táctiles según UI_STYLE_GUIDE:
//   - Fondo humo, tarjeta central blanca con sombra suave
//   - Acento naranja vibrante
//   - Teclado numérico con botones ergonómicos grandes
//   - Animación de shake al ingresar PIN incorrecto
//   - Ruteo automático por rol al autenticarse

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../pos/presentation/pos_screen.dart';
import '../../kds/presentation/kds_screen.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  // ── Controladores de Animación ─────────────────────────────────────────
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // Animación de "shake" horizontal para feedback de PIN incorrecto
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  /// Escucha cambios de estado para lanzar animaciones y navegar.
  void _handleStateChange(AuthState state, BuildContext context) {
    if (state.status == AuthStatus.error) {
      // Disparar animación de error (shake)
      _shakeController.forward(from: 0);
    }

    if (state.status == AuthStatus.authenticated && state.currentRole != null) {
      // Redirigir según el nombre del rol autenticado
      _navigateByRole(state.currentRole!.name, context);
    }
  }

  /// Redirige a la pantalla correspondiente según el rol.
  void _navigateByRole(String roleName, BuildContext context) {
    Widget destination;

    switch (roleName.toLowerCase()) {
      case 'cajera':
        destination = const PosScreen();
        break;
      case 'cocinero':
        destination = const KdsScreen();
        break;
      case 'encargada':
        destination = const AdminDashboardScreen();
        break;
      default:
        // Rol desconocido: no navegar (seguridad)
        return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Escuchar cambios de estado para efectos laterales (navegación/animación)
    ref.listen<AuthState>(authProvider, (_, next) {
      _handleStateChange(next, context);
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo / Título ────────────────────────────────────────
                  _buildHeader(),
                  const SizedBox(height: 36),
                  // ── Tarjeta del Teclado Numérico ─────────────────────────
                  _buildPinCard(authState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets Constructores ──────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        // Icono de la app con acento naranja
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Happy House',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ingresa tu PIN para acceder',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPinCard(AuthState authState) {
    final hasError = authState.status == AuthStatus.error;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        // Offset horizontal sinusoidal para el efecto shake
        final dx = hasError
            ? 8 * (0.5 - (_shakeAnimation.value - 0.5).abs()) * 2
            : 0.0;
        return Transform.translate(
          offset: Offset(dx * (1 - _shakeAnimation.value) * 10, 0),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              // ── Indicador de puntos del PIN ──────────────────────────
              _buildPinIndicator(authState),
              const SizedBox(height: 8),
              // ── Mensaje de error ──────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: authState.errorMessage != null
                    ? Padding(
                        key: const ValueKey('error_msg'),
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox(key: ValueKey('no_error'), height: 0),
              ),
              const SizedBox(height: 24),
              // ── Grid del Teclado Numérico ─────────────────────────────
              _buildNumericKeypad(authState),
            ],
          ),
        ),
      ),
    );
  }

  /// Cuatro puntos que representan los dígitos ingresados del PIN.
  Widget _buildPinIndicator(AuthState authState) {
    final hasError = authState.status == AuthStatus.error;
    final isLoading = authState.status == AuthStatus.loading;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < authState.pin.length;
        Color dotColor;

        if (hasError) {
          dotColor = AppColors.pinError;
        } else if (isFilled) {
          dotColor = AppColors.pinFilled;
        } else {
          dotColor = AppColors.pinEmpty;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: isFilled ? 18 : 14,
          height: isFilled ? 18 : 14,
          decoration: BoxDecoration(
            color: isLoading ? AppColors.primary : dotColor,
            shape: BoxShape.circle,
            boxShadow: isFilled && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  /// Grid 3x4 del teclado numérico con botones ergonómicos táctiles y adaptables.
  Widget _buildNumericKeypad(AuthState authState) {
    final isLoading = authState.status == AuthStatus.loading;

    // Layout del teclado: filas con sus valores
    final keypadLayout = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: keypadLayout.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: row.map((key) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _buildKeypadButton(key, isLoading),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Botón individual del teclado numérico con proporción cuadrada y tacto reactivo.
  Widget _buildKeypadButton(String label, bool isLoading) {
    final bool isDigit = RegExp(r'^\d$').hasMatch(label);
    final bool isClear = label == 'C';
    final bool isDelete = label == '⌫';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading
            ? null
            : () {
                final notifier = ref.read(authProvider.notifier);
                if (isDigit) {
                  notifier.appendDigit(label);
                } else if (isClear) {
                  notifier.clearPin();
                } else if (isDelete) {
                  notifier.deleteDigit();
                }
              },
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        highlightColor: AppColors.primary.withValues(alpha: 0.08),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Ink(
            decoration: BoxDecoration(
              color: isDigit
                  ? AppColors.backgroundCanvas
                  : (isClear
                      ? AppColors.errorLight
                      : AppColors.backgroundCanvas),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: isDelete
                  ? Icon(
                      Icons.backspace_outlined,
                      color: isLoading
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      size: 24,
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isClear
                            ? AppColors.error
                            : (isLoading
                                ? AppColors.textSecondary
                                : AppColors.textPrimary),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLAS PLACEHOLDER (se implementarán en sprints siguientes)
// Sirven como destino del ruteo por rol para validar el flujo completo.
// ─────────────────────────────────────────────────────────────────────────────

class PosScreenPlaceholder extends ConsumerWidget {
  const PosScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RoleScreen(
      title: 'Terminal POS',
      subtitle: 'Cajera',
      icon: Icons.point_of_sale_rounded,
      color: AppColors.primary,
      onLogout: () => _logout(ref, context),
    );
  }

  void _logout(WidgetRef ref, BuildContext context) {
    ref.read(authProvider.notifier).logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }
}

class KdsScreenPlaceholder extends ConsumerWidget {
  const KdsScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RoleScreen(
      title: 'Cocina (KDS)',
      subtitle: 'Cocinero',
      icon: Icons.restaurant_rounded,
      color: AppColors.orderNew,
      onLogout: () => _logout(ref, context),
    );
  }

  void _logout(WidgetRef ref, BuildContext context) {
    ref.read(authProvider.notifier).logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }
}

class AdminScreenPlaceholder extends ConsumerWidget {
  const AdminScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RoleScreen(
      title: 'Panel Gerencial',
      subtitle: 'Encargada',
      icon: Icons.dashboard_rounded,
      color: AppColors.success,
      onLogout: () => _logout(ref, context),
    );
  }

  void _logout(WidgetRef ref, BuildContext context) {
    ref.read(authProvider.notifier).logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }
}

/// Widget reutilizable para las pantallas placeholder de cada rol.
class _RoleScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onLogout;

  const _RoleScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 52, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bienvenido, $subtitle ✓',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar Sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
