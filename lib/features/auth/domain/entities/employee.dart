import 'role.dart';

class Employee {
  final String id;
  final String roleId;
  final String name;
  final String pinCode;
  final bool isActive;
  final Role? role;

  Employee({
    required this.id,
    required this.roleId,
    required this.name,
    required this.pinCode,
    required this.isActive,
    this.role,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      roleId: map['role_id'] as String,
      name: map['name'] as String,
      pinCode: map['pin_code'] as String,
      isActive: map['is_active'] == 1 || map['is_active'] == true,
    );
  }
}
