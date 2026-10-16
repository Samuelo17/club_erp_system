/// Entidad de dominio que representa una sesión de caja (turno de trabajo).
class CashSession {
  final String id;
  final String employeeId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status; // 'OPEN' | 'CLOSED'

  const CashSession({
    required this.id,
    required this.employeeId,
    required this.openedAt,
    this.closedAt,
    required this.status,
  });

  bool get isOpen => status == 'OPEN';
  bool get isClosed => status == 'CLOSED';
}
