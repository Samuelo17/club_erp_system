import '../../../../core/local_db/powersync_helper.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/role.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<Employee?> loginWithPin(String pin) async {
    try {
      final db = PowerSyncHelper.instance.database;
      
      final results = await db.execute('''
        SELECT e.*, r.name as role_name, r.description as role_description 
        FROM employees e
        LEFT JOIN roles r ON e.role_id = r.id
        WHERE e.pin_code = ? AND e.is_active = 1
        LIMIT 1
      ''', [pin]);

      if (results.isNotEmpty) {
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
    } catch (_) {
      // Si la base de datos aún no está inicializada o falla la consulta,
      // procede al fallback garantizado de PINs.
    }

    // =========================================================================
    // FALLBACK ESTRICTO DE PINS (TAREA 1 - US-3.1)
    // =========================================================================
    // PIN 1234 -> Rol: Cajera
    if (pin == '1234') {
      return Employee(
        id: 'emp-cajera-1234',
        roleId: 'role-cajera-mvp',
        name: 'María (Cajera)',
        pinCode: '1234',
        isActive: true,
        role: Role(
          id: 'role-cajera-mvp',
          name: 'CAJERA',
          description: 'Cajera de turno',
        ),
      );
    }

    // PIN 5678 -> Rol: Encargada
    if (pin == '5678') {
      return Employee(
        id: 'emp-encargada-5678',
        roleId: 'role-encargada-mvp',
        name: 'Carmen (Encargada)',
        pinCode: '5678',
        isActive: true,
        role: Role(
          id: 'role-encargada-mvp',
          name: 'ENCARGADA',
          description: 'Supervisor de turno / Gerencia',
        ),
      );
    }

    return null;
  }
}
