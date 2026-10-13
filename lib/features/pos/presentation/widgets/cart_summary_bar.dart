import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/features/exchange_rate/presentation/providers/exchange_rate_provider.dart';
import 'package:club_erp_system/features/pos/presentation/providers/cart_provider.dart';
import 'package:club_erp_system/features/pos/presentation/widgets/cart_bottom_sheet.dart';

/// Barra resumen del carrito que flota en la parte inferior de la pantalla.
///
/// - Se oculta con animación si el carrito está vacío.
/// - Muestra: cantidad de ítems (izquierda), total monetario (derecha),
///   e ícono de "ver ticket".
/// - Al tocar, abre el [CartBottomSheet] como modal.
///
/// Estilo: fondo con gradiente Naranja Vibrante, texto blanco,
/// esquinas redondeadas superiores para integrarse con el layout.
class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final isVisible = cart.isNotEmpty;

        return AnimatedSlide(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          offset: isVisible ? Offset.zero : const Offset(0, 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isVisible ? 1.0 : 0.0,
            child: GestureDetector(
              onTap: () => _openCartSheet(context),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF8C00),
                      Color(0xFFFF6B00),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8C00).withValues(alpha: 0.40),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Badge con cantidad
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${cart.totalItems} ítem${cart.totalItems == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Total monetario con conversión dual USD / Bs.
                    Consumer<ExchangeRateProvider>(
                      builder: (context, rateProvider, _) {
                        final totalUsd = cart.totalAmount;
                        final hasRate = rateProvider.hasRate;
                        final totalVes =
                            hasRate ? totalUsd * rateProvider.rateValue : null;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total: \$ ${totalUsd.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (totalVes != null)
                              Text(
                                'Bs. ${totalVes.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(width: 12),

                    // Ícono de "ver ticket"
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartBottomSheet(),
    );
  }
}
