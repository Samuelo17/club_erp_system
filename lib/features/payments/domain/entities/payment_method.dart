/// Entidad de dominio que representa un método de pago disponible.
///
/// Mapea la tabla `payment_methods` del DDL.
/// Ejemplos de [name]: 'Efectivo USD', 'Efectivo VES',
/// 'Pago Móvil', 'Punto de Venta'.
///
/// La lógica de negocio (requiere referencia o no) se resuelve
/// con [requiresReference], una propiedad derivada del nombre.
class PaymentMethod {
  final String id;
  final String name;
  final bool isActive;

  const PaymentMethod({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  /// `true` si este método de pago requiere Banco + Referencia.
  ///
  /// Regla de negocio (AC US-2.2):
  /// Solo "Pago Móvil" y "Punto de Venta" exigen estos campos.
  bool get requiresReference =>
      name.contains('Pago Móvil') || name.contains('Punto de Venta');

  /// `true` si este método requiere validación administrativa posterior en el Dashboard.
  ///
  /// **Regla de Negocio**:
  /// - Solo "Pago Móvil" requiere validación en línea ('PENDING_VALIDATION')
  ///   porque la cajera no puede verificar la cuenta bancaria del negocio en el acto.
  /// - "Punto de Venta" se aprueba al instante con el voucher físico ('CONCILIADO').
  /// - "Efectivo" se verifica físicamente en caja ('CONCILIADO').
  bool get requiresOnlineValidation => name.contains('Pago Móvil');

  /// Moneda natural del método de pago (inferida del nombre).
  ///
  /// 'Efectivo VES' → 'VES', todo lo demás → 'USD'.
  String get naturalCurrency => name.contains('VES') ? 'VES' : 'USD';
}
