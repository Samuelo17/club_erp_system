// lib/features/pos/providers/cart_provider.dart
//
// Estado inmutable del carrito de compras y cálculo de totales multimoneda.
// El carrito es estado temporal en memoria. Se persiste como Order + OrderItems
// al momento de confirmar el cobro (Sprint Día 3).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import 'exchange_rate_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: CartItem
// ─────────────────────────────────────────────────────────────────────────────

/// Representa un ítem individual en el carrito de compras.
///
/// Captura un snapshot del precio ([unitPriceUsd]) al momento de agregar
/// para mantener consistencia si el precio del producto cambia después.
class CartItem {
  final Product product;
  final int qty;

  /// Precio unitario en USD capturado al agregar al carrito.
  final double unitPriceUsd;

  const CartItem({
    required this.product,
    required this.qty,
    required this.unitPriceUsd,
  });

  /// Subtotal de este ítem (precio × cantidad).
  double get subtotalUsd => unitPriceUsd * qty;

  CartItem copyWith({int? qty}) {
    return CartItem(
      product: product,
      qty: qty ?? this.qty,
      unitPriceUsd: unitPriceUsd,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: CartTotal
// ─────────────────────────────────────────────────────────────────────────────

/// Totales calculados del carrito en ambas monedas (USD y VES).
class CartTotal {
  /// Monto total en dólares estadounidenses.
  final double totalUsd;

  /// Monto total en bolívares (totalUsd × exchangeRate).
  final double totalVes;

  /// Tasa de cambio utilizada para el cálculo.
  final double exchangeRate;

  /// Cantidad total de unidades (suma de todas las qty).
  final int itemCount;

  /// Cantidad de productos distintos en el carrito.
  final int productCount;

  const CartTotal({
    required this.totalUsd,
    required this.totalVes,
    required this.exchangeRate,
    required this.itemCount,
    required this.productCount,
  });

  static const empty = CartTotal(
    totalUsd: 0,
    totalVes: 0,
    exchangeRate: 0,
    itemCount: 0,
    productCount: 0,
  );

  bool get isEmpty => productCount == 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER: CartNotifier
// ─────────────────────────────────────────────────────────────────────────────

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  /// Agrega un producto al carrito. Si ya existe, incrementa la cantidad.
  void addProduct(Product product) {
    final idx = state.indexWhere((i) => i.product.id == product.id);

    if (idx >= 0) {
      // Ya existe → incrementar cantidad
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx)
            state[i].copyWith(qty: state[i].qty + 1)
          else
            state[i],
      ];
    } else {
      // Nuevo producto → agregar al final con snapshot del precio actual
      state = [
        ...state,
        CartItem(
          product: product,
          qty: 1,
          unitPriceUsd: product.priceUsd,
        ),
      ];
    }
  }

  /// Incrementa la cantidad de un producto específico.
  void incrementQty(String productId) {
    state = [
      for (final item in state)
        if (item.product.id == productId)
          item.copyWith(qty: item.qty + 1)
        else
          item,
    ];
  }

  /// Decrementa la cantidad. Si llega a 0, elimina el ítem del carrito.
  void decrementQty(String productId) {
    final updated = <CartItem>[];
    for (final item in state) {
      if (item.product.id == productId) {
        if (item.qty > 1) {
          updated.add(item.copyWith(qty: item.qty - 1));
        }
        // qty == 1 → no agregar (eliminar del carrito)
      } else {
        updated.add(item);
      }
    }
    state = updated;
  }

  /// Elimina completamente un producto del carrito sin importar la cantidad.
  void removeItem(String productId) {
    state = state.where((i) => i.product.id != productId).toList();
  }

  /// Vacía completamente el carrito.
  void clearCart() {
    state = [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Provider principal del carrito de compras.
final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

/// Provider derivado que calcula los totales del carrito en USD y VES.
/// Escucha tanto al [cartProvider] como al [exchangeRateProvider] para
/// recalcular automáticamente cuando cualquiera cambia.
final cartTotalProvider = Provider<CartTotal>((ref) {
  final items = ref.watch(cartProvider);
  final rateAsync = ref.watch(exchangeRateProvider);
  final rate = rateAsync.value?.rate ?? 0.0;

  if (items.isEmpty) {
    return CartTotal(
      totalUsd: 0.0,
      totalVes: 0.0,
      exchangeRate: rate,
      itemCount: 0,
      productCount: 0,
    );
  }

  final totalUsd =
      items.fold<double>(0.0, (sum, item) => sum + item.subtotalUsd);

  return CartTotal(
    totalUsd: totalUsd,
    totalVes: totalUsd * rate,
    exchangeRate: rate,
    itemCount: items.fold<int>(0, (sum, item) => sum + item.qty),
    productCount: items.length,
  );
});

