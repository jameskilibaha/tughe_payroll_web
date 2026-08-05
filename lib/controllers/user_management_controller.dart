import 'dart:async';
import 'package:get/get.dart';

import '../models/permission_row.dart';
import '../models/user.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/persistence_service.dart';

class UserManagementController extends GetxController {
  UserManagementController({PersistenceService? persistence, ApiService? apiService})
      : _persistence = persistence ?? PersistenceService(),
        _api = apiService ?? ApiService();

  static const _key = 'tughe_system_users';

  final PersistenceService _persistence;
  final ApiService _api;
  final RxList<User> systemUsers = <User>[].obs;
  final RxBool isLoading = true.obs;

  /// Real backend permission rows, one list of 14 per user (keyed by the
  /// user's backendId) - see tughe/permission/model.py. This replaces the
  /// old `User.permissions` list, which was only ever stored locally and
  /// never actually reached the backend.
  final RxMap<int, List<PermissionRow>> permissionsByUserId = <int, List<PermissionRow>>{}.obs;

  /// Keys of the form "userId:functionName" currently being saved, so the
  /// UI can show a per-cell loading spinner instead of changing silently.
  final RxSet<String> savingPermissionKeys = <String>{}.obs;

  /// Non-empty only when the last fetch genuinely failed. Never masked by
  /// sample/dummy data.
  final RxString errorMessage = ''.obs;

  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final token = await _api.tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      isLoading.value = false;
      if (!_ready.isCompleted) _ready.complete();
      return;
    }

    List<User>? cached;
    final raw = await _persistence.readJson(_key);
    if (raw is List) {
      try {
        cached = raw.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        cached = null;
      }
    }

    try {
      // Real data first: talk to the backend before showing anything else.
      await _fetchFromBackend(mergeBase: cached ?? const []);
      errorMessage.value = '';
    } catch (error) {
      if (cached != null) systemUsers.assignAll(cached);
      errorMessage.value =
          error is ApiException ? error.message : 'Imeshindwa kuunganisha na seva. Angalia mtandao wako.';
    } finally {
      isLoading.value = false;
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  bool _isRefreshing = false;

  Future<void> refreshFromBackend() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      await _fetchFromBackend(mergeBase: systemUsers);
      errorMessage.value = '';
    } catch (error) {
      if (error is ApiException && !error.isNetworkError) {
        errorMessage.value = error.message;
        Get.snackbar('Imeshindwa kupakua watumiaji', error.message);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// [mergeBase] carries over locally-cached cosmetic fields (email/role/
  /// designation/permissions the backend doesn't store) by backendId.
  Future<void> _fetchFromBackend({required List<User> mergeBase}) async {
    final backendList = await _api.getAllUsers();
    final byBackendId = {for (final u in mergeBase) if (u.backendId != null) u.backendId: u};
    final merged = backendList
        .map((raw) {
          final json = Map<String, dynamic>.from(raw as Map);
          final id = (json['id'] as num?)?.toInt();
          return User.fromBackendJson(json, previous: byBackendId[id]);
        })
        .toList()
        .cast<User>();
    systemUsers.assignAll(merged);
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final json = systemUsers.map((e) => e.toJson()).toList();
    await _persistence.writeJson(_key, json);
  }

  /// Splits a full display name into (firstName, lastName) for the fields
  /// the backend actually stores - the Add User form only collects a
  /// single "Jina Kamili" field.
  (String, String) _splitName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return ('Mtumiaji', '-');
    if (parts.length == 1) return (parts.first, '-');
    return (parts.first, parts.sublist(1).join(' '));
  }

  void toggleBlockUser(String userId) {
    final index = systemUsers.indexWhere((u) => u.id == userId);
    if (index == -1) return;
    final u = systemUsers[index];
    final nextStatus = u.status == 'Active' ? 'Blocked' : 'Active';
    systemUsers[index] = u.copyWith(status: nextStatus);
    unawaited(_persist());

    final backendId = u.backendId;
    if (backendId == null) return; // not yet synced - local-only for now
    _api.blockUser(id: backendId, active: nextStatus == 'Blocked' ? 1 : 0).catchError((error) {
      // Revert on failure.
      final revertIndex = systemUsers.indexWhere((x) => x.id == userId);
      if (revertIndex != -1) systemUsers[revertIndex] = u;
      Get.snackbar('Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kubadilisha hali ya mtumiaji.');
    });
  }

  void updateUser(User updated) {
    final index = systemUsers.indexWhere((u) => u.id == updated.id);
    final previous = index != -1 ? systemUsers[index] : null;
    if (index != -1) {
      systemUsers[index] = updated;
    } else {
      systemUsers.add(updated);
    }
    unawaited(_persist());

    final backendId = updated.backendId;
    if (backendId == null) return; // local-only user, nothing to sync yet
    final (firstName, lastName) = _splitName(updated.name);
    _api
        .updateUserProfile(
          id: backendId,
          firstName: updated.firstName ?? firstName,
          lastName: updated.lastName ?? lastName,
          phoneNumber: updated.phoneNumber ?? '0000000000',
          username: updated.username ?? updated.email,
        )
        .catchError((error) {
      if (previous != null) {
        final revertIndex = systemUsers.indexWhere((x) => x.id == updated.id);
        if (revertIndex != -1) systemUsers[revertIndex] = previous;
      }
      Get.snackbar('Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kuhifadhi mabadiliko.');
    });
  }

  /// Fetches and caches the real 14-function permission rows for [userId]
  /// (a real backend id) - called once per user when the Permissions tab
  /// needs them.
  Future<void> loadPermissionsFor(int userId) async {
    if (permissionsByUserId.containsKey(userId)) return;
    try {
      final rows = await _api.getUserPermissions(userId);
      permissionsByUserId[userId] =
          rows.map((r) => PermissionRow.fromBackendJson(Map<String, dynamic>.from(r as Map))).toList();
    } catch (error) {
      // Avoid a forever-spinning cell for this user - record an empty
      // list so the UI stops waiting, while still surfacing the error.
      permissionsByUserId[userId] = const [];
      Get.snackbar('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kupakua ruhusa za mtumiaji.');
    }
  }

  /// Loads permissions for every currently-known system user with a real
  /// backend id - called once when the Permissions tab first opens.
  Future<void> loadAllPermissions() async {
    for (final u in systemUsers) {
      final id = u.backendId;
      if (id != null) await loadPermissionsFor(id);
    }
  }

  /// Grants or revokes ALL access (insert/update/select/delete/block) for
  /// one function, for one user - shows a per-cell loading state and
  /// only updates the UI once the real database write succeeds.
  Future<void> setFunctionAccess(int userId, String functionName, bool granted) async {
    final key = '$userId:$functionName';
    final rows = permissionsByUserId[userId];
    if (rows == null) return;
    final rowIndex = rows.indexWhere((r) => r.functionName == functionName);
    if (rowIndex == -1) return;
    final row = rows[rowIndex];

    savingPermissionKeys.add(key);
    try {
      await _api.updatePermission(
        id: row.id,
        userId: userId,
        dataInsert: granted,
        dataUpdate: granted,
        dataSelect: granted,
        dataDelete: granted,
        dataBlock: granted,
      );
      final updated = List<PermissionRow>.from(rows);
      updated[rowIndex] = row.copyWith(
        dataInsert: granted,
        dataUpdate: granted,
        dataSelect: granted,
        dataDelete: granted,
        dataBlock: granted,
      );
      permissionsByUserId[userId] = updated;
    } catch (error) {
      Get.snackbar('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kusasisha ruhusa kwenye seva.');
    } finally {
      savingPermissionKeys.remove(key);
    }
  }

  /// Applies a preset role (see [rolePresets] in permission_row.dart) by
  /// granting/revoking each of the 14 functions accordingly, one at a
  /// time (each shows its own cell-level loading state).
  Future<void> applyRolePreset(int userId, String roleKey) async {
    final allowed = rolePresets[roleKey];
    if (allowed == null) return;
    for (final fn in systemFunctions) {
      final name = fn['name']!;
      await setFunctionAccess(userId, name, allowed.contains(name));
    }
  }

  void addUser(User user) {
    // Optimistic insert so the screen feels instant; reconciled with the
    // real backend id once the request completes.
    systemUsers.add(user);
    unawaited(_persist());

    final (firstName, lastName) = _splitName(user.name);
    final username = (user.email.isNotEmpty ? user.email.split('@').first : user.name)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');

    _api
        .createUser(
          firstName: firstName,
          lastName: lastName,
          phoneNumber: user.phoneNumber ?? '0000000000',
          username: username.isEmpty ? 'user${DateTime.now().millisecondsSinceEpoch}' : username,
          password: user.password ?? 'Tughe@1234',
        )
        .then((created) {
      final index = systemUsers.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        systemUsers[index] = User.fromBackendJson(created, previous: user);
        unawaited(_persist());
      }
    }).catchError((error) {
      systemUsers.removeWhere((u) => u.id == user.id);
      Get.snackbar('Imeshindikana Kusajili', error is ApiException ? error.message : 'Imeshindwa kusajili mtumiaji.');
    });
  }
}
