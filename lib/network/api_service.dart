import 'api_client.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Typed wrapper around every `tughePayrollCore` FastAPI endpoint used by
/// the app. Each method matches one backend route 1:1 (see the various
/// `tughe/*/router.py` files) so the mapping is easy to audit.
///
/// Controllers should not build request maps inline; they call these
/// methods and let this class own the exact backend contract (paths,
/// payload shape). If the backend contract changes, this is the only
/// file that needs to change.
class ApiService {
  ApiService({ApiClient? client, TokenStorage? tokenStorage})
      : _client = client ?? ApiClient(),
        tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _client;
  final TokenStorage tokenStorage;

  /// Casts a decoded response body to a JSON object, or throws a clear,
  /// diagnosable [ApiException] instead of letting a raw Dart type-cast
  /// error surface as a generic "imeshindwa kuhifadhi" message. [context]
  /// is shown in the error so future issues are easy to pin down.
  Map<String, dynamic> _asMap(dynamic value, String context) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw ApiException(
        'Jibu la seva halikutarajiwa kwa "$context" (aina: ${value.runtimeType}). '
        'Hii mara nyingi inamaanisha endpoint husika ya backend haina response_model sahihi.');
  }

  // ---------------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------------
  Future<bool> health() async {
    try {
      final res = await _client.get('/api/health');
      return res is Map && res['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Auth  (tughe/auth/router.py)
  // ---------------------------------------------------------------------
  /// POST /api/login -> {token, token_type, user: AuthUser}
  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    final res = await _client.post('/api/login', body: {
      'username': username,
      'password': password,
    });
    final map = _asMap(res, 'login');
    final token = map['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await tokenStorage.saveToken(token);
    }
    return map;
  }

  Future<void> logout() => tokenStorage.clearToken();

  // ---------------------------------------------------------------------
  // Users  (tughe/user/router.py, prefix /api/user)
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> createUser({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String username,
    required String password,
  }) async {
    final res = await _client.post('/api/user', body: {
      'id': 0,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'username': username,
      'password': password,
    });
    return _asMap(res, 'createUser');
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required int id,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String username,
  }) async {
    final res = await _client.put('/api/user', body: {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'username': username,
    });
    return _asMap(res, 'updateUserProfile');
  }

  /// Sets/replaces the LOGGED-IN user's own profile picture, shown in the
  /// app header. [photoBase64] is a full data URL. Returns the resulting
  /// `photoFileName` the backend saved it as.
  Future<Map<String, dynamic>> updateOwnPhoto(String photoBase64) async {
    // id is ignored server-side (the backend uses the JWT-authenticated
    // caller), but the request body schema still requires the field.
    final res = await _client.put('/api/user/photo', body: {'id': 0, 'photoBase64': photoBase64});
    return _asMap(res, 'updateOwnPhoto');
  }

  /// Downloads the actual image bytes for a photo previously saved via
  /// [updateOwnPhoto]/[updateEmployeePhoto] (identified by its `photoFileName`).
  Future<List<int>> fetchUserPhotoBytes(String fileName) async {
    return _client.getBytes('/api/user/photo/$fileName');
  }

  Future<void> changePassword({required int id, required String password}) async {
    await _client.put('/api/user/change-password', body: {'id': id, 'password': password});
  }

  /// `active` mirrors the backend's own convention (0 = active, 1 = blocked);
  /// the backend's block endpoint actually just toggles regardless of the
  /// value sent, so the exact value here is not load-bearing.
  Future<Map<String, dynamic>> blockUser({required int id, required int active}) async {
    final res = await _client.put('/api/user/block', body: {'id': id, 'active': active});
    return _asMap(res, 'blockUser');
  }

  Future<List<dynamic>> getAllUsers() async {
    final res = await _client.get('/api/user/all');
    return List<dynamic>.from(res as List);
  }

  /// The user's real 14-function permission rows (`tughe/permission/model.py`).
  Future<List<dynamic>> getUserPermissions(int userId) async {
    final res = await _client.get('/api/permission/$userId');
    return List<dynamic>.from(res as List);
  }

  /// Updates one existing Permission row (identified by its own numeric
  /// [id], NOT the function name) - every user already has one row per
  /// function auto-created when their account was made, so this is
  /// always an update, never a create.
  Future<void> updatePermission({
    required int id,
    required int userId,
    required bool dataInsert,
    required bool dataUpdate,
    required bool dataSelect,
    required bool dataDelete,
    required bool dataBlock,
  }) async {
    await _client.put('/api/permission/change', body: {
      'id': id,
      'user_id': userId,
      'data_insert': dataInsert,
      'data_update': dataUpdate,
      'data_select': dataSelect,
      'data_delete': dataDelete,
      'data_block': dataBlock,
    });
  }

  Future<Map<String, dynamic>> getUser(String userId) async {
    final res = await _client.get('/api/user/$userId');
    return _asMap(res, 'getUser');
  }

  // ---------------------------------------------------------------------
  // Employees  (tughe/employee/router.py, prefix /api/employee)
  // ---------------------------------------------------------------------
  /// `id: 0` creates a new employee; a non-zero `id` updates the existing
  /// one (see `tughe/employee/service.py:create`). `user_id` can be left as
  /// 0 on create - the backend auto-creates the linked login account and
  /// overwrites it.
  Future<Map<String, dynamic>> saveEmployee({
    required int id,
    required String employeeIdNumber,
    required String firstName,
    required String middleName,
    required String lastName,
    required String sex,
    required String maritalStatus,
    required String nationality,
    required String residentDistrict,
    required String mobileNo,
    required String email,
    required String dateOfBirthIso,
    required String dateOfEmploymentIso,
    int userId = 0,
  }) async {
    final res = await _client.post('/api/employee', body: {
      'id': id,
      'employeeIdNumber': employeeIdNumber,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'sex': sex,
      'maritalStatus': maritalStatus,
      'nationality': nationality,
      'residentDistrict': residentDistrict,
      'mobileNo': mobileNo,
      'email': email,
      'dateOfBirth': dateOfBirthIso,
      'dateOfEmployment': dateOfEmploymentIso,
      'user_id': userId,
    });
    return _asMap(res, 'saveEmployee');
  }

  Future<Map<String, dynamic>> saveEmployeeStatus({
    required int employeeId,
    required String occupation,
    required String workstation,
    required double monthlyWages,
    required String bankName,
    required String bankAccountNumber,
  }) async {
    final res = await _client.post('/api/employee/status', body: {
      'employeeId': employeeId,
      'occupation': occupation,
      'workstation': workstation,
      'monthlyWages': monthlyWages,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
    });
    return _asMap(res, 'saveEmployeeStatus');
  }

  Future<void> blockEmployee(int id) async {
    await _client.put('/api/employee/block', body: {'id': id});
  }

  /// [photoBase64] is a full data URL (e.g. "data:image/jpeg;base64,...").
  /// Returns the resulting `photoFileName` the backend saved it as.
  Future<Map<String, dynamic>> updateEmployeePhoto({required int employeeId, required String photoBase64}) async {
    final res = await _client.put('/api/employee/photo', body: {'id': employeeId, 'photoBase64': photoBase64});
    return _asMap(res, 'updateEmployeePhoto');
  }

  /// Downloads the actual image bytes for a photo previously saved via
  /// [updateEmployeePhoto] (identified by its `photoFileName`).
  Future<List<int>> fetchEmployeePhotoBytes(String fileName) async {
    return _client.getBytes('/api/employee/photo/$fileName');
  }

  Future<List<dynamic>> searchEmployees({int? id, String? employeeIdNumber, String? mobileNo}) async {
    final res = await _client.post('/api/employee/search', body: {
      'id': id?.toString(),
      'employeeIdNumber': employeeIdNumber,
      'mobileNo': mobileNo,
      'user_id': null,
    });
    return List<dynamic>.from(res as List);
  }

  /// Composed endpoint: every matching employee with their salary status
  /// and active arrears/allowances already attached - ONE request instead
  /// of 1 + 3*N (was overloading the backend on every page load).
  Future<List<dynamic>> searchEmployeesFullProfile({int? id, String? employeeIdNumber, String? mobileNo}) async {
    final res = await _client.post('/api/employee/full-profile', body: {
      'id': id?.toString(),
      'employeeIdNumber': employeeIdNumber,
      'mobileNo': mobileNo,
      'user_id': null,
    });
    return List<dynamic>.from(res as List);
  }

  Future<List<dynamic>> searchEmployeeStatus(int employeeId) async {
    final res = await _client.post('/api/employee/search-status', body: {'employee_id': employeeId});
    return List<dynamic>.from(res as List);
  }

  // ---------------------------------------------------------------------
  // Arrears - master settings  (tughe/arrear/router.py, prefix /api/arrears)
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> saveArrearSetting({
    required int id,
    required String name,
    required String key, // SPECIAL | OTHER
    required String deductionModel, // AMOUNT | PERCENT
    required double percentOrAmount,
    bool isPermanentDeduction = false,
    bool isChoice = true,
  }) async {
    final res = await _client.post('/api/arrears', body: {
      'id': id,
      'name': name,
      'key': key,
      'percentOrAmount': percentOrAmount,
      'deductionModel': deductionModel,
      'isPermanentDeduction': isPermanentDeduction,
      'isChoice': isChoice,
    });
    return _asMap(res, 'saveArrearSetting');
  }

  Future<void> blockArrearSetting(int id) async {
    await _client.put('/api/arrears/block', body: {'id': id});
  }

  /// Pushes this master setting's current value to every employee already
  /// assigned it (e.g. NSSF's rate changed) - returns how many were updated.
  Future<Map<String, dynamic>> syncArrearSettingToEmployees(int id) async {
    final res = await _client.put('/api/arrears/sync-to-employees', body: {'id': id});
    return _asMap(res, 'syncArrearSettingToEmployees');
  }

  Future<List<dynamic>> searchArrearSettings({String? name, String? key}) async {
    final res = await _client.post('/api/arrears/search', body: {
      'id': null,
      'name': name,
      'key': key,
      'deductionModel': null,
    });
    return List<dynamic>.from(res as List);
  }

  // ---------------------------------------------------------------------
  // Allowances - master settings (tughe/allowance/router.py, /api/allowances)
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> saveAllowanceSetting({
    required int id,
    required String name,
    required String additionModel, // AMOUNT | PERCENT
    required String allowancesType, // SPECIAL | OTHER
    required double percentOrAmount,
    required bool isForEverOne,
  }) async {
    final res = await _client.post('/api/allowances', body: {
      'id': id,
      'name': name,
      'additionModel': additionModel,
      'allowancesType': allowancesType,
      'percentOrAmount': percentOrAmount,
      'isForEverOne': isForEverOne,
    });
    return _asMap(res, 'saveAllowanceSetting');
  }

  Future<void> blockAllowanceSetting(int id) async {
    await _client.put('/api/allowances/block', body: {'id': id});
  }

  /// Same as syncArrearSettingToEmployees, for allowances.
  Future<Map<String, dynamic>> syncAllowanceSettingToEmployees(int id) async {
    final res = await _client.put('/api/allowances/sync-to-employees', body: {'id': id});
    return _asMap(res, 'syncAllowanceSettingToEmployees');
  }

  Future<List<dynamic>> searchAllowanceSettings({String? name, String? allowancesType}) async {
    final res = await _client.post('/api/allowances/search', body: {
      'id': null,
      'name': name,
      'additionModel': null,
      'allowancesType': allowancesType,
    });
    return List<dynamic>.from(res as List);
  }

  // ---------------------------------------------------------------------
  // Per-employee arrears assignments (/api/emp-arrears)
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> saveEmpArrear({
    required int id,
    required double amount,
    required double deduction,
    required int employeeId,
    required int arrearsId,
  }) async {
    final res = await _client.post('/api/emp-arrears', body: {
      'id': id,
      'amount': amount,
      'deduction': deduction,
      'employee_id': employeeId,
      'arrears_id': arrearsId,
    });
    return _asMap(res, 'saveEmpArrear');
  }

  Future<void> blockEmpArrear({required int id, required int employeeId, required int arrearsId}) async {
    await _client.put('/api/emp-arrears/block', body: {
      'id': id,
      'employee_id': employeeId,
      'arrears_id': arrearsId,
    });
  }

  /// NOTE: don't rely on [isBlocked] to filter server-side - the backend's
  /// `bool(ent.isBlocked)` treats any non-empty string (including "False")
  /// as `True`, so it doesn't do what its name implies. Fetch without it
  /// and filter on each row's own `isBlocked` field client-side instead
  /// (see `EmployeeController.refreshFromBackend`).
  Future<List<dynamic>> searchEmpArrears({required int employeeId, String? isBlocked}) async {
    final res = await _client.post('/api/emp-arrears/search', body: {
      'id': null,
      'employee_id': employeeId.toString(),
      'arrears_id': null,
      'isBlocked': isBlocked,
    });
    return List<dynamic>.from(res as List);
  }

  // ---------------------------------------------------------------------
  // Per-employee allowances assignments (/api/emp-allowances)
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> saveEmpAllowance({
    required int id,
    required double amount,
    required int employeeId,
    required int allowanceId,
  }) async {
    final res = await _client.post('/api/emp-allowances', body: {
      'id': id,
      'amount': amount,
      'employee_id': employeeId,
      'allowance_id': allowanceId,
    });
    return _asMap(res, 'saveEmpAllowance');
  }

  Future<void> blockEmpAllowance({required int id, required int employeeId, required int allowanceId}) async {
    await _client.put('/api/emp-allowances/block', body: {
      'id': id,
      'employee_id': employeeId,
      'allowance_id': allowanceId,
    });
  }

  Future<List<dynamic>> searchEmpAllowances({required int employeeId, String? isBlocked}) async {
    final res = await _client.post('/api/emp-allowances/search', body: {
      'id': null,
      'employee_id': employeeId.toString(),
      'allowance_id': null,
      'isBlocked': isBlocked,
    });
    return List<dynamic>.from(res as List);
  }

  // ---------------------------------------------------------------------
  // Salary Terms / TRA formula (tughe/salarTerm/router.py, /api/salary-terms)
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> saveSalaryTerms({
    required int id,
    required Map<String, double> flatTerms, // term..term5, percentage..percentage5, addition..addition5
  }) async {
    final res = await _client.post('/api/salary-terms', body: {'id': id, ...flatTerms});
    return _asMap(res, 'saveSalaryTerms');
  }

  /// Fetches all salary-term rows (see the note on `searchEmpArrears` about
  /// why `isBlocked` isn't passed as a filter here); the caller picks the
  /// active (non-blocked) row.
  Future<List<dynamic>> searchSalaryTerms() async {
    final res = await _client.post('/api/salary-terms/search', body: {'id': null, 'isBlocked': null});
    return List<dynamic>.from(res as List);
  }

  // ---------------------------------------------------------------------
  // Audit Trail (tughe/auditTail/router.py, /api/audit-tails)
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> createAuditLog({
    required int tableId,
    required String tableName,
    required String actionType,
    required String oldData,
    required String newData,
  }) async {
    final res = await _client.post('/api/audit-tails', body: {
      'tableId': tableId,
      'tableName': tableName,
      'actionType': actionType,
      'oldData': oldData,
      'newData': newData,
      'user_id': 0, // overwritten server-side with the authenticated user
    });
    return _asMap(res, 'createAuditLog');
  }

  Future<List<dynamic>> searchAuditLogs() async {
    final res = await _client.post('/api/audit-tails/search', body: {
      'id': null,
      'tableId': null,
      'tableName': null,
      'actionType': null,
      'user_id': null,
    });
    return List<dynamic>.from(res as List);
  }

  // ---------------------------------------------------------------------
  // Payroll (tughe/payroll/router.py, /api/payrolls)
  // ---------------------------------------------------------------------
  /// [employeeIds]: real numeric backend employee ids (not employeeIdNumber
  /// strings) - leave null/empty to run for every eligible employee.
  Future<Map<String, dynamic>> generatePayroll(String monthYear, {List<int>? employeeIds}) async {
    final res = await _client.post('/api/payrolls/generate-payroll',
        body: {'monthYear': monthYear, 'employeeIds': employeeIds});
    return _asMap(res, 'generatePayroll');
  }

  /// Undoes a previous generate-payroll run for [monthYear] - removes every
  /// salary-slip/arrears-payment/allowances-payment row it created, so a
  /// fresh run for the same month starts clean. [employeeIds] narrows the
  /// reversal to specific employees only; leave null to reverse everyone.
  Future<Map<String, dynamic>> reverseGeneratePayroll(String monthYear, {List<int>? employeeIds}) async {
    final res = await _client.post('/api/payrolls/reverse-generate-payroll',
        body: {'monthYear': monthYear, 'employeeIds': employeeIds});
    return _asMap(res, 'reverseGeneratePayroll');
  }

  /// Real, already-generated payroll breakdown (NSSF/income tax/allowances/
  /// arrears/net pay rows) for one employee/month, produced by a previous
  /// `generatePayroll` run. Empty list means payroll hasn't been run for
  /// that employee/month yet.
  Future<List<dynamic>> searchSalarySlipGene({required int employeeId, required String monthYear}) async {
    final res = await _client.post('/api/salary-slip-gene/search-by-employee',
        body: {'employee_id': employeeId, 'monthYear': monthYear});
    return List<dynamic>.from(res as List);
  }

  // ---------------------------------------------------------------------
  // Reports (tughe/report/router.py, /api/reports)
  // ---------------------------------------------------------------------
  Future<List<dynamic>> fetchReportFiles() async {
    final res = await _client.get('/api/reports/file-list');
    return List<dynamic>.from(res as List);
  }

  Future<List<int>> downloadReportFile(String fileFull) async {
    return _client.getBytes('/api/reports/open-file/$fileFull');
  }

  Future<void> deleteReportFile(String fileFull) async {
    await _client.delete('/api/reports/delete/$fileFull');
  }

  Future<void> generateSalarySlip({required int employeeId, required String monthYear}) async {
    await _client.post('/api/reports/salary-slip', body: {
      'employee_id': employeeId,
      'monthYear': monthYear,
      'employeeStatus_id': 0,
    });
  }

  Future<void> generateSalarySlipAll(String monthYear) async {
    await _client.post('/api/reports/salary-slip-all', body: {'monthYear': monthYear});
  }
}
