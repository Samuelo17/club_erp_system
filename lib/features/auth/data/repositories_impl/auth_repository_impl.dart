import '../../../../core/local_db/powersync_helper.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/role.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<Employee?> loginWithPin(String pin) async {
    final db = PowerSyncHelper.instance.database;
    
    final results = await db.execute('''
      SELECT e.*, r.name as role_name, r.description as role_description 
      FROM employees e
      LEFT JOIN roles r ON e.role_id = r.id
      WHERE e.pin_code = ? AND e.is_active = 1
      LIMIT 1
    ''', [pin]);

    if (results.isEmpty) {
      return null;
    }

    final row = results.first;
    
    Role? role;
    if (row['role_name'] != null) {
      role = Role(
        id: row['role_id'] as String,
        name: row['role_name'] as String,
        description: row['role_description'] as String?,
      );
    }

    final employee = Employee.fromMap(row);
    return Employee(
      id: employee.id,
      roleId: employee.roleId,
      name: employee.name,
      pinCode: employee.pinCode,
      isActive: employee.isActive,
      role: role,
    );
  }
}
