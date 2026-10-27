// lib/features/kds/presentation/widgets/kds_order_card.dart
//
// Tarjeta de Comanda de Cocina (KDS Ticket) para el Cocinero.
// Diseñada con alta legibilidad, bordes gruesos y colores de estado contrastantes:
//   - Pendiente: Acento Naranja/Ámbar con botón "INICIAR PREPARACIÓN"
//   - En Preparación: Acento Azul con botón "MARCAR LISTO"
//   - Cantidades de productos resaltadas en grande
//   - Al marcar listo, desaparece automáticamente de la cola activa

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/kds_providers.dart';

class KdsOrderCard extends ConsumerWidget {
  final KdsOrderData kdsOrder;

  const KdsOrderCard({super.key, required this.kdsOrder});

  /// Formatea la hora en formato HH:mm
  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Calcula el tiempo transcurrido desde la creación de la comanda
  String _timeElapsed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return 'Hace un momento';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else {
      return 'Hace ${diff.inHours} h ${diff.inMinutes % 60} min';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = kdsOrder.order;
    final isCooking = order.status == 'cooking';
    final accentColor =
        isCooking ? const Color(0xFF2563EB) : const Color(0xFFEA580C);
    final accentLight =
        isCooking ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED);
    final minutesElapsed = DateTime.now().difference(order.createdAt).inMinutes;
    final isDelayed = minutesElapsed >= 15;

    final shortId = order.id.length >= 6
        ? order.id.substring(0, 6).toUpperCase()
        : order.id.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.85),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera de Tarjeta: ID + Tiempo + Badge de Estado ───────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ID Corto y Hora
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$shortId',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(order.createdAt),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            if (isDelayed)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.warning_amber_rounded,
                                    size: 13, color: AppColors.error),
                              ),
                            Text(
                              _timeElapsed(order.createdAt),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDelayed
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                // Badge de Estado Visual
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCooking
                            ? Icons.soup_kitchen_rounded
                            : Icons.schedule_rounded,
                        size: 14,
                        color: accentColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isCooking ? 'EN PREPARACIÓN' : 'PENDIENTE',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.border),

          // ── Cuerpo: Lista de OrderItems (Cantidad grande + Nombre) ───────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kdsOrder.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sin productos detallados',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...kdsOrder.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Cantidad resaltada en caja grande de alto contraste
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.35),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${item.qty}x',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Nombre del producto en tipografía clara y gruesa
                          Expanded(
                            child: Text(
                              item.productName,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.border),

          // ── Acciones: Botón de Avance de Estado ───────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ref
                      .read(kdsControllerProvider.notifier)
                      .advanceOrderStatus(
                        orderId: order.id,
                        currentStatus: order.status,
                      );
                },
                icon: Icon(
                  isCooking
                      ? Icons.check_circle_rounded
                      : Icons.local_fire_department_rounded,
                  size: 22,
                ),
                label: Text(
                  isCooking ? 'MARCAR LISTO' : 'INICIAR PREPARACIÓN',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCooking ? AppColors.success : const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
