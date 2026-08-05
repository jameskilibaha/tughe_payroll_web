import 'package:get/get.dart';

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

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
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
  Future<void> login({required String username, required String password}) async {
    final result = await _api.login(username: username, password: password);
    final backendUser = Map<String, dynamic>.from(result['user'] as Map);
    final user = User.fromBackendJson(backendUser);
    currentUser.value = user;
    await _persistence.writeJson(_key, user.toJson());
    _refreshEverythingAfterLogin();
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
  Future<void> changePassword(String newPassword) async {
    final backendId = currentUser.value?.backendId;
    if (backendId == null) return;
    await _api.changePassword(id: backendId, password: newPassword);
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
      Get.snackbar('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kuhifadhi picha kwenye seva.');
    }
  }
}
