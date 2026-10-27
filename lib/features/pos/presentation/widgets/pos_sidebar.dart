// lib/features/pos/presentation/widgets/pos_sidebar.dart
//
// Sidebar vertical minimalista del POS según UI_STYLE_GUIDE:
// Solo íconos para cambiar entre módulos + logout al fondo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/presentation/auth_screen.dart';
import '../../providers/cart_provider.dart';

class PosSidebar extends ConsumerWidget {
  const PosSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(
          right: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // ── App Logo ────────────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 28),
          // ── Navegación entre módulos ─────────────────────────────────────
          _SidebarIcon(
            icon: Icons.point_of_sale_rounded,
            label: 'Terminal POS',
            isActive: true,
            onTap: () {}, // Ya estamos en POS
          ),
          _SidebarIcon(
            icon: Icons.restaurant_rounded,
            label: 'Cocina (KDS)',
            isActive: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Módulo de Cocina — Próximamente'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _SidebarIcon(
            icon: Icons.dashboard_rounded,
            label: 'Panel Admin',
            isActive: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Panel Admin — Próximamente'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const Spacer(),
          // ── Logout ──────────────────────────────────────────────────────
          _SidebarIcon(
            icon: Icons.logout_rounded,
            label: 'Cerrar Sesión',
            isActive: false,
            isDestructive: true,
            onTap: () {
              ref.read(cartProvider.notifier).clearCart();
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Botón individual del sidebar con tooltip, estado activo y color destructivo.
class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SidebarIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: label,
        preferBelow: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isActive
                    ? AppColors.primary
                    : isDestructive
                        ? AppColors.error
                        : AppColors.textSecondary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
