import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/audit_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/user_management_controller.dart';
import '../../models/audit_log_entry.dart';
import '../../models/permission_row.dart';
import '../../models/user.dart';
import '../../network/api_exception.dart';
import '../../utils/csv_export_web.dart';
import '../widgets/app_status_views.dart';
import '../widgets/pagination_bar.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../core/tr_snack.dart';
import '../../core/theme.dart';

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
    final auth = Get.find<AuthController>();
    return Obx(() {
      if (!auth.isAdmin) {
        // An Accountant manages only their own password; users, permissions and the
        // audit log are for the Admin.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('NENOSIRI LANGU (MY PASSWORD)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Pal.brandText)),
            const SizedBox(height: 4),
            Text('Badilisha nenosiri lako la kuingia kwenye mfumo.',
                style: TextStyle(fontSize: 11, color: Pal.textSecondary)),
            const SizedBox(height: 12),
            const Expanded(child: _PasswordTab()),
          ],
        );
      }
      return _adminView();
    });
  }

  Widget _adminView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('USER CONTROLLER & AUDIT TRAIL',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Pal.brandText)),
        const SizedBox(height: 4),
        Text('Simamia Watumiaji wa Mfumo, Nenosiri, Ruhusa (Permissions) na Rekodi ya Matukio (Audit Log)',
            style: TextStyle(fontSize: 11, color: Pal.textSecondary)),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabController,
          labelColor: Pal.brandText,
          isScrollable: true,
          tabs: [
            Tab(text: tr('Watumiaji wa Mfumo (Users)')),
            Tab(text: tr('Nenosiri (Password)')),
            Tab(text: tr('Ruhusa za Mfumo (Permissions)')),
            Tab(text: tr('Audit Trail (Log)')),
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

/// Asks for confirmation, then gives [u] the role [newRole]. The SERVER switches all the matching
/// permissions at once; a failure is shown in a dialog that stays until it is read.
Future<void> _confirmAndChangeRole(BuildContext context, User u, String newRole) async {
  if (u.backendId == null || newRole == u.role) return;
  final userCtrl = Get.find<UserManagementController>();
  final auth = Get.find<AuthController>();
  final warning = newRole == kRoleUser
      ? 'Atapoteza ruhusa zote na HATAWEZA kuingia kwenye mfumo huu.'
      : newRole == kRoleAdmin
          ? 'Atapata ruhusa zote, ikiwemo kusimamia watumiaji na ruhusa.'
          : newRole == kRoleHr
              ? 'Atapata kazi za HR (wafanyakazi, rekodi, likizo) lakini HATAONA mishahara wala payroll.'
              : 'Atapata ruhusa za kazi za payroll (bila kusimamia watumiaji).';
  final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Badilisha Role'),
          content: Text('Kumpa ${u.name} role ya ${roleLabel(newRole)}?\n\n$warning'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Ghairi')),
            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Ndiyo, Badilisha')),
          ],
        ),
      ) ??
      false;
  if (!ok) return;
  final done = await userCtrl.changeRole(u.backendId!, newRole);
  if (!done) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.error_outline, color: Colors.red.shade700, size: 30),
        title: const Text('Imeshindikana kubadilisha role'),
        content: SelectableText(
          '${userCtrl.lastRoleError.value ?? 'Hitilafu isiyojulikana'}\n\n'
          'Kama hujaanzisha upya server ya backend baada ya kuweka faili mpya, ianzishe upya kisha ujaribu tena.',
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Sawa'))],
      ),
    );
    return;
  }
  Get.find<AuditController>().addLog(
    userName: auth.currentUser.value?.name ?? 'System',
    userRole: auth.currentUser.value?.role ?? '-',
    action: 'Kubadilisha Role (Change Role)',
    details: '${auth.currentUser.value?.name} amembadilisha ${u.name} kutoka ${u.role} kuwa $newRole.',
    category: 'User Management',
  );
}

// ---------------------------------------------------------------------------
// 1. USERS TAB — list, block/unblock, + Ongeza Mtumiaji Mpya (Add User)
// ---------------------------------------------------------------------------

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _query = '';
  String _roleFilter = 'All';
  int _page = 0;
  int _pageSize = 10;
  String _pageKey = '';

  MaterialColor _roleColor(String role) => switch (role) {
        kRoleAdmin => Colors.purple,
        kRoleAccountant => Colors.blue,
        kRoleHr => Colors.teal,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserManagementController>();
    final auth = Get.find<AuthController>();

    return Obx(() {
      final all = userCtrl.systemUsers.toList();
      final counts = {for (final r in kAllRoles) r: all.where((u) => u.role == r).length};
      final q = _query.trim().toLowerCase();
      final filtered = all.where((u) {
        if (_roleFilter != 'All' && u.role != _roleFilter) return false;
        if (q.isEmpty) return true;
        return u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.username ?? '').toLowerCase().contains(q) ||
            u.designation.toLowerCase().contains(q);
      }).toList();

      final pageKey = '$q|$_roleFilter';
      if (pageKey != _pageKey) {
        _pageKey = pageKey;
        _page = 0;
      }
      final visible = pageSlice(filtered, _page, _pageSize);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: InputDecoration(
                      isDense: true, prefixIcon: const Icon(Icons.search, size: 16), hintText: tr('Tafuta mtumiaji...')),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              for (final r in ['All', ...kAllRoles])
                ChoiceChip(
                  label: Text(
                    r == 'All' ? 'Wote (${all.length})' : '${roleLabel(r)} (${counts[r]})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _roleFilter == r,
                  onSelected: (_) => setState(() => _roleFilter = r),
                ),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _AddUserDialog()),
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Ongeza Mtumiaji Mpya', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Wafanyakazi wanaosajiliwa huanza kama User (hawaingii kwenye mfumo). Badilisha role hapa: Admin au Accountant ndio pekee wanaoweza kuingia.',
            style: TextStyle(fontSize: 10.5, color: Pal.textMuted),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: userCtrl.isLoading.value
                ? const AppLoadingIndicator(message: 'Inapakua watumiaji...')
                : (userCtrl.errorMessage.value.isNotEmpty && userCtrl.systemUsers.isEmpty)
                    ? AppErrorRetryView(message: userCtrl.errorMessage.value, onRetry: userCtrl.refreshFromBackend)
                    : filtered.isEmpty
                        ? Center(child: Text('Hakuna watumiaji wanaolingana.', style: TextStyle(color: Pal.textMuted)))
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.separated(
                                  itemCount: visible.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) => _tile(visible[i], userCtrl, auth),
                                ),
                              ),
                              PaginationBar(
                                total: filtered.length,
                                page: _page,
                                pageSize: _pageSize,
                                pageSizes: const [10, 25, 50, 100],
                                onPageChanged: (p) => setState(() => _page = p),
                                onPageSizeChanged: (n) => setState(() {
                                  _pageSize = n;
                                  _page = 0;
                                }),
                              ),
                            ],
                          ),
          ),
        ],
      );
    });
  }

  Widget _tile(User u, UserManagementController userCtrl, AuthController auth) {
    final isBlocked = u.status == 'Blocked';
    final isSelf = auth.currentUser.value?.id == u.id;
    final changing = u.backendId != null && userCtrl.changingRole.contains(u.backendId);
    final color = _roleColor(u.role);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pal.border),
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
                  Flexible(child: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                  if (isSelf) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Pal.tint(Colors.blue), borderRadius: BorderRadius.circular(4)),
                      child: Text('Wewe', style: TextStyle(fontSize: 9, color: Pal.brandText)),
                    ),
                  ],
                ]),
                Text('${u.designation.isEmpty ? '-' : u.designation}${u.username == null ? '' : '  •  @${u.username}'}',
                    style: TextStyle(fontSize: 10.5, color: Pal.textSecondary), overflow: TextOverflow.ellipsis),
                if (u.email.isNotEmpty) Text(u.email, style: TextStyle(fontSize: 10, color: Pal.textMuted)),
                if (u.lastLogin != null)
                  Text('Aliingia Mwisho: ${u.lastLogin}', style: TextStyle(fontSize: 9.5, color: Pal.textMuted)),
              ],
            ),
          ),
          // Role: colour badge + (for everybody except yourself) a dropdown to change it.
          if (changing)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Tooltip(
              message: isSelf ? tr('Huwezi kubadilisha role yako mwenyewe') : tr('Badilisha role'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: Pal.tint(color), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: kAllRoles.contains(u.role) ? u.role : kRoleUser,
                    isDense: true,
                    iconSize: 18,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Pal.fg(color.shade700)),
                    onChanged: (isSelf || u.backendId == null) ? null : (r) => _confirmAndChangeRole(context, u, r ?? u.role),
                    items: [
                      for (final r in kAllRoles)
                        DropdownMenuItem(
                          value: r,
                          child: Text(roleLabel(r), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isBlocked ? Pal.tint(Colors.red) : Pal.tint(Colors.green),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isBlocked ? 'Blocked' : 'Active',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isBlocked ? Pal.fg(Colors.red.shade700) : Pal.fg(Colors.green.shade700))),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: tr(isBlocked ? 'Fungua (Unblock)' : 'Fungia (Block)'),
            icon: Icon(isBlocked ? Icons.lock_open : Icons.lock_outline,
                size: 18, color: isBlocked ? Pal.fg(Colors.green.shade700) : Pal.fg(Colors.red.shade700)),
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
  String _role = kRoleAccountant;
  String _errorMsg = '';

  final _roles = const [kRoleAdmin, kRoleAccountant, kRoleHr, kRoleUser];

  void _submit() {
    setState(() => _errorMsg = '');
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Tafadhali jaza Jina Kamili na Barua Pepe.');
      return;
    }
    if (_passwordCtrl.text.trim().length < 8) {
      setState(() => _errorMsg = 'Nenosiri la awali lazima liwe na angalau herufi/namba 8.');
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
          ? (_role == kRoleAdmin ? 'Msimamizi wa Mfumo' : (_role == kRoleUser ? 'Mfanyakazi' : (_role == kRoleHr ? 'Afisa Rasilimali Watu' : 'Mhasibu wa Mshahara')))
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
                Text('Ongeza Mtumiaji Mpya wa Mfumo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Pal.brandText)),
                const SizedBox(height: 12),
                if (_errorMsg.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Pal.tint(Colors.red), borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMsg, style: TextStyle(color: Pal.fg(Colors.red.shade800), fontSize: 11)),
                  ),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: tr('Jina Kamili'), isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(labelText: tr('Barua Pepe (Email)'), isDense: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: InputDecoration(labelText: tr('Wadhifa wa Mfumo (Role)'), isDense: true),
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(roleLabel(r), style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _designationCtrl,
                  decoration: InputDecoration(labelText: tr('Cheo Kazini (Designation, hiari)'), isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(labelText: tr('Nenosiri la Awali (Initial Password)'), isDense: true),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ghairi')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submit,
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
  bool _saving = false;
  String? _errorMsg;
  String? _successMsg;

  /// Id of the user whose password is being changed. null = the logged-in
  /// user (own password); otherwise any other system user (admin action).
  String? _targetId;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMsg = null;
      _successMsg = null;
    });

    if (_newPasswordCtrl.text.length < 8) {
      setState(() => _errorMsg = 'Nenosiri jipya lazima liwe na angalau herufi au namba 8.');
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

    final target = _targetId == null || _targetId == current.id
        ? null
        : userCtrl.systemUsers.firstWhereOrNull((u) => u.id == _targetId);

    // ---- Changing ANOTHER user's password (admin action) ----
    if (target != null) {
      if (target.backendId == null) {
        setState(() => _errorMsg = 'Mtumiaji huyu bado hajahifadhiwa kwenye seva.');
        return;
      }
      setState(() => _saving = true);
      try {
        await userCtrl.changeUserPassword(target, _newPasswordCtrl.text);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _errorMsg = error is ApiException
              ? error.message
              : 'Imeshindwa kuhifadhi nenosiri jipya kwenye seva. Jaribu tena.';
        });
        return;
      }
      Get.find<AuditController>().addLog(
        userName: current.name,
        userRole: current.role,
        action: 'Kubadilisha Nenosiri la Mtumiaji (Change User Password)',
        details: '${current.name} amebadilisha nenosiri la ${target.name}.',
        category: 'Security',
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _successMsg = 'Nenosiri la ${target.name} limebadilishwa kwa mafanikio.';
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      });
      return;
    }

    // ---- Changing OWN password ----
    final updated = current.copyWith(password: _newPasswordCtrl.text);
    userCtrl.updateUser(updated);
    auth.setCurrentUser(updated);
    auth.changePassword(_newPasswordCtrl.text, currentPassword: _currentPasswordCtrl.text).catchError((error) {
      trSnack('Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kuhifadhi nenosiri jipya kwenye seva. Jaribu tena.');
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
            color: Pal.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Badilisha Nenosiri (Change Password)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Pal.brandText)),
              const SizedBox(height: 4),
              Text('Chagua mtumiaji yeyote kubadilisha nenosiri lake, au chagua jina lako mwenyewe. Tumia nenosiri imara lenye herufi kubwa/ndogo na namba.',
                  style: TextStyle(fontSize: 10.5, color: Pal.textSecondary)),
              const SizedBox(height: 14),
              if (Get.find<AuthController>().isAdmin)
              Obx(() {
                final users = Get.find<UserManagementController>().systemUsers;
                final me = Get.find<AuthController>().currentUser.value;
                final selected = _targetId ?? me?.id;
                final ids = users.map((u) => u.id).toList();
                return DropdownButtonFormField<String>(
                  value: ids.contains(selected) ? selected : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('Mtumiaji (User)'), isDense: true),
                  items: users
                      .map((u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.id == me?.id ? '${u.name} (Wewe)' : '${u.name} • ${u.role}',
                                style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _targetId = v;
                    _errorMsg = null;
                    _successMsg = null;
                  }),
                );
              }),
              const SizedBox(height: 10),
              if (_errorMsg != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Pal.tint(Colors.red), borderRadius: BorderRadius.circular(8)),
                  child: Text(_errorMsg!, style: TextStyle(color: Pal.fg(Colors.red.shade800), fontSize: 11)),
                ),
              if (_successMsg != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Pal.tint(Colors.green), borderRadius: BorderRadius.circular(8)),
                  child: Text(_successMsg!, style: TextStyle(color: Pal.fg(Colors.green.shade800), fontSize: 11)),
                ),
              if (_targetId == null || _targetId == Get.find<AuthController>().currentUser.value?.id) ...[
                TextField(
                  controller: _currentPasswordCtrl,
                  obscureText: !_showPasswords,
                  decoration: InputDecoration(labelText: tr('Nenosiri la Sasa (Current Password)'), isDense: true),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _newPasswordCtrl,
                obscureText: !_showPasswords,
                decoration: InputDecoration(labelText: tr('Nenosiri Jipya (New Password)'), isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordCtrl,
                obscureText: !_showPasswords,
                decoration: InputDecoration(labelText: tr('Thibitisha Nenosiri Jipya (Confirm)'), isDense: true),
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
                  onPressed: _saving ? null : _submit,
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
// 3. PERMISSIONS TAB — pick a person, see what they may do, change it
// ---------------------------------------------------------------------------

class _PermissionsTab extends StatefulWidget {
  const _PermissionsTab();

  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  final _searchCtrl = TextEditingController();
  bool _showAllUsers = false;
  int? _selectedId; // backend id of the person being edited
  final Set<String> _open = {}; // functions whose 5 detailed switches are open

  static const _categoryOrder = ['Watumishi', 'HR', 'Payroll', 'Ripoti', 'Usimamizi', 'Usalama'];

  static const _roleHelp = {
    kRoleAdmin: 'Anasimamia watumiaji, ruhusa na kila kitu kingine.',
    kRoleAccountant: 'Payroll Officer: anafanya kazi za payroll; hasimamii watumiaji wala ruhusa.',
    kRoleHr: 'HR: anasimamia wafanyakazi, rekodi na likizo; haoni mishahara wala payroll.',
    kRoleUser: 'Hana ruhusa yoyote; haingii kwenye admin panel.',
  };

  static const _flags = [
    ('select', 'Ona (View)'),
    ('insert', 'Ongeza (Add)'),
    ('update', 'Hariri (Edit)'),
    ('delete', 'Futa (Delete)'),
    ('block', 'Fungia (Block)'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  MaterialColor _roleColor(String role) => switch (role) {
        kRoleAdmin => Colors.purple,
        kRoleAccountant => Colors.blue,
        kRoleHr => Colors.teal,
        _ => Colors.blueGrey,
      };

  Future<void> _select(int id) async {
    setState(() => _selectedId = id);
    await Get.find<UserManagementController>().loadPermissionsFor(id);
  }

  bool _flagValue(PermissionRow row, String flag) => switch (flag) {
        'insert' => row.dataInsert,
        'update' => row.dataUpdate,
        'delete' => row.dataDelete,
        'block' => row.dataBlock,
        _ => row.dataSelect,
      };

  int _grantedCount(PermissionRow row) => _flags.where((f) => _flagValue(row, f.$1)).length;

  /// Removing your OWN access to users/permissions locks you out of this very screen: ask first.
  Future<bool> _confirmSelfRisk(User u, String function, {required bool revoking}) async {
    final isSelf = Get.find<AuthController>().currentUser.value?.id == u.id;
    if (!revoking || !isSelf || !(function == 'USER' || function == 'PERMISSION')) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 30),
            title: const Text('Unaondoa ruhusa yako mwenyewe'),
            content: const Text(
                'Ukiondoa ruhusa ya kusimamia watumiaji au ruhusa kutoka kwa akaunti yako, hutaweza kuirudisha mwenyewe. Mwingine mwenye ruhusa hiyo ndiye atakayeirudisha.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Ghairi')),
              ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Ndiyo, Ondoa')),
            ],
          ),
        ) ??
        false;
  }

  void _log(User u, String function, String what) {
    final auth = Get.find<AuthController>();
    Get.find<AuditController>().addLog(
      userName: auth.currentUser.value?.name ?? 'System',
      userRole: auth.currentUser.value?.role ?? '-',
      action: 'Mabadiliko ya Ruhusa (Permissions Update)',
      details: '${auth.currentUser.value?.name} amebadilisha ruhusa ya $function ya ${u.name}: $what.',
      category: 'User Management',
    );
  }

  Future<void> _setAll(User u, String function, bool granted) async {
    if (!await _confirmSelfRisk(u, function, revoking: !granted)) return;
    final ok = await Get.find<UserManagementController>().setFunctionAccess(u.backendId!, function, granted);
    if (ok) _log(u, function, granted ? 'ruhusa kamili imewashwa' : 'ruhusa zote zimeondolewa');
  }

  Future<void> _setFlag(User u, String function, String flag, bool value) async {
    if (!await _confirmSelfRisk(u, function, revoking: flag == 'select' && !value)) return;
    final ok = await Get.find<UserManagementController>().setFunctionFlags(
      u.backendId!,
      function,
      insert: flag == 'insert' ? value : null,
      update: flag == 'update' ? value : null,
      select: flag == 'select' ? value : null,
      delete: flag == 'delete' ? value : null,
      block: flag == 'block' ? value : null,
    );
    if (ok) _log(u, function, '$flag ${value ? 'imewashwa' : 'imezimwa'}');
  }

  @override
  Widget build(BuildContext context) {
    final userCtrl = Get.find<UserManagementController>();

    return Obx(() {
      final everyone = userCtrl.systemUsers.where((u) => u.backendId != null).toList();
      if (everyone.isEmpty) {
        return userCtrl.isLoading.value
            ? const AppLoadingIndicator(message: 'Inapakua watumiaji...')
            : AppErrorRetryView(
                message: userCtrl.errorMessage.value.isNotEmpty ? userCtrl.errorMessage.value : 'Hakuna watumiaji bado.',
                onRetry: userCtrl.refreshFromBackend);
      }

      final q = _searchCtrl.text.trim().toLowerCase();
      final listed = everyone.where((u) {
        // Plain Users have no permissions: hidden unless asked for (or already selected).
        if (!_showAllUsers && u.role == kRoleUser && u.backendId != _selectedId) return false;
        if (q.isEmpty) return true;
        return u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q) || (u.username ?? '').toLowerCase().contains(q);
      }).toList();

      if (_selectedId == null && listed.isNotEmpty) {
        final first = listed.first.backendId!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedId == null) _select(first);
        });
      }
      final selected = everyone.firstWhereOrNull((u) => u.backendId == _selectedId);

      return LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final editor = selected == null
            ? Center(child: Text('Chagua mtu upande wa kushoto kuona na kubadilisha ruhusa zake.', style: TextStyle(color: Pal.textMuted)))
            : _editor(context, selected, userCtrl);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: _userList(listed, everyone.length)),
              const SizedBox(width: 16),
              Expanded(child: editor),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: listed.any((u) => u.backendId == _selectedId) ? _selectedId : null,
              isExpanded: true,
              decoration: InputDecoration(isDense: true, labelText: tr('Mtumiaji (User)')),
              items: [
                for (final u in listed)
                  DropdownMenuItem(value: u.backendId, child: Text('${u.name}  -  ${roleLabel(u.role)}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => v == null ? null : _select(v),
            ),
            FilterChip(
              avatar: Icon(_showAllUsers ? Icons.visibility : Icons.visibility_off, size: 16),
              label: Text(_showAllUsers ? 'Wote wanaonyeshwa' : 'Onyesha pia User (wafanyakazi wa kawaida)', style: const TextStyle(fontSize: 11)),
              selected: _showAllUsers,
              onSelected: (v) => setState(() => _showAllUsers = v),
            ),
            const SizedBox(height: 8),
            Expanded(child: editor),
          ],
        );
      });
    });
  }

  // ---- left: the people -------------------------------------------------------------------

  Widget _userList(List<User> listed, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search, size: 16), hintText: tr('Tafuta mtumiaji...')),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            avatar: Icon(_showAllUsers ? Icons.visibility : Icons.visibility_off, size: 16),
            label: Text(_showAllUsers ? 'Wote wanaonyeshwa' : 'Onyesha pia User (wafanyakazi wa kawaida)', style: const TextStyle(fontSize: 11)),
            selected: _showAllUsers,
            onSelected: (v) => setState(() => _showAllUsers = v),
          ),
        ),
        const SizedBox(height: 4),
        Text('Wanaoonekana: ${listed.length} / $total', style: TextStyle(fontSize: 10, color: Pal.textMuted)),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            itemCount: listed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final u = listed[i];
              final active = u.backendId == _selectedId;
              final color = _roleColor(u.role);
              return Material(
                color: active ? Pal.tint(Colors.blue) : Pal.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _select(u.backendId!),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? Pal.fg(Colors.blue.shade700) : Pal.border, width: active ? 1.6 : 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _brandBlue,
                          child: Text(u.avatarInitials, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              Text(u.email, style: TextStyle(fontSize: 10, color: Pal.textMuted), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: Pal.tint(color), borderRadius: BorderRadius.circular(6)),
                          child: Text(u.role.isEmpty ? '-' : u.role, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Pal.fg(color.shade700))),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- right: one person's role and permissions --------------------------------------------

  Widget _editor(BuildContext context, User u, UserManagementController ctrl) {
    final id = u.backendId!;
    final isSelf = Get.find<AuthController>().currentUser.value?.id == u.id;
    final changing = ctrl.changingRole.contains(id);
    final rows = ctrl.permissionsByUserId[id];
    final color = _roleColor(u.role);

    int granted = 0;
    if (rows != null) {
      for (final fn in systemFunctions) {
        final row = rows.firstWhereOrNull((r) => r.functionName == fn['name']);
        if (row != null && row.hasAnyAccess) granted++;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 24),
      children: [
        // who
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _brandBlue,
                child: Text(u.avatarInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    Text(u.email, style: TextStyle(fontSize: 11, color: Pal.textSecondary)),
                    if (isSelf) Text('Huyu ni wewe', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Pal.brandText)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Pal.tint(color), borderRadius: BorderRadius.circular(8)),
                child: Text(roleLabel(u.role), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Pal.fg(color.shade700))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // role
        Text('Jukumu (Role)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Pal.brandText)),
        const SizedBox(height: 2),
        Text(
          isSelf
              ? 'Huwezi kubadilisha jukumu lako mwenyewe.'
              : 'Kuchagua jukumu kunawasha au kuzima ruhusa zote zinazohusika kwa hatua moja.',
          style: TextStyle(fontSize: 10.5, color: Pal.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final role in kAllRoles)
              _roleCard(context, u, role, disabled: isSelf || changing),
          ],
        ),
        if (changing)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        const SizedBox(height: 22),

        // permissions
        Row(
          children: [
            Expanded(child: Text('Ruhusa za kina', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Pal.brandText))),
            if (rows != null && rows.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Pal.surfaceAlt, borderRadius: BorderRadius.circular(20)),
                child: Text('$granted kati ya ${systemFunctions.length} zimewashwa', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Pal.textSecondary)),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text('Washa au zima kazi nzima kwa swichi; bonyeza mshale kuchagua vitendo kimoja kimoja. Kila badiliko linahifadhiwa mara moja.',
            style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
        const SizedBox(height: 10),
        if (rows == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
        else if (rows.isEmpty)
          _NoRowsNotice(onRetry: () {
            ctrl.permissionsByUserId.remove(id);
            ctrl.loadPermissionsFor(id);
          })
        else
          for (final category in _categoryOrder) ..._group(u, category, rows, ctrl),
      ],
    );
  }

  Widget _roleCard(BuildContext context, User u, String role, {required bool disabled}) {
    final selected = u.role == role;
    final color = _roleColor(role);
    return SizedBox(
      width: 236,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: (disabled || selected) ? null : () => _confirmAndChangeRole(context, u, role),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? Pal.tint(color) : Pal.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Pal.fg(color.shade700) : Pal.border, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: selected ? Pal.fg(color.shade700) : Pal.textMuted),
                const SizedBox(width: 6),
                Expanded(child: Text(roleLabel(role), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: disabled && !selected ? Pal.textMuted : null))),
              ]),
              const SizedBox(height: 4),
              Text(_roleHelp[role] ?? '', style: TextStyle(fontSize: 10.5, height: 1.3, color: Pal.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _group(User u, String category, List<PermissionRow> rows, UserManagementController ctrl) {
    final functions = systemFunctions.where((f) => f['category'] == category).toList();
    if (functions.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Text(category, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Pal.textSecondary)),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Pal.border)),
        child: Column(
          children: [
            for (var i = 0; i < functions.length; i++) ...[
              _functionRow(u, functions[i], rows.firstWhereOrNull((r) => r.functionName == functions[i]['name']), ctrl),
              if (i != functions.length - 1) Divider(height: 1, color: Pal.border),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _functionRow(User u, Map<String, String> fn, PermissionRow? row, UserManagementController ctrl) {
    final name = fn['name']!;
    final id = u.backendId!;
    final saving = ctrl.savingPermissionKeys.contains('$id:$name');
    final open = _open.contains(name);

    if (row == null) {
      return ListTile(
        dense: true,
        title: Text(fn['label']!, style: const TextStyle(fontSize: 12)),
        subtitle: Text('Hakuna safu ya ruhusa hii kwa mtumiaji huyu.', style: TextStyle(fontSize: 10, color: Pal.textMuted)),
      );
    }

    final count = _grantedCount(row);
    final status = row.hasFullAccess ? 'Ruhusa kamili' : (count > 0 ? 'Sehemu ($count kati ya 5)' : 'Hakuna ruhusa');
    final statusColor = row.hasFullAccess ? Colors.green.shade700 : (count > 0 ? Colors.orange.shade800 : Pal.textMuted);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fn['label']!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor)),
                  ],
                ),
              ),
              if (saving)
                const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              else
                Switch(value: row.hasAnyAccess, onChanged: (v) => _setAll(u, name, v)),
              IconButton(
                tooltip: tr(open ? 'Ficha vitendo' : 'Chagua vitendo kimoja kimoja'),
                visualDensity: VisualDensity.compact,
                icon: Icon(open ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => open ? _open.remove(name) : _open.add(name)),
              ),
            ],
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final flag in _flags)
                    FilterChip(
                      label: Text(flag.$2, style: const TextStyle(fontSize: 11)),
                      selected: _flagValue(row, flag.$1),
                      onSelected: saving ? null : (v) => _setFlag(u, name, flag.$1, v),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown when the server returned no permission rows for a person.
class _NoRowsNotice extends StatelessWidget {
  const _NoRowsNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Pal.tint(Colors.orange), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Seva haikurudisha ruhusa za mtumiaji huyu. Jaribu tena; ikiendelea, hakikisha faili mpya za backend zimewekwa na server imeanzishwa upya.',
              style: TextStyle(fontSize: 11.5, color: Pal.text),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Jaribu Tena')),
        ],
      ),
    );
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
  int _page = 0;
  int _pageSize = 25;
  String _pageKey = '';
  bool _exporting = false;

  bool _matches(AuditLogEntry log, String query) {
    final matchesSearch = query.isEmpty ||
        log.userName.toLowerCase().contains(query) ||
        log.action.toLowerCase().contains(query) ||
        log.details.toLowerCase().contains(query);
    final matchesCategory = _selectedCategory == 'All' || log.category == _selectedCategory;
    return matchesSearch && matchesCategory;
  }

  /// Downloads the audit log as a CSV file: the WHOLE history from the server (the screen itself
  /// shows only the newest entries), narrowed by the search and category you have set.
  Future<void> _export(AuditController auditCtrl) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final all = await auditCtrl.fetchAllForExport();
      final query = _searchCtrl.text.toLowerCase();
      final rows = all.where((log) => _matches(log, query)).toList();
      if (rows.isEmpty) {
        trSnack('Hakuna cha kupakua', 'Hakuna rekodi zinazolingana na utafutaji wako.');
        return;
      }
      exportAuditLogsCsv(rows);
      trSnack('Imefanikiwa', 'Faili la CSV lenye rekodi ${rows.length} limepakuliwa.');
    } on ApiException catch (error) {
      trSnack('Imeshindikana kupakua', error.message);
    } catch (error) {
      trSnack('Imeshindikana kupakua', 'Imeshindwa kutengeneza faili: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

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
      final filtered = auditCtrl.auditLogs.where((log) => _matches(log, query)).toList();

      // Back to page 1 whenever the search/category changes.
      final pageKey = '$query|$_selectedCategory';
      if (pageKey != _pageKey) {
        _pageKey = pageKey;
        _page = 0;
      }
      final visible = pageSlice(filtered, _page, _pageSize);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;
            final searchField = TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 16),
                hintText: tr('Tafuta kwa jina, kitendo au maelezo...'),
              ),
            );
            final categoryDropdown = DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(isDense: true, labelText: tr('Aina (Category)')),
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
                  onPressed: (auditCtrl.auditLogs.isEmpty || _exporting) ? null : () => _export(auditCtrl),
                  icon: _exporting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined, size: 16),
                  label: Text(_exporting ? 'Inatayarisha faili...' : 'Pakua (CSV)', style: const TextStyle(fontSize: 11)),
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
          Text('Jumla: ${filtered.length} / ${auditCtrl.auditLogs.length} Rekodi'
              '${auditCtrl.auditLogs.length >= AuditController.screenLimit ? ' (za hivi karibuni; CSV inapakua zote)' : ''}',
              style: TextStyle(fontSize: 10, color: Pal.textMuted)),
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
                      style: TextStyle(color: Pal.textMuted),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final log = visible[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Pal.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Pal.border),
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
                              Text(log.timestamp, style: TextStyle(fontSize: 9.5, color: Pal.textMuted)),
                            ]),
                            const SizedBox(height: 4),
                            Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(log.details, style: TextStyle(fontSize: 10.5, color: Pal.textSecondary)),
                            const SizedBox(height: 2),
                            Row(children: [
                              Expanded(
                                child: Text('${log.userName} (${log.userRole})',
                                    style: TextStyle(fontSize: 10, color: Pal.textMuted)),
                              ),
                              if (log.ipAddress != null) ...[
                                Icon(Icons.language, size: 11, color: Pal.textMuted),
                                const SizedBox(width: 3),
                                Text(log.ipAddress!, style: TextStyle(fontSize: 9.5, color: Pal.textMuted)),
                                const SizedBox(width: 8),
                              ],
                              if (log.statusCode != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: log.isSuccess ? Pal.tint(Colors.green) : Pal.tint(Colors.red),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${log.statusCode}',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: log.isSuccess ? Pal.fg(Colors.green.shade700) : Pal.fg(Colors.red.shade700))),
                                ),
                            ]),
                          ],
                        ),
                      );
                    },
                  ),
                      ),
                      PaginationBar(
                        total: filtered.length,
                        page: _page,
                        pageSize: _pageSize,
                        onPageChanged: (p) => setState(() => _page = p),
                        onPageSizeChanged: (n) => setState(() {
                          _pageSize = n;
                          _page = 0;
                        }),
                      ),
                    ],
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
