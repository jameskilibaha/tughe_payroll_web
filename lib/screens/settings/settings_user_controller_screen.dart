import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/audit_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/user_management_controller.dart';
import '../../models/permission_row.dart';
import '../../models/user.dart';
import '../../utils/csv_export_web.dart';
import '../widgets/app_status_views.dart';

const _brandBlue = Color(0xFF1E3A8A);


class SettingsUserControllerScreen extends StatefulWidget {
  const SettingsUserControllerScreen({super.key});

  @override
  State<SettingsUserControllerScreen> createState() => _SettingsUserControllerScreenState();
}

class _SettingsUserControllerScreenState extends State<SettingsUserControllerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('USER CONTROLLER & AUDIT TRAIL',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _brandBlue)),
        const SizedBox(height: 4),
        const Text('Simamia Watumiaji wa Mfumo, Nenosiri, Ruhusa (Permissions) na Rekodi ya Matukio (Audit Log)',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabController,
          labelColor: _brandBlue,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Watumiaji wa Mfumo (Users)'),
            Tab(text: 'Nenosiri (Password)'),
            Tab(text: 'Ruhusa za Mfumo (Permissions)'),
            Tab(text: 'Audit Trail (Log)'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _UsersTab(),
              _PasswordTab(),
              _PermissionsTab(),
              _AuditTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1. USERS TAB — list, block/unblock, + Ongeza Mtumiaji Mpya (Add User)
// ---------------------------------------------------------------------------

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserManagementController>();
    final auth = Get.find<AuthController>();

    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _AddUserDialog()),
                style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Ongeza Mtumiaji Mpya', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: userCtrl.isLoading.value
                  ? const AppLoadingIndicator(message: 'Inapakua watumiaji...')
                  : (userCtrl.errorMessage.value.isNotEmpty && userCtrl.systemUsers.isEmpty)
                      ? AppErrorRetryView(message: userCtrl.errorMessage.value, onRetry: userCtrl.refreshFromBackend)
                      : userCtrl.systemUsers.isEmpty
                          ? const Center(child: Text('Hakuna watumiaji bado.', style: TextStyle(color: Colors.black45)))
                          : ListView.separated(
                              itemCount: userCtrl.systemUsers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final u = userCtrl.systemUsers[i];
                  final isBlocked = u.status == 'Blocked';
                  final isSelf = auth.currentUser.value?.id == u.id;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _brandBlue,
                          child: Text(u.avatarInitials,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                if (isSelf) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration:
                                        BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('Wewe', style: TextStyle(fontSize: 9, color: _brandBlue)),
                                  ),
                                ],
                              ]),
                              Text('${u.designation} • ${u.role}', style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
                              Text(u.email, style: const TextStyle(fontSize: 10, color: Colors.black45)),
                              if (u.lastLogin != null)
                                Text('Aliingia Mwisho: ${u.lastLogin}', style: const TextStyle(fontSize: 9.5, color: Colors.black38)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isBlocked ? Colors.red.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(isBlocked ? 'Blocked' : 'Active',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isBlocked ? Colors.red.shade700 : Colors.green.shade700)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: isBlocked ? 'Fungua (Unblock)' : 'Fungia (Block)',
                          icon: Icon(isBlocked ? Icons.lock_open : Icons.lock_outline,
                              size: 18, color: isBlocked ? Colors.green.shade700 : Colors.red.shade700),
                          onPressed: isSelf
                              ? null
                              : () {
                                  userCtrl.toggleBlockUser(u.id);
                                  Get.find<AuditController>().addLog(
                                    userName: auth.currentUser.value?.name ?? 'System',
                                    userRole: auth.currentUser.value?.role ?? '-',
                                    action: isBlocked ? 'Kufungua Mtumiaji (Unblock User)' : 'Kufungia Mtumiaji (Block User)',
                                    details: '${auth.currentUser.value?.name} amebadilisha hali ya ${u.name} (${u.id}).',
                                    category: 'User Management',
                                  );
                                },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ));
  }
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'Afisa Utumishi';
  String _errorMsg = '';

  final _roles = const ['Msimamizi', 'Mhasibu Mkuu', 'Afisa Utumishi'];

  void _submit() {
    setState(() => _errorMsg = '');
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Tafadhali jaza Jina Kamili na Barua Pepe.');
      return;
    }
    if (_passwordCtrl.text.trim().length < 6) {
      setState(() => _errorMsg = 'Nenosiri la awali lazima liwe na angalau herufi/namba 6.');
      return;
    }

    final userCtrl = Get.find<UserManagementController>();
    final auth = Get.find<AuthController>();

    if (userCtrl.systemUsers.any((u) => u.email.toLowerCase() == _emailCtrl.text.trim().toLowerCase())) {
      setState(() => _errorMsg = 'Barua pepe hii tayari imesajiliwa na mtumiaji mwingine.');
      return;
    }

    final initials = _nameCtrl.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();

    final newUser = User(
      id: 'USR-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      role: _role,
      designation: _designationCtrl.text.trim().isEmpty
          ? (_role == 'Msimamizi'
              ? 'Mkurugenzi wa Mfumo'
              : _role == 'Mhasibu Mkuu'
                  ? 'Mhasibu wa Mshahara'
                  : 'Afisa Utumishi')
          : _designationCtrl.text.trim(),
      avatarInitials: initials.isEmpty ? 'NA' : initials,
      status: 'Active',
      password: _passwordCtrl.text,
      permissions: const ['sajili_watumishi', 'badili_nenosiri'],
    );

    userCtrl.addUser(newUser);
    Get.find<AuditController>().addLog(
      userName: auth.currentUser.value?.name ?? 'System',
      userRole: auth.currentUser.value?.role ?? '-',
      action: 'Usajili wa Mtumiaji Mpya (New User)',
      details: '${auth.currentUser.value?.name} amesajili mtumiaji mpya ${newUser.name} (${newUser.role}).',
      category: 'User Management',
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _designationCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Ongeza Mtumiaji Mpya wa Mfumo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _brandBlue)),
                const SizedBox(height: 12),
                if (_errorMsg.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMsg, style: TextStyle(color: Colors.red.shade800, fontSize: 11)),
                  ),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Jina Kamili', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Barua Pepe (Email)', isDense: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Wadhifa wa Mfumo (Role)', isDense: true),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _designationCtrl,
                  decoration: const InputDecoration(labelText: 'Cheo Kazini (Designation, hiari)', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nenosiri la Awali (Initial Password)', isDense: true),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ghairi')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
                      child: const Text('Sajili Mtumiaji'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. PASSWORD TAB — Badili Nenosiri (Change Password)
// ---------------------------------------------------------------------------

class _PasswordTab extends StatefulWidget {
  const _PasswordTab();

  @override
  State<_PasswordTab> createState() => _PasswordTabState();
}

class _PasswordTabState extends State<_PasswordTab> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _showPasswords = false;
  String? _errorMsg;
  String? _successMsg;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _errorMsg = null;
      _successMsg = null;
    });

    if (_newPasswordCtrl.text.length < 6) {
      setState(() => _errorMsg = 'Nenosiri jipya lazima liwe na angalau herufi au namba 6.');
      return;
    }
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _errorMsg = 'Nenosiri jipya na uthibitisho havina usawa (Passwords do not match).');
      return;
    }

    final auth = Get.find<AuthController>();
    final userCtrl = Get.find<UserManagementController>();
    final current = auth.currentUser.value;
    if (current == null) return;

    final updated = current.copyWith(password: _newPasswordCtrl.text);
    userCtrl.updateUser(updated);
    auth.setCurrentUser(updated);
    auth.changePassword(_newPasswordCtrl.text).catchError((error) {
      Get.snackbar('Imeshindikana', 'Imeshindwa kuhifadhi nenosiri jipya kwenye seva. Jaribu tena.');
    });

    Get.find<AuditController>().addLog(
      userName: current.name,
      userRole: current.role,
      action: 'Kubadilisha Nenosiri (Change Password)',
      details: '${current.name} amebadilisha nenosiri lake la kuingia mfumoni.',
      category: 'Security',
    );

    setState(() {
      _successMsg = 'Nenosiri limebadilishwa kwa mafanikio.';
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Badilisha Nenosiri Lako (Change Password)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _brandBlue)),
              const SizedBox(height: 4),
              const Text('Kwa usalama wako, tumia nenosiri imara lenye herufi kubwa/ndogo na namba.',
                  style: TextStyle(fontSize: 10.5, color: Colors.black54)),
              const SizedBox(height: 14),
              if (_errorMsg != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_errorMsg!, style: TextStyle(color: Colors.red.shade800, fontSize: 11)),
                ),
              if (_successMsg != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_successMsg!, style: TextStyle(color: Colors.green.shade800, fontSize: 11)),
                ),
              TextField(
                controller: _currentPasswordCtrl,
                obscureText: !_showPasswords,
                decoration: const InputDecoration(labelText: 'Nenosiri la Sasa (Current Password)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newPasswordCtrl,
                obscureText: !_showPasswords,
                decoration: const InputDecoration(labelText: 'Nenosiri Jipya (New Password)', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: !_showPasswords,
                decoration: const InputDecoration(labelText: 'Thibitisha Nenosiri Jipya (Confirm)', isDense: true),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: _showPasswords,
                    onChanged: (v) => setState(() => _showPasswords = v ?? false),
                  ),
                  const Text('Onyesha Manenosiri', style: TextStyle(fontSize: 11.5)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
                  icon: const Icon(Icons.key, size: 16),
                  label: const Text('Badilisha Nenosiri', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. PERMISSIONS TAB — Matrix ya Ruhusa za Mfumo kwa kila mtumiaji
// ---------------------------------------------------------------------------

class _PermissionsTab extends StatefulWidget {
  const _PermissionsTab();

  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  final _horizontalCtrl = ScrollController();
  final _verticalCtrl = ScrollController();
  bool _loadedOnce = false;

  @override
  void dispose() {
    _horizontalCtrl.dispose();
    _verticalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserManagementController>();
    final auth = Get.find<AuthController>();

    return Obx(() {
      final users = userCtrl.systemUsers;

      // Fetch each user's real permission rows once users are available -
      // guarded so it only fires the network calls the first time.
      if (!_loadedOnce && users.isNotEmpty && !userCtrl.isLoading.value) {
        _loadedOnce = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => userCtrl.loadAllPermissions());
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Text('Matrix ya Ruhusa za Mfumo kwa Kila Mtumiaji (Permissions Management)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Bofya kisanduku ili kuwasha au kuzima ruhusa kwa kazi husika (inasasisha seva mara moja). '
              'Tumia "Wajibu (Role)" chini ya jina la mtumiaji kuweka mkusanyiko wa ruhusa kwa haraka. '
              'Tumia mistari ya kusogeza (scrollbar) chini/kando kuona safu wima na safu mlalo zote.',
              style: TextStyle(fontSize: 10.5, color: Colors.black54)),
          const SizedBox(height: 12),
          Expanded(
            child: userCtrl.isLoading.value
                ? const AppLoadingIndicator(message: 'Inapakua watumiaji...')
                : (userCtrl.errorMessage.value.isNotEmpty && users.isEmpty)
                    ? AppErrorRetryView(message: userCtrl.errorMessage.value, onRetry: userCtrl.refreshFromBackend)
                    : users.isEmpty
                        ? const Center(child: Text('Hakuna watumiaji bado.', style: TextStyle(color: Colors.black45)))
                        : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              // Vertical scroll works fine natively (mouse wheel/trackpad) so
              // it doesn't need its own Scrollbar wrapper - wrapping BOTH
              // directions in nested Scrollbars caused a RenderBox layout
              // crash (a Scrollbar's CustomPaint needs a bounded size, and
              // nesting one inside an unbounded vertical scroll broke that).
              // Only horizontal scrolling needs a visible, draggable handle.
              child: SingleChildScrollView(
                controller: _verticalCtrl,
                child: Scrollbar(
                  controller: _horizontalCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalCtrl,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        const DataColumn(label: Text('Ruhusa (Permission)')),
                        ...users.map((u) => DataColumn(
                              label: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  Text(u.role, style: const TextStyle(fontSize: 9, color: Colors.black45)),
                                  if (u.backendId != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: DropdownButton<String>(
                                        isDense: true,
                                        underline: const SizedBox.shrink(),
                                        hint: const Text('Wajibu (Role)', style: TextStyle(fontSize: 9)),
                                        style: const TextStyle(fontSize: 9, color: _brandBlue),
                                        items: rolePresets.keys
                                            .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 9))))
                                            .toList(),
                                        onChanged: auth.currentUser.value?.id == u.id
                                            ? null
                                            : (role) {
                                                if (role == null) return;
                                                userCtrl.applyRolePreset(u.backendId!, role);
                                                Get.find<AuditController>().addLog(
                                                  userName: auth.currentUser.value?.name ?? 'System',
                                                  userRole: auth.currentUser.value?.role ?? '-',
                                                  action: 'Wajibu (Role) Umewekwa',
                                                  details: '${auth.currentUser.value?.name} amemweka ${u.name} kama "$role".',
                                                  category: 'User Management',
                                                );
                                              },
                                      ),
                                    ),
                                ],
                              ),
                            )),
                      ],
                      rows: systemFunctions.map((fn) {
                        final functionName = fn['name']!;
                        return DataRow(cells: [
                          DataCell(SizedBox(
                            width: 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(fn['label']!, style: const TextStyle(fontSize: 11), softWrap: true),
                                Text(fn['category']!, style: const TextStyle(fontSize: 9, color: Colors.black45)),
                              ],
                            ),
                          )),
                          ...users.map((u) {
                            final backendId = u.backendId;
                            final isSelf = auth.currentUser.value?.id == u.id;
                            if (backendId == null) {
                              return const DataCell(Tooltip(
                                message: 'Mtumiaji huyu bado hajahifadhiwa kwenye seva.',
                                child: Icon(Icons.hourglass_empty, size: 16, color: Colors.black26),
                              ));
                            }
                            final rows = userCtrl.permissionsByUserId[backendId];
                            if (rows == null) {
                              return const DataCell(SizedBox(
                                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                            }
                            final row = rows.where((r) => r.functionName == functionName).firstOrNull;
                            final granted = row?.hasFullAccess ?? false;
                            final key = '$backendId:$functionName';
                            final isSaving = userCtrl.savingPermissionKeys.contains(key);
                            return DataCell(isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Checkbox(
                                    value: granted,
                                    onChanged: (isSelf || row == null)
                                        ? null
                                        : (checked) {
                                            userCtrl.setFunctionAccess(backendId, functionName, checked == true);
                                            Get.find<AuditController>().addLog(
                                              userName: auth.currentUser.value?.name ?? 'System',
                                              userRole: auth.currentUser.value?.role ?? '-',
                                              action: 'Mabadiliko ya Ruhusa (Permissions Update)',
                                              details:
                                                  '${auth.currentUser.value?.name} ame${checked == true ? "washa" : "zima"} ruhusa "${fn['label']}" kwa ${u.name}.',
                                              category: 'User Management',
                                            );
                                          },
                                  ));
                          }),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}


// ---------------------------------------------------------------------------
// 4. AUDIT TAB — search, category filter, CSV download, clear all
// ---------------------------------------------------------------------------

class _AuditTab extends StatefulWidget {
  const _AuditTab();

  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';

  static const _categories = [
    'All',
    'Security',
    'User Management',
    'Payroll Settings',
    'Employee Management',
    'Reports',
    'System',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditCtrl = Get.find<AuditController>();

    return Obx(() {
      final query = _searchCtrl.text.toLowerCase();
      final filtered = auditCtrl.auditLogs.where((log) {
        final matchesSearch = query.isEmpty ||
            log.userName.toLowerCase().contains(query) ||
            log.action.toLowerCase().contains(query) ||
            log.details.toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == 'All' || log.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;
            final searchField = TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 16),
                hintText: 'Tafuta kwa jina, kitendo au maelezo...',
              ),
            );
            final categoryDropdown = DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(isDense: true, labelText: 'Aina (Category)'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11.5))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
            );
            final actionButtons = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: auditCtrl.auditLogs.isEmpty ? null : () => exportAuditLogsCsv(auditCtrl.auditLogs),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Pakua (CSV)', style: TextStyle(fontSize: 11)),
                ),
                TextButton.icon(
                  onPressed: auditCtrl.auditLogs.isEmpty
                      ? null
                      : () => _confirmClear(context, auditCtrl),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.red),
                  label: const Text('Futa Rekodi Zote', style: TextStyle(fontSize: 11, color: Colors.red)),
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 8),
                  categoryDropdown,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: actionButtons),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 2, child: searchField),
                const SizedBox(width: 10),
                SizedBox(width: 220, child: categoryDropdown),
                const SizedBox(width: 10),
                actionButtons,
              ],
            );
          }),
          const SizedBox(height: 6),
          Text('Jumla: ${filtered.length} / ${auditCtrl.auditLogs.length} Rekodi',
              style: const TextStyle(fontSize: 10, color: Colors.black45)),
          const SizedBox(height: 8),
          Expanded(
            child: auditCtrl.isLoading.value
                ? const AppLoadingIndicator(message: 'Inapakua kumbukumbu (audit log)...')
                : (auditCtrl.errorMessage.value.isNotEmpty && auditCtrl.auditLogs.isEmpty)
                    ? AppErrorRetryView(message: auditCtrl.errorMessage.value, onRetry: auditCtrl.refreshFromBackend)
                    : filtered.isEmpty
                ? Center(
                    child: Text(
                      auditCtrl.auditLogs.isEmpty
                          ? 'Hakuna Rekodi za Audit.'
                          : 'Hakuna Rekodi Zinazolingana na Utafutaji.',
                      style: const TextStyle(color: Colors.black45),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final log = filtered[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: _categoryColor(log.category).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(log.category,
                                    style: TextStyle(fontSize: 9, color: _categoryColor(log.category), fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Text(log.timestamp, style: const TextStyle(fontSize: 9.5, color: Colors.black45)),
                            ]),
                            const SizedBox(height: 4),
                            Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(log.details, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
                            const SizedBox(height: 2),
                            Row(children: [
                              Expanded(
                                child: Text('${log.userName} (${log.userRole})',
                                    style: const TextStyle(fontSize: 10, color: Colors.black38)),
                              ),
                              if (log.ipAddress != null) ...[
                                Icon(Icons.language, size: 11, color: Colors.black26),
                                const SizedBox(width: 3),
                                Text(log.ipAddress!, style: const TextStyle(fontSize: 9.5, color: Colors.black38)),
                                const SizedBox(width: 8),
                              ],
                              if (log.statusCode != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: log.isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${log.statusCode}',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: log.isSuccess ? Colors.green.shade700 : Colors.red.shade700)),
                                ),
                            ]),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }

  void _confirmClear(BuildContext context, AuditController auditCtrl) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Futa Rekodi Zote za Audit?'),
        content: const Text(
            'Je, una uhakika unataka kufuta kumbukumbu zote za mfumo (Audit Logs)? Hatua hii haiwezi kutenduliwa.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Ghairi')),
          TextButton(
            onPressed: () {
              auditCtrl.clearLogs();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Futa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Security':
        return Colors.red.shade700;
      case 'User Management':
        return Colors.purple.shade700;
      case 'Payroll Settings':
        return _brandBlue;
      case 'Employee Management':
        return Colors.green.shade700;
      case 'Reports':
        return Colors.teal.shade700;
      case 'System':
        return Colors.blueGrey.shade700;
      default:
        return Colors.black54;
    }
  }
}
