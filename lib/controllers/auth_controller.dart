import 'package:get/get.dart';

import '../models/permission_row.dart';
import '../models/user.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/persistence_service.dart';
import 'allowances_settings_controller.dart';
import 'arrears_settings_controller.dart';
import 'audit_controller.dart';
import 'employee_controller.dart';
import 'salary_terms_controller.dart';
import 'user_management_controller.dart';
import '../core/tr_snack.dart';

class AuthController extends GetxController {
  AuthController({PersistenceService? persistence, ApiService? apiService})
      : _persistence = persistence ?? PersistenceService(),
        _api = apiService ?? ApiService();

  static const _key = 'tughe_current_user';

  final PersistenceService _persistence;
  final ApiService _api;

  final Rxn<User> currentUser = Rxn<User>();
  final RxBool isLoading = true.obs;

  bool get isLoggedIn => currentUser.value != null;

  /// Admin = may manage users, permissions and the audit log. (Sessions saved by an older
  /// version carry the old label "Msimamizi"; treat it as Admin until the next login.)
  bool get isAdmin {
    final role = currentUser.value?.role ?? '';
    // An empty/unknown role (older server that does not report roles) is not hidden from anything:
    // the server still checks every permission.
    return role == kRoleAdmin || role.startsWith('Msimamizi') || !kAllRoles.contains(role);
  }

  /// HR officers work with the people, never with the pay.
  bool get isHr => currentUser.value?.role == kRoleHr;

  @override
  void onInit() {
    super.onInit();
    // Any 401 from the backend (expired/invalid/missing token) should drop
    // the cached session everywhere, not just clear the stored token -
    // otherwise the UI keeps showing "logged in" while every request
    // silently fails. The token itself is already cleared by ApiClient
    // before this fires.
    _api.onUnauthorized = _forceLocalLogout;
    _restoreSession();
  }

  void _forceLocalLogout() {
    if (currentUser.value == null) return; // already logged out, nothing to do
    currentUser.value = null;
    _persistence.remove(_key);
  }

  Future<void> _restoreSession() async {
    // A JWT token from a previous session, if any, is enough to trust the
    // cached profile until the next API call proves otherwise (a 401 will
    // clear the token and the next screen redirects to login).
    final token = await _api.tokenStorage.readToken();
    final raw = await _persistence.readJson(_key);
    if (token != null && token.isNotEmpty && raw is Map<String, dynamic>) {
      try {
        currentUser.value = User.fromJson(raw);
      } catch (_) {
        currentUser.value = null;
      }
    } else {
      currentUser.value = null;
    }
    isLoading.value = false;
  }

  /// Calls `POST /api/login` and, on success, stores the JWT token and the
  /// authenticated profile. Throws [ApiException] on invalid credentials,
  /// a blocked account, or a connectivity problem - the caller (login
  /// screen) is expected to show `error.message` to the person.
  ///
  /// Returns TRUE when the person has to choose a new password first (the password was set by somebody
  /// else: an Admin's reset, or the initial one). The session is then NOT opened yet: show the
  /// "choose a new password" dialog and call [completePasswordChange] (or [cancelPasswordChange]).
  Future<bool> login({required String username, required String password}) async {
    final result = await _api.login(username: username, password: password);
    final user = User.fromBackendJson(Map<String, dynamic>.from(result['user'] as Map));
    if (result['mustChangePassword'] == true) {
      _pendingUser = user;
      _pendingPassword = password;
      return true;
    }
    await _openSession(user);
    return false;
  }

  User? _pendingUser;
  String? _pendingPassword;

  Future<void> _openSession(User user) async {
    currentUser.value = user;
    await _persistence.writeJson(_key, user.toJson());
    _refreshEverythingAfterLogin();
  }

  /// Sets the new password (the server checks the rules and answers with a fresh token), then opens the session.
  Future<void> completePasswordChange(String newPassword) async {
    final user = _pendingUser;
    final current = _pendingPassword;
    if (user == null || current == null || user.backendId == null) {
      throw ApiException('Kikao cha kuingia kimekwisha. Ingia tena.');
    }
    await _api.changePassword(id: user.backendId!, password: newPassword, currentPassword: current);
    _pendingUser = null;
    _pendingPassword = null;
    await _openSession(user);
  }

  /// The person gave up choosing a new password: nothing is opened and the token is thrown away.
  Future<void> cancelPasswordChange() async {
    _pendingUser = null;
    _pendingPassword = null;
    await _api.logout();
  }

  /// Every other controller starts fetching as soon as it's created (in
  /// main()), which happens before the person has logged in - so their
  /// first attempt either gets skipped (no token yet) or fails with 401.
  /// Once login succeeds, kick them all off again for real. Each call is
  /// independent and handles its own errors/loading state.
  void _refreshEverythingAfterLogin() {
    if (Get.isRegistered<EmployeeController>()) {
      Get.find<EmployeeController>().refreshFromBackend();
    }
    if (Get.isRegistered<ArrearsSettingsController>()) {
      Get.find<ArrearsSettingsController>().refreshFromBackend();
    }
    if (Get.isRegistered<AllowancesSettingsController>()) {
      Get.find<AllowancesSettingsController>().refreshFromBackend();
    }
    if (Get.isRegistered<SalaryTermsController>()) {
      Get.find<SalaryTermsController>().refreshFromBackend();
    }
    if (Get.isRegistered<UserManagementController>()) {
      Get.find<UserManagementController>().refreshFromBackend();
    }
    if (Get.isRegistered<AuditController>()) {
      Get.find<AuditController>().refreshFromBackend();
    }
  }

  Future<void> logout() async {
    currentUser.value = null;
    await _persistence.remove(_key);
    await _api.logout();
  }

  /// Updates the in-memory/local session for the already-authenticated user
  /// (e.g. after editing their own profile) without calling `/api/login`
  /// again - there's no new credential to verify.
  Future<void> setCurrentUser(User user) async {
    currentUser.value = user;
    await _persistence.writeJson(_key, user.toJson());
  }

  /// Calls the real `PUT /api/user/change-password` for the currently
  /// logged-in user. Silently does nothing if the session hasn't been
  /// synced with a real backend id yet (nothing to update server-side).
  Future<void> changePassword(String newPassword, {String? currentPassword}) async {
    final backendId = currentUser.value?.backendId;
    if (backendId == null) return;
    await _api.changePassword(id: backendId, password: newPassword, currentPassword: currentPassword);
  }

  /// Uploads/replaces the logged-in user's own profile picture, shown in
  /// the app header. [photoBase64] is a full data URL sent to the backend,
  /// which stores it as a real file and returns its filename.
  Future<void> updateOwnPhoto(String photoBase64) async {
    final user = currentUser.value;
    if (user == null) return;
    try {
      final result = await _api.updateOwnPhoto(photoBase64);
      final fileName = result['photoFileName'] as String?;
      await setCurrentUser(user.copyWith(photoFileName: fileName));
    } catch (error) {
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kuhifadhi picha kwenye seva.');
    }
  }
}
