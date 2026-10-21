import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/employee_controller.dart';
import '../core/theme.dart';
import '../core/tr_snack.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import '../models/employee.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import 'widgets/app_status_views.dart';
import 'widgets/form_kit.dart';

/// Rasilimali Watu (HR): leave, the people records (emergency contacts, dependents, education,
/// contracts) and the contracts that are about to end. No pay is shown anywhere on these pages.
class HrScreen extends StatelessWidget {
  const HrScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('RASILIMALI WATU (HR)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Pal.brandText)),
          const SizedBox(height: 4),
          Text('Likizo, rekodi za wafanyakazi na mikataba. Mishahara haionekani kwenye kurasa hizi.',
              style: TextStyle(fontSize: 11.5, color: Pal.textSecondary)),
          const SizedBox(height: 10),
          TabBar(
            isScrollable: true,
            labelColor: Pal.primary,
            unselectedLabelColor: Pal.textMuted,
            tabs: [
              Tab(icon: const Icon(Icons.beach_access_outlined, size: 18), text: tr('Likizo (Leave)')),
              Tab(icon: const Icon(Icons.badge_outlined, size: 18), text: tr('Rekodi za Mfanyakazi')),
              Tab(icon: const Icon(Icons.event_note_outlined, size: 18), text: tr('Mikataba Inayoisha')),
            ],
          ),
          const SizedBox(height: 10),
          const Expanded(
            child: TabBarView(
              children: [_LeaveTab(), _RecordsTab(), _ContractsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------
ApiService get _api => Get.find<ApiService>();

String _err(Object e) => e is ApiException ? e.message : '$e';

BoxDecoration _card() => BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border));

Widget _empty(IconData icon, String text) => Container(
      padding: const EdgeInsets.all(28),
      decoration: _card(),
      child: Column(children: [
        Icon(icon, size: 36, color: Pal.textMuted),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: Pal.textSecondary)),
      ]),
    );

String _shortDate(dynamic iso) {
  final s = '${iso ?? ''}';
  return s.length >= 10 ? s.substring(0, 10) : s;
}

Future<bool> _confirm(BuildContext context, String title, String message, {String yes = 'Ndiyo'}) async {
  return await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Ghairi')),
            ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text(yes)),
          ],
        ),
      ) ??
      false;
}

/// Type-ahead employee picker (people who are not blocked).
class _EmployeePicker extends StatelessWidget {
  const _EmployeePicker({super.key, required this.onSelected, this.errorText, this.autofocus = false});

  final ValueChanged<Employee?> onSelected;
  final String? errorText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final employees = Get.find<EmployeeController>().employees.where((e) => e.backendId != null && e.status != 'Blocked').toList();
    return Autocomplete<Employee>(
      displayStringForOption: (e) => '${e.fullName} (${e.id})',
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        return employees.where((e) => q.isEmpty || e.fullName.toLowerCase().contains(q) || e.id.toLowerCase().contains(q)).take(8);
      },
      onSelected: (e) => onSelected(e),
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        autofocus: autofocus,
        onChanged: (_) => onSelected(null),
        decoration: InputDecoration(
          labelText: tr('Mfanyakazi *'),
          hintText: tr('Andika jina au namba...'),
          prefixIcon: const Icon(Icons.person_search_outlined, size: 18),
          errorText: errorText == null ? null : tr(errorText!),
        ),
      ),
    );
  }
}

/// A dialog frame with a title, a scrolling body and the Cancel / Save buttons.
class _FormDialog extends StatelessWidget {
  const _FormDialog({required this.title, required this.icon, required this.child, required this.onSubmit, required this.submitLabel, this.busy = false});

  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback onSubmit;
  final String submitLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
              child: Row(children: [
                Icon(icon, color: Pal.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 6),
                child: child,
              ),
            ),
            FormActions(onCancel: () => Navigator.of(context).pop(false), onSubmit: onSubmit, busy: busy, submitLabel: submitLabel),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. LEAVE
// ---------------------------------------------------------------------------
class _LeaveTab extends StatefulWidget {
  const _LeaveTab();

  @override
  State<_LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<_LeaveTab> {
  String _status = 'ALL';
  int _year = DateTime.now().year;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _today = [];

  static const _statusNames = {
    'ALL': 'Zote',
    'PENDING': 'Zinasubiri',
    'APPROVED': 'Zimeidhinishwa',
    'REJECTED': 'Zimekataliwa',
    'CANCELLED': 'Zimefutwa',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.hrLeaveRequests(status: _status == 'ALL' ? null : _status, year: _year);
      final today = await _api.hrOnLeaveToday();
      if (!mounted) return;
      setState(() {
        _requests = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _today = today.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _err(e);
        _loading = false;
      });
    }
  }

  Future<void> _new() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _NewLeaveDialog());
    if (ok == true) {
      trSnack('Imefanikiwa', 'Ombi la likizo limeingizwa; linasubiri idhini.');
      _load();
    }
  }

  Future<void> _decide(Map<String, dynamic> r, bool approve) async {
    final note = TextEditingController();
    final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(approve ? 'Idhinisha Likizo' : 'Kataa Likizo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['employeeName']} - ${r['leaveType']}\n${_shortDate(r['startDate'])} hadi ${_shortDate(r['endDate'])} (siku ${_days(r['days'])})'),
                const SizedBox(height: 12),
                AppTextField(label: 'Maelezo (hiari)', controller: note, icon: Icons.notes_outlined),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Ghairi')),
              ElevatedButton(
                onPressed: () => Navigator.of(c).pop(true),
                style: approve ? null : ElevatedButton.styleFrom(backgroundColor: Pal.danger, foregroundColor: Colors.white),
                child: Text(approve ? 'Idhinisha' : 'Kataa'),
              ),
            ],
          ),
        ) ??
        false;
    final text = note.text.trim();
    note.dispose();
    if (!go) return;
    try {
      await _api.hrDecideLeave((r['id'] as num).toInt(), approve: approve, note: text.isEmpty ? null : text);
      trSnack('Imefanikiwa', approve ? 'Likizo imeidhinishwa.' : 'Likizo imekataliwa.');
      _load();
    } catch (e) {
      trSnack('Imeshindikana', _err(e));
    }
  }

  Future<void> _cancel(Map<String, dynamic> r) async {
    if (!await _confirm(context, 'Futa Likizo', 'Kufuta likizo ya ${r['employeeName']} (${_shortDate(r['startDate'])})? Siku zitarudi kwenye salio.', yes: 'Ndiyo, Futa')) return;
    try {
      await _api.hrCancelLeave((r['id'] as num).toInt());
      _load();
    } catch (e) {
      trSnack('Imeshindikana', _err(e));
    }
  }

  Future<void> _balance(Map<String, dynamic> r) async {
    await showDialog<void>(context: context, builder: (_) => _BalanceDialog(employeeId: (r['employee_id'] as num).toInt(), name: '${r['employeeName']}', year: _year));
  }

  static String _days(dynamic v) {
    final n = (v as num?) ?? 0;
    return n == n.roundToDouble() ? '${n.toInt()}' : '$n';
  }

  MaterialColor _color(String status) => switch (status) {
        'APPROVED' => Colors.green,
        'REJECTED' => Colors.red,
        'CANCELLED' => Colors.blueGrey,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = DateTime.now().year + 1; y >= DateTime.now().year - 3; y--) y];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: AppDropdown<String>(
                  label: 'Hali',
                  value: _status,
                  items: _statusNames.keys.toList(),
                  labelOf: (k) => tr(_statusNames[k]!),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _status = v);
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 130,
                child: AppDropdown<int>(
                  label: 'Mwaka',
                  value: _year,
                  items: years,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _year = v);
                    _load();
                  },
                ),
              ),
              ElevatedButton.icon(onPressed: _new, icon: const Icon(Icons.add, size: 18), label: const Text('Ombi la Likizo')),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(context: context, builder: (_) => const _LeaveTypesDialog()),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Aina za Likizo'),
              ),
              IconButton(tooltip: tr('Onyesha upya'), onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          if (_today.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Pal.tint(Colors.teal), borderRadius: BorderRadius.circular(12)),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Walio likizo leo:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Pal.fg(Colors.teal.shade800))),
                  for (final t in _today)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${t['employeeName']} (hadi ${_shortDate(t['endDate'])})', style: const TextStyle(fontSize: 10.5)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_loading && _requests.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: AppLoadingIndicator(message: 'Inapakua maombi ya likizo...'))
          else if (_error != null)
            AppErrorRetryView(message: _error!, onRetry: _load)
          else if (_requests.isEmpty)
            _empty(Icons.beach_access_outlined, 'Hakuna maombi ya likizo kwa uchaguzi huu.')
          else
            Container(
              decoration: _card(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _requests.length; i++) ...[
                    _row(_requests[i]),
                    if (i != _requests.length - 1) Divider(height: 1, color: Pal.border),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final status = '${r['status']}';
    final color = _color(status);
    final pending = status == 'PENDING';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 330,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _balance(r),
                  child: Text('${r['employeeName']}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Pal.primary)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r['leaveType']}${r['isPaid'] == false ? ' (bila malipo)' : ''}  |  ${_shortDate(r['startDate'])} - ${_shortDate(r['endDate'])}  |  siku ${_days(r['days'])}',
                  style: TextStyle(fontSize: 11, color: Pal.textSecondary),
                ),
                if ((r['reason'] ?? '').toString().isNotEmpty) Text('${r['reason']}', style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
                if ((r['decidedBy'] ?? '').toString().isNotEmpty)
                  Text('Na: ${r['decidedBy']}${(r['decisionNote'] ?? '').toString().isEmpty ? '' : ' - ${r['decisionNote']}'}',
                      style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Pal.tint(color), borderRadius: BorderRadius.circular(8)),
            child: Text(tr(_statusNames[status] ?? status), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Pal.fg(color.shade700))),
          ),
          if (pending) ...[
            TextButton.icon(onPressed: () => _decide(r, true), icon: const Icon(Icons.check_circle_outline, size: 18), label: const Text('Idhinisha')),
            TextButton.icon(
              onPressed: () => _decide(r, false),
              icon: Icon(Icons.cancel_outlined, size: 18, color: Pal.danger),
              label: Text('Kataa', style: TextStyle(color: Pal.danger)),
            ),
          ],
          if (pending || status == 'APPROVED')
            IconButton(tooltip: tr('Futa likizo'), icon: Icon(Icons.delete_outline, color: Pal.danger, size: 20), onPressed: () => _cancel(r)),
        ],
      ),
    );
  }
}

class _NewLeaveDialog extends StatefulWidget {
  const _NewLeaveDialog();

  @override
  State<_NewLeaveDialog> createState() => _NewLeaveDialogState();
}

class _NewLeaveDialogState extends State<_NewLeaveDialog> {
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _reason = TextEditingController();
  Employee? _employee;
  List<Map<String, dynamic>> _types = [];
  int? _typeId;
  bool _saving = false;
  final Map<String, String> _errors = {};
  String? _failure;

  @override
  void initState() {
    super.initState();
    _api.hrLeaveTypes().then((rows) {
      if (!mounted) return;
      setState(() {
        _types = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (_types.isNotEmpty) _typeId = (_types.first['id'] as num).toInt();
      });
    }).catchError((e) {
      if (mounted) setState(() => _failure = _err(e));
    });
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    if (_employee == null || _employee!.backendId == null) errors['employee'] = 'Chagua mfanyakazi kutoka kwenye orodha.';
    if (_typeId == null) errors['type'] = 'Chagua aina ya likizo.';
    if (_start.text.trim().isEmpty) errors['start'] = 'Chagua tarehe ya kuanza.';
    if (_end.text.trim().isEmpty) errors['end'] = 'Chagua tarehe ya kumaliza.';
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _failure = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await _api.hrRequestLeave({
        'employee_id': _employee!.backendId,
        'leave_type_id': _typeId,
        'startDate': _start.text.trim(),
        'endDate': _end.text.trim(),
        'reason': _reason.text.trim().isEmpty ? null : _reason.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = _err(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _FormDialog(
      title: 'Ombi Jipya la Likizo',
      icon: Icons.beach_access_outlined,
      submitLabel: 'Wasilisha',
      busy: _saving,
      onSubmit: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_failure != null) FormNotice(_failure!),
          _EmployeePicker(autofocus: true, errorText: _errors['employee'], onSelected: (e) => setState(() {
                _employee = e;
                _errors.remove('employee');
              })),
          const SizedBox(height: 14),
          AppDropdown<int>(
            label: 'Aina ya Likizo',
            value: _typeId,
            items: _types.map((t) => (t['id'] as num).toInt()).toList(),
            labelOf: (id) {
              final t = _types.firstWhere((x) => (x['id'] as num).toInt() == id, orElse: () => {'name': '$id', 'daysPerYear': 0});
              final days = (t['daysPerYear'] as num?) ?? 0;
              return days > 0 ? '${t['name']} (siku ${days.toInt()} kwa mwaka)' : '${t['name']}';
            },
            required: true,
            errorText: _errors['type'],
            onChanged: (v) => setState(() => _typeId = v),
          ),
          const SizedBox(height: 14),
          FormGrid(children: [
            AppDateField(
              label: 'Kuanzia',
              controller: _start,
              required: true,
              errorText: _errors['start'],
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 2, 12, 31),
              onPicked: () => setState(() => _errors.remove('start')),
            ),
            AppDateField(
              label: 'Hadi',
              controller: _end,
              required: true,
              errorText: _errors['end'],
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 2, 12, 31),
              onPicked: () => setState(() => _errors.remove('end')),
            ),
          ]),
          const SizedBox(height: 14),
          AppTextField(label: 'Sababu (hiari)', controller: _reason, icon: Icons.notes_outlined, textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 6),
          Text('Siku zinahesabiwa Jumatatu hadi Ijumaa; Jumamosi na Jumapili hazihesabiwi.', style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
        ],
      ),
    );
  }
}

class _BalanceDialog extends StatelessWidget {
  const _BalanceDialog({required this.employeeId, required this.name, required this.year});

  final int employeeId;
  final String name;
  final int year;

  static String _n(dynamic v) {
    if (v == null) return '-';
    final n = v as num;
    return n == n.roundToDouble() ? '${n.toInt()}' : '$n';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Salio la Likizo - $name ($year)'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<List<dynamic>>(
          future: _api.hrLeaveBalance(employeeId, year: year),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) return Text(_err(snap.error!));
            final rows = (snap.data ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 38,
                columns: [
                  DataColumn(label: Text('Aina')),
                  DataColumn(label: Text('Stahiki'), numeric: true),
                  DataColumn(label: Text('Zilizotumika'), numeric: true),
                  DataColumn(label: Text('Zinasubiri'), numeric: true),
                  DataColumn(label: Text('Zilizobaki'), numeric: true),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(Text('${r['leaveType']}')),
                      DataCell(Text((r['entitled'] as num) > 0 ? _n(r['entitled']) : tr('Hakuna kikomo'))),
                      DataCell(Text(_n(r['taken']))),
                      DataCell(Text(_n(r['pending']))),
                      DataCell(Text(r['remaining'] == null ? '-' : _n(r['remaining']), style: const TextStyle(fontWeight: FontWeight.w800))),
                    ]),
                ],
              ),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Funga'))],
    );
  }
}

class _LeaveTypesDialog extends StatefulWidget {
  const _LeaveTypesDialog();

  @override
  State<_LeaveTypesDialog> createState() => _LeaveTypesDialogState();
}

class _LeaveTypesDialogState extends State<_LeaveTypesDialog> {
  List<Map<String, dynamic>> _types = [];
  bool _loading = true;
  final _name = TextEditingController();
  final _days = TextEditingController(text: '0');
  bool _paid = true;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _api.hrLeaveTypes(all: true);
      if (!mounted) return;
      setState(() {
        _types = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _failure = _err(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _add() async {
    setState(() => _failure = null);
    try {
      await _api.hrSaveLeaveType({'name': _name.text.trim(), 'daysPerYear': double.tryParse(_days.text.trim().replaceAll(',', '.')) ?? 0, 'isPaid': _paid});
      _name.clear();
      _days.text = '0';
      await _load();
    } catch (e) {
      if (mounted) setState(() => _failure = _err(e));
    }
  }

  Future<void> _toggle(Map<String, dynamic> t) async {
    try {
      await _api.hrSaveLeaveType({'isBlocked': !(t['isBlocked'] == true)}, id: (t['id'] as num).toInt());
      await _load();
    } catch (e) {
      if (mounted) setState(() => _failure = _err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aina za Likizo'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_failure != null) FormNotice(_failure!),
              if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
              for (final t in _types)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${t['name']}', style: TextStyle(decoration: t['isBlocked'] == true ? TextDecoration.lineThrough : null)),
                  subtitle: Text(((t['daysPerYear'] as num?) ?? 0) > 0 ? 'Siku ${(t['daysPerYear'] as num).toInt()} kwa mwaka' : 'Hakuna kikomo cha siku',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t['isPaid'] == true ? 'Na malipo' : 'Bila malipo', style: const TextStyle(fontSize: 10.5)),
                    IconButton(
                      tooltip: tr(t['isBlocked'] == true ? 'Washa' : 'Zima'),
                      icon: Icon(t['isBlocked'] == true ? Icons.toggle_off : Icons.toggle_on, color: t['isBlocked'] == true ? Pal.textMuted : Pal.success),
                      onPressed: () => _toggle(t),
                    ),
                  ]),
                ),
              const Divider(),
              const FormSection('Aina Mpya', icon: Icons.add_circle_outline),
              AppTextField(label: 'Jina', controller: _name, icon: Icons.label_outline),
              const SizedBox(height: 10),
              AppTextField(
                label: 'Siku kwa mwaka (0 = hakuna kikomo)',
                controller: _days,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,1}'))],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Likizo ya malipo', style: TextStyle(fontSize: 12.5)),
                value: _paid,
                onChanged: (v) => setState(() => _paid = v),
              ),
              Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 18), label: const Text('Ongeza'))),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Funga'))],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. EMPLOYEE RECORDS
// ---------------------------------------------------------------------------
enum _FType { text, date, integer, boolean, choice }

class _F {
  const _F(this.key, this.label, this.type, {this.required = false, this.choices = const []});

  final String key;
  final String label;
  final _FType type;
  final bool required;
  final List<String> choices;
}

class _Section {
  const _Section(this.kind, this.title, this.icon, this.fields, this.summary);

  final String kind;
  final String title;
  final IconData icon;
  final List<_F> fields;
  final String Function(Map<String, dynamic>) summary;
}

String _s(Map<String, dynamic> r, String k) => (r[k] ?? '').toString();

final List<_Section> _sections = [
  _Section('emergency-contacts', 'Mawasiliano ya Dharura', Icons.contact_phone_outlined, const [
    _F('name', 'Jina', _FType.text, required: true),
    _F('relationship', 'Uhusiano', _FType.text),
    _F('phone', 'Simu', _FType.text, required: true),
    _F('address', 'Anwani', _FType.text),
  ], (r) => '${_s(r, 'name')} (${_s(r, 'relationship')})  -  ${_s(r, 'phone')}${_s(r, 'address').isEmpty ? '' : '  -  ${_s(r, 'address')}'}'),
  _Section('dependents', 'Wategemezi', Icons.family_restroom_outlined, const [
    _F('name', 'Jina', _FType.text, required: true),
    _F('relationship', 'Uhusiano', _FType.text),
    _F('dateOfBirth', 'Tarehe ya Kuzaliwa', _FType.date),
    _F('isBeneficiary', 'Mnufaika (Beneficiary)', _FType.boolean),
  ], (r) => '${_s(r, 'name')} (${_s(r, 'relationship')})${_s(r, 'dateOfBirth').isEmpty ? '' : '  -  ${_shortDate(r['dateOfBirth'])}'}${r['isBeneficiary'] == true ? '  -  Mnufaika' : ''}'),
  _Section('education', 'Elimu na Mafunzo', Icons.school_outlined, const [
    _F('institution', 'Taasisi', _FType.text, required: true),
    _F('qualification', 'Cheti / Shahada', _FType.text),
    _F('fieldOfStudy', 'Fani', _FType.text),
    _F('yearCompleted', 'Mwaka wa Kuhitimu', _FType.integer),
  ], (r) => '${_s(r, 'qualification')} - ${_s(r, 'institution')}${_s(r, 'fieldOfStudy').isEmpty ? '' : ' (${_s(r, 'fieldOfStudy')})'}${_s(r, 'yearCompleted').isEmpty ? '' : '  -  ${_s(r, 'yearCompleted')}'}'),
  _Section('contracts', 'Mikataba', Icons.description_outlined, const [
    _F('contractType', 'Aina ya Mkataba', _FType.choice, choices: ['PERMANENT', 'FIXED_TERM', 'PROBATION']),
    _F('position', 'Cheo', _FType.text),
    _F('startDate', 'Tarehe ya Kuanza', _FType.date, required: true),
    _F('endDate', 'Tarehe ya Kuisha (acha wazi kama haina mwisho)', _FType.date),
    _F('notes', 'Maelezo', _FType.text),
  ], (r) => '${_s(r, 'contractType')}${_s(r, 'position').isEmpty ? '' : ' - ${_s(r, 'position')}'}  |  ${_shortDate(r['startDate'])} hadi ${_s(r, 'endDate').isEmpty ? 'bila mwisho' : _shortDate(r['endDate'])}'),
];

class _RecordsTab extends StatefulWidget {
  const _RecordsTab();

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  Employee? _employee;
  final Map<String, List<Map<String, dynamic>>> _data = {};
  bool _loading = false;
  String? _error;
  int _pickerKey = 0;

  Future<void> _load() async {
    final id = _employee?.backendId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(_sections.map((s) => _api.hrRecords(s.kind, id)));
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _sections.length; i++) {
          _data[_sections[i].kind] = results[i].map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _err(e);
        _loading = false;
      });
    }
  }

  Future<void> _edit(_Section s, {Map<String, dynamic>? existing}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordDialog(section: s, employeeId: _employee!.backendId!, existing: existing),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(_Section s, Map<String, dynamic> r) async {
    if (!await _confirm(context, 'Futa Rekodi', 'Kufuta rekodi hii (${s.title})?', yes: 'Ndiyo, Futa')) return;
    try {
      await _api.hrDeleteRecord(s.kind, (r['id'] as num).toInt());
      _load();
    } catch (e) {
      trSnack('Imeshindikana', _err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 460,
            child: _EmployeePicker(
              key: ValueKey(_pickerKey),
              onSelected: (e) {
                if (e == null) return;
                setState(() {
                  _employee = e;
                  _data.clear();
                });
                _load();
              },
            ),
          ),
          const SizedBox(height: 14),
          if (_employee == null)
            _empty(Icons.badge_outlined, 'Chagua mfanyakazi kuona na kuhariri rekodi zake za HR.')
          else if (_loading && _data.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: AppLoadingIndicator(message: 'Inapakua rekodi...'))
          else if (_error != null)
            AppErrorRetryView(message: _error!, onRetry: _load)
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('${_employee!.fullName} (${_employee!.id})', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Pal.brandText)),
            ),
            for (final s in _sections) _sectionCard(s),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionCard(_Section s) {
    final rows = _data[s.kind] ?? const <Map<String, dynamic>>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(children: [
              Icon(s.icon, size: 18, color: Pal.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('${s.title} (${rows.length})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: () => _edit(s), icon: const Icon(Icons.add, size: 18), label: const Text('Ongeza')),
            ]),
          ),
          if (rows.isEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text('Hakuna rekodi bado.', style: TextStyle(fontSize: 11, color: Pal.textMuted)))
          else
            for (final r in rows) ...[
              Divider(height: 1, color: Pal.border),
              ListTile(
                dense: true,
                title: Text(s.summary(r), style: const TextStyle(fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: tr('Hariri'), icon: const Icon(Icons.edit_outlined, size: 19), onPressed: () => _edit(s, existing: r)),
                  IconButton(tooltip: tr('Futa'), icon: Icon(Icons.delete_outline, size: 19, color: Pal.danger), onPressed: () => _delete(s, r)),
                ]),
              ),
            ],
        ],
      ),
    );
  }
}

class _RecordDialog extends StatefulWidget {
  const _RecordDialog({required this.section, required this.employeeId, this.existing});

  final _Section section;
  final int employeeId;
  final Map<String, dynamic>? existing;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final Map<String, TextEditingController> _c = {};
  final Map<String, bool> _bool = {};
  final Map<String, String?> _choice = {};
  final Map<String, String> _errors = {};
  bool _saving = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    for (final f in widget.section.fields) {
      final v = e?[f.key];
      switch (f.type) {
        case _FType.boolean:
          _bool[f.key] = v == true;
        case _FType.choice:
          _choice[f.key] = (v ?? f.choices.first).toString();
        case _FType.date:
          _c[f.key] = TextEditingController(text: v == null ? '' : _shortDate(v));
        default:
          _c[f.key] = TextEditingController(text: v == null ? '' : '$v');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    final body = <String, dynamic>{};
    for (final f in widget.section.fields) {
      switch (f.type) {
        case _FType.boolean:
          body[f.key] = _bool[f.key] ?? false;
        case _FType.choice:
          body[f.key] = _choice[f.key];
        case _FType.integer:
          final t = _c[f.key]!.text.trim();
          if (t.isEmpty) {
            if (f.required) errors[f.key] = 'Sehemu hii inahitajika.';
            body[f.key] = null;
          } else if (int.tryParse(t) == null) {
            errors[f.key] = 'Weka namba nzima.';
          } else {
            body[f.key] = int.parse(t);
          }
        default:
          final t = _c[f.key]!.text.trim();
          if (t.isEmpty && f.required) errors[f.key] = 'Sehemu hii inahitajika.';
          body[f.key] = t.isEmpty ? null : t;
      }
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _failure = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await _api.hrAddRecord(widget.section.kind, widget.employeeId, body);
      } else {
        await _api.hrUpdateRecord(widget.section.kind, (widget.existing!['id'] as num).toInt(), body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = _err(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _FormDialog(
      title: '${widget.existing == null ? 'Ongeza' : 'Hariri'}: ${widget.section.title}',
      icon: widget.section.icon,
      submitLabel: 'Hifadhi',
      busy: _saving,
      onSubmit: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_failure != null) FormNotice(_failure!),
          for (final f in widget.section.fields) ...[
            switch (f.type) {
              _FType.boolean => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(f.label, style: const TextStyle(fontSize: 12.5)),
                  value: _bool[f.key] ?? false,
                  onChanged: (v) => setState(() => _bool[f.key] = v),
                ),
              _FType.choice => AppDropdown<String>(
                  label: f.label,
                  value: _choice[f.key],
                  items: f.choices,
                  onChanged: (v) => setState(() => _choice[f.key] = v),
                ),
              _FType.date => AppDateField(
                  label: f.label,
                  controller: _c[f.key]!,
                  required: f.required,
                  errorText: _errors[f.key],
                  firstDate: DateTime(1940),
                  lastDate: DateTime(now.year + 30, 12, 31),
                  onPicked: () => setState(() => _errors.remove(f.key)),
                ),
              _ => AppTextField(
                  label: f.label,
                  controller: _c[f.key]!,
                  required: f.required,
                  errorText: _errors[f.key],
                  keyboardType: f.type == _FType.integer ? TextInputType.number : null,
                  inputFormatters: f.type == _FType.integer ? [FilteringTextInputFormatter.digitsOnly] : null,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() => _errors.remove(f.key)),
                ),
            },
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. CONTRACTS ABOUT TO END
// ---------------------------------------------------------------------------
class _ContractsTab extends StatefulWidget {
  const _ContractsTab();

  @override
  State<_ContractsTab> createState() => _ContractsTabState();
}

class _ContractsTabState extends State<_ContractsTab> {
  int _days = 90;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.hrExpiringContracts(days: _days);
      if (!mounted) return;
      setState(() {
        _rows = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _err(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 220,
              child: AppDropdown<int>(
                label: 'Inayoisha ndani ya',
                value: _days,
                items: const [30, 60, 90, 180, 365],
                labelOf: (d) => 'Siku $d',
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _days = v);
                  _load();
                },
              ),
            ),
            IconButton(tooltip: tr('Onyesha upya'), onPressed: _load, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: AppLoadingIndicator(message: 'Inapakua mikataba...'))
          else if (_error != null)
            AppErrorRetryView(message: _error!, onRetry: _load)
          else if (_rows.isEmpty)
            _empty(Icons.event_available_outlined, 'Hakuna mkataba unaoisha ndani ya siku $_days.')
          else
            Container(
              decoration: _card(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _rows.length; i++) ...[
                    _row(_rows[i]),
                    if (i != _rows.length - 1) Divider(height: 1, color: Pal.border),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final left = (r['daysLeft'] as num).toInt();
    final color = left < 0 ? Colors.red : (left <= 30 ? Colors.orange : Colors.blue);
    return ListTile(
      leading: CircleAvatar(radius: 17, backgroundColor: Pal.tint(color), child: Icon(Icons.event_note_outlined, size: 17, color: Pal.fg(color.shade700))),
      title: Text('${r['name']} (${r['employeeIdNumber']})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      subtitle: Text('${r['contractType']}${(r['position'] ?? '').toString().isEmpty ? '' : ' - ${r['position']}'}  |  inaisha ${_shortDate(r['endDate'])}',
          style: TextStyle(fontSize: 11, color: Pal.textSecondary)),
      trailing: Text(left < 0 ? 'Imeisha siku ${-left} zilizopita' : 'Siku $left zimebaki',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Pal.fg(color.shade700))),
    );
  }
}
