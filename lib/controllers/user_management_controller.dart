import 'dart:async';
import 'package:get/get.dart';

import '../models/permission_row.dart';
import '../models/user.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/persistence_service.dart';
import '../core/tr_snack.dart';

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
        trSnack('Imeshindwa kupakua watumiaji', error.message);
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
      trSnack('Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kubadilisha hali ya mtumiaji.');
    });
  }

  /// Admin action: sets a new password for ANY user directly on the server
  /// (PUT /api/user/change-password; needs the UPDATE permission on USER).
  /// The new password is deliberately not cached locally.
  Future<void> changeUserPassword(User user, String newPassword) async {
    final backendId = user.backendId;
    if (backendId == null) {
      throw StateError('User ${user.name} has no backend id yet');
    }
    await _api.changePassword(id: backendId, password: newPassword);
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
      trSnack('Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kuhifadhi mabadiliko.');
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
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kupakua ruhusa za mtumiaji.');
    }
  }

  /// Loads permissions for every currently-known system user with a real
  /// backend id - called once when the Permissions tab first opens.
  Future<void> loadAllPermissions({bool onlyStaff = false}) async {
    for (final u in systemUsers.toList()) {
      if (onlyStaff && u.role == kRoleUser) continue; // plain Users have no permissions to show
      final id = u.backendId;
      if (id != null) await loadPermissionsFor(id);
    }
  }

  /// Grants or revokes ALL access (insert/update/select/delete/block) for one function of one user.
  Future<bool> setFunctionAccess(int userId, String functionName, bool granted) => setFunctionFlags(
        userId,
        functionName,
        insert: granted,
        update: granted,
        select: granted,
        delete: granted,
        block: granted,
      );

  /// Changes some of the 5 action flags of ONE function for ONE user (the ones left null stay as
  /// they are). The screen only changes once the server has really saved it; on failure nothing
  /// changes and the reason is shown. Afterwards the user's role label is brought in line with
  /// the new permissions (the server derives a role from them in the same way).
  Future<bool> setFunctionFlags(
    int userId,
    String functionName, {
    bool? insert,
    bool? update,
    bool? select,
    bool? delete,
    bool? block,
  }) async {
    final key = '$userId:$functionName';
    final rows = permissionsByUserId[userId];
    if (rows == null) return false;
    final rowIndex = rows.indexWhere((r) => r.functionName == functionName);
    if (rowIndex == -1) return false;
    final row = rows[rowIndex];
    final next = row.copyWith(dataInsert: insert, dataUpdate: update, dataSelect: select, dataDelete: delete, dataBlock: block);

    savingPermissionKeys.add(key);
    try {
      await _api.updatePermission(
        id: row.id,
        userId: userId,
        dataInsert: next.dataInsert,
        dataUpdate: next.dataUpdate,
        dataSelect: next.dataSelect,
        dataDelete: next.dataDelete,
        dataBlock: next.dataBlock,
      );
      final updated = List<PermissionRow>.from(rows);
      updated[rowIndex] = next;
      permissionsByUserId[userId] = updated;
      final userIndex = systemUsers.indexWhere((u) => u.backendId == userId);
      if (userIndex != -1) {
        systemUsers[userIndex] = systemUsers[userIndex].copyWith(role: roleFromPermissions(updated));
        unawaited(_persist());
      }
      return true;
    } catch (error) {
      trSnack('Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kusasisha ruhusa kwenye seva.');
      return false;
    } finally {
      savingPermissionKeys.remove(key);
    }
  }

  /// The role a set of permissions amounts to (same rule as the server): Admin = may view users AND
  /// permissions; Accountant = any other permission; User = none.
  static String roleFromPermissions(List<PermissionRow> rows) {
    bool canSee(String name) => rows.any((r) => r.functionName == name && r.dataSelect);
    if (canSee('USER') && canSee('PERMISSION')) return kRoleAdmin;
    final granted = rows.where((r) => r.functionName != 'LOGIN' && r.hasAnyAccess).map((r) => r.functionName).toSet();
    // HR: only the people functions (and at least one of the two HR ones) - same rule as the server.
    if (granted.isNotEmpty &&
        granted.every(kRoleFunctions[kRoleHr]!.contains) &&
        (granted.contains('HR_RECORDS') || granted.contains('LEAVE'))) {
      return kRoleHr;
    }
    if (granted.isNotEmpty) return kRoleAccountant;
    return kRoleUser;
  }

  /// User ids whose role is being changed right now (to show a spinner).
  final RxSet<int> changingRole = <int>{}.obs;

  /// Why the last [changeRole] failed (null after a success) - the screen shows it in a dialog.
  final RxnString lastRoleError = RxnString();

  /// Gives a user the role Admin / Accountant / User. The SERVER switches all the matching
  /// permissions at once (`PUT /api/permission/role`); if it is an older server without that
  /// endpoint (404/405) the permissions are given one by one instead. Returns true on success;
  /// otherwise [lastRoleError] holds the reason.
  Future<bool> changeRole(int userId, String role, {bool quiet = false}) async {
    changingRole.add(userId);
    lastRoleError.value = null;
    try {
      var newRole = role;
      try {
        final result = await _api.setUserRole(userId: userId, role: role);
        newRole = (result['role'] as String?) ?? role;
      } on ApiException catch (error) {
        // Only a server that really does not know the endpoint ("Not Found" / "Method Not Allowed")
        // is given the permissions one by one. Any other answer - e.g. "User not found",
        // "Huwezi kubadilisha role yako mwenyewe" - is a real reason and is shown as it is.
        final generic = error.message.trim().toLowerCase();
        final endpointMissing = (error.statusCode == 405) || (error.statusCode == 404 && (generic == 'not found' || generic.isEmpty));
        if (endpointMissing) {
          await _applyRoleOneByOne(userId, role);
        } else {
          rethrow;
        }
      }
      final index = systemUsers.indexWhere((u) => u.backendId == userId);
      if (index != -1) {
        systemUsers[index] = systemUsers[index].copyWith(role: newRole);
        unawaited(_persist());
      }
      permissionsByUserId.remove(userId);
      unawaited(loadPermissionsFor(userId));
      if (!quiet) trSnack('Imefanikiwa', 'Role imebadilishwa kuwa ${roleLabel(newRole)}.');
      return true;
    } catch (error) {
      final message = error is ApiException
          ? '${error.message}${error.statusCode == null ? '' : '  (status ${error.statusCode})'}'
          : 'Imeshindwa kubadilisha role: $error';
      lastRoleError.value = message;
      if (!quiet) trSnack('Imeshindikana', message, duration: const Duration(seconds: 8));
      return false;
    } finally {
      changingRole.remove(userId);
    }
  }

  /// Fallback for a server that does not know `PUT /api/permission/role` yet.
  Future<void> _applyRoleOneByOne(int userId, String role) async {
    final allowed = kRoleFunctions[role] ?? const <String>{};
    permissionsByUserId.remove(userId);
    await loadPermissionsFor(userId);
    if ((permissionsByUserId[userId] ?? const <PermissionRow>[]).isEmpty) {
      // Without the user's permission rows nothing can be changed - say so instead of pretending.
      throw ApiException(
          'Seva haina njia mpya ya role (PUT /api/permission/role) na ruhusa za mtumiaji huyu hazikupatikana. '
          'Weka faili mpya za backend (permission/router.py, user/role.py, user/router.py, auth/router.py, user/schema.py, '
          'permission/schema.py) kisha uanzishe upya server.');
    }
    for (final fn in systemFunctions) {
      final name = fn['name']!;
      await setFunctionAccess(userId, name, allowed.contains(name));
    }
  }

  /// Kept for the permissions matrix header: same as [changeRole].
  Future<void> applyRolePreset(int userId, String roleKey) async {
    await changeRole(userId, roleKey);
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
        // Give the new user the permissions of the chosen role (Admin / Accountant).
        final newId = (created['id'] as num?)?.toInt();
        if (newId != null && kAllRoles.contains(user.role) && user.role != kRoleUser) {
          unawaited(changeRole(newId, user.role, quiet: true));
        }
      }
    }).catchError((error) {
      systemUsers.removeWhere((u) => u.id == user.id);
      trSnack('Imeshindikana Kusajili', error is ApiException ? error.message : 'Imeshindwa kusajili mtumiaji.');
    });
  }
}
