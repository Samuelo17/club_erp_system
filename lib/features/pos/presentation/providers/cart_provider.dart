import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:club_erp_system/core/local_db/sqlite_helper.dart';
import 'package:club_erp_system/features/pos/domain/entities/cart_item.dart';
import 'package:club_erp_system/features/pos/domain/entities/order.dart';
import 'package:club_erp_system/features/pos/domain/entities/order_item.dart';
import 'package:club_erp_system/features/pos/domain/entities/product.dart';
import 'package:club_erp_system/features/pos/domain/repositories/order_repository.dart';

/// Proveedor de estado reactivo para el carrito de compras (ticket dinámico).
///
/// Usa [ChangeNotifier] para notificar a los widgets consumidores
/// cada vez que se agrega, modifica o elimina un ítem.
///
/// **US-1.3**: Ahora recibe un [OrderRepository] inyectado para persistir
/// la orden en SQLite de forma atómica mediante [processOrder].
class CartProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;
  final List<CartItem> _items = [];

  /// Indica si hay una operación de persistencia en curso.
  bool _isProcessing = false;

  CartProvider({required OrderRepository orderRepository})
      // ignore: prefer_initializing_formals
      : _orderRepository = orderRepository;

  /// Lista de ítems del carrito (vista de solo lectura).
  List<CartItem> get items => List.unmodifiable(_items);

  /// Total monetario del carrito (suma de subtotales).
  double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Cantidad total de productos individuales en el carrito.
  int get totalItems =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  /// `true` si el carrito no tiene ítems.
  bool get isEmpty => _items.isEmpty;

  /// `true` si el carrito tiene al menos un ítem.
  bool get isNotEmpty => _items.isNotEmpty;

  /// `true` mientras se persiste la orden en SQLite.
  bool get isProcessing => _isProcessing;

  /// Agrega un producto al carrito.
  ///
  /// - Si el producto ya existe (mismo `id`), incrementa su cantidad en 1.
  /// - Si no existe, lo agrega como nuevo [CartItem] con cantidad 1.
  void addProduct(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);

    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }

    notifyListeners();
  }

  /// Incrementa en 1 la cantidad del producto indicado.
  void incrementQuantity(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);

    if (index != -1) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  /// Decrementa en 1 la cantidad del producto indicado.
  ///
  /// Si la cantidad llega a 0, elimina el ítem del carrito.
  void decrementQuantity(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);

    if (index != -1) {
      _items[index].quantity--;

      if (_items[index].quantity <= 0) {
        _items.removeAt(index);
      }

      notifyListeners();
    }
  }

  /// Elimina un producto completo del carrito (sin importar la cantidad).
  void removeProduct(Product product) {
    _items.removeWhere((item) => item.product.id == product.id);
    notifyListeners();
  }

  /// Vacía completamente el carrito.
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// Persiste la orden actual en SQLite y vacía el carrito.
  ///
  /// **Flujo Transaccional (US-1.3)**:
  /// 1. Genera un UUID v4 para la orden.
  /// 2. Mapea cada [CartItem] a un [OrderItem], copiando `currentPrice`
  ///    hacia `unitPrice` (**Inmutabilidad Financiera**).
  /// 3. Llama a [OrderRepository.createOrder] que ejecuta todo dentro
  ///    de un `db.transaction()` atómico.
  /// 4. Si todo sale bien, vacía `_items` y retorna `true`.
  /// 5. Si falla, no modifica el carrito y retorna `false`.
  Future<bool> processOrder() async {
    if (_items.isEmpty) return false;

    _isProcessing = true;
    notifyListeners();

    try {
      const uuid = Uuid();
      final orderId = uuid.v4();
      final now = DateTime.now();

      // Construir la entidad Order con constantes dummy del MVP
      final order = Order(
        id: orderId,
        employeeId: dummyEmployeeId,
        cashSessionId: dummySessionId,
        totalAmount: totalAmount,
        status: 'PENDING',
        createdAt: now,
      );

      // Mapear CartItems → OrderItems (Inmutabilidad Financiera)
      final orderItems = _items.map((cartItem) {
        return OrderItem(
          id: uuid.v4(),
          orderId: orderId,
          productId: cartItem.product.id,
          quantity: cartItem.quantity,
          unitPrice: cartItem.product.currentPrice, // ← Copia congelada
        );
      }).toList();

      // Persistir atómicamente en SQLite
      await _orderRepository.createOrder(order, orderItems);

      // Éxito: vaciar carrito
      _items.clear();
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Fallo: mantener el carrito intacto para reintento
      _isProcessing = false;
      notifyListeners();
      debugPrint('❌ Error al procesar orden: $e');
      return false;
    }
  }
}
