/// Mirrors one row of the backend's `permissions` table
/// (`tughe/permission/model.py`) - one row per (functionName, user),
/// with 5 independent action-type flags.
class PermissionRow {
  const PermissionRow({
    required this.id,
    required this.functionName,
    required this.userId,
    required this.dataInsert,
    required this.dataUpdate,
    required this.dataSelect,
    required this.dataDelete,
    required this.dataBlock,
  });

  final int id;
  final String functionName; // one of EFunctionNames, e.g. "EMPLOYEE"
  final int userId;
  final bool dataInsert;
  final bool dataUpdate;
  final bool dataSelect;
  final bool dataDelete;
  final bool dataBlock;

  /// True if ANY action is granted - used to show a simple on/off summary
  /// checkbox in the UI without needing 5 separate boxes per cell.
  bool get hasAnyAccess => dataInsert || dataUpdate || dataSelect || dataDelete || dataBlock;

  /// True only if ALL actions are granted.
  bool get hasFullAccess => dataInsert && dataUpdate && dataSelect && dataDelete && dataBlock;

  PermissionRow copyWith({
    bool? dataInsert,
    bool? dataUpdate,
    bool? dataSelect,
    bool? dataDelete,
    bool? dataBlock,
  }) {
    return PermissionRow(
      id: id,
      functionName: functionName,
      userId: userId,
      dataInsert: dataInsert ?? this.dataInsert,
      dataUpdate: dataUpdate ?? this.dataUpdate,
      dataSelect: dataSelect ?? this.dataSelect,
      dataDelete: dataDelete ?? this.dataDelete,
      dataBlock: dataBlock ?? this.dataBlock,
    );
  }

  factory PermissionRow.fromBackendJson(Map<String, dynamic> json) => PermissionRow(
        id: (json['id'] as num).toInt(),
        functionName: json['name'] as String,
        userId: (json['user_id'] as num).toInt(),
        dataInsert: json['data_insert'] as bool? ?? false,
        dataUpdate: json['data_update'] as bool? ?? false,
        dataSelect: json['data_select'] as bool? ?? false,
        dataDelete: json['data_delete'] as bool? ?? false,
        dataBlock: json['data_block'] as bool? ?? false,
      );
}

/// The 14 real backend function names (`tughe/functionName.py:
/// EFunctionNames`), with a friendly Swahili label and category for the
/// Permissions matrix UI. LOGIN is excluded (not a manageable permission -
/// everyone needs to be able to log in).
const List<Map<String, String>> systemFunctions = [
  {'name': 'EMPLOYEE', 'label': 'Wafanyakazi (Employee)', 'category': 'Watumishi'},
  {'name': 'ADD_ARREARS', 'label': 'Mipangilio ya Makato (Arrears Settings)', 'category': 'Payroll'},
  {'name': 'ADD_ALLOWANCES', 'label': 'Mipangilio ya Posho (Allowances Settings)', 'category': 'Payroll'},
  {'name': 'EMP_ARREARS', 'label': 'Makato ya Mfanyakazi (Employee Arrears)', 'category': 'Payroll'},
  {'name': 'EMP_ALLOWANCES', 'label': 'Posho za Mfanyakazi (Employee Allowances)', 'category': 'Payroll'},
  {'name': 'SALARY_TERMS', 'label': 'Vigezo vya Kodi (TRA Salary Terms)', 'category': 'Payroll'},
  {'name': 'PAYROLL', 'label': 'Kuendesha Payroll (Run/Reverse Payroll)', 'category': 'Payroll'},
  {'name': 'HR_RECORDS', 'label': 'Rekodi za HR (Mawasiliano, Wategemezi, Elimu, Mikataba)', 'category': 'HR'},
  {'name': 'LEAVE', 'label': 'Likizo (Leave: Maombi na Idhini)', 'category': 'HR'},
  {'name': 'SALARY_SLIP', 'label': 'Hati za Mshahara (Salary Slip)', 'category': 'Ripoti'},
  {'name': 'REPORT', 'label': 'Ripoti (Reports)', 'category': 'Ripoti'},
  {'name': 'USER', 'label': 'Watumiaji wa Mfumo (Users)', 'category': 'Usimamizi'},
  {'name': 'PERMISSION', 'label': 'Ruhusa za Mfumo (Permissions)', 'category': 'Usimamizi'},
  {'name': 'AUDIT_TAILS', 'label': 'Kumbukumbu za Mfumo (Audit Log)', 'category': 'Usalama'},
];

/// The three roles of the system. A role is not stored separately on the server: it
/// follows the user's permissions (see tughe/user/role.py) and the server reports it
/// with every user:
///   Admin       manages users, permissions and everything else
///   Accountant  does the payroll work (no user / permission / audit management)
///   User        no permissions - the default for everybody newly registered (e.g. an
///               employee). Only Admin and Accountant can sign in to the admin panel.
/// An Admin changes a role in the panel; the server switches the permissions at once.
const String kRoleAdmin = 'Admin';
const String kRoleAccountant = 'Accountant'; // shown as Payroll Officer
const String kRoleHr = 'HR';
const String kRoleUser = 'User';
const List<String> kAllRoles = [kRoleAdmin, kRoleAccountant, kRoleHr, kRoleUser];

String roleLabel(String role) => switch (role) {
      kRoleAdmin => 'Admin (Msimamizi)',
      kRoleAccountant => 'Payroll Officer (Mhasibu wa Mshahara)',
      kRoleHr => 'HR (Rasilimali Watu)',
      kRoleUser => 'User (Mfanyakazi)',
      _ => role,
    };

/// Which functions each role has FULL access to - the same table as the server
/// (tughe/user/role.py). The app only needs it as a fallback: an older server without
/// `PUT /api/permission/role` is given the permissions one by one instead.
const Map<String, Set<String>> kRoleFunctions = {
  kRoleAdmin: {
    'EMPLOYEE', 'ADD_ARREARS', 'ADD_ALLOWANCES', 'EMP_ARREARS', 'EMP_ALLOWANCES',
    'SALARY_TERMS', 'PAYROLL', 'SALARY_SLIP', 'REPORT', 'USER', 'PERMISSION', 'AUDIT_TAILS', 'HR_RECORDS', 'LEAVE',
  },
  kRoleAccountant: {
    'EMPLOYEE', 'ADD_ARREARS', 'ADD_ALLOWANCES', 'EMP_ARREARS', 'EMP_ALLOWANCES',
    'SALARY_TERMS', 'PAYROLL', 'SALARY_SLIP', 'REPORT',
  },
  kRoleHr: {'EMPLOYEE', 'HR_RECORDS', 'LEAVE'}, // people only - never pay
  kRoleUser: <String>{},
};

/// Roles that may sign in to the admin panel.
bool roleCanSignIn(String role) => role == kRoleAdmin || role == kRoleAccountant || role == kRoleHr;
