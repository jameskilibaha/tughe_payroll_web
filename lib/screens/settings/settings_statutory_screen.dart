import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/statutory_controller.dart';
import '../../core/theme.dart';
import '../../core/tr_snack.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../utils/formatters.dart';
import '../widgets/app_status_views.dart';
import '../widgets/form_kit.dart';

/// "Mipangilio ya Kisheria": the rates the payroll and the statutory reports use (NSSF / PSSSF, SDL,
/// WCF, HESLB) and how part-month pay is worked out. The rates start with the program's standard
/// values and are marked UNCONFIRMED until somebody has checked them against TRA / NSSF / PSSSF / WCF
/// and pressed "Thibitisha Viwango"; any change asks for a new confirmation.
class SettingsStatutoryScreen extends StatefulWidget {
  const SettingsStatutoryScreen({super.key});

  @override
  State<SettingsStatutoryScreen> createState() => _SettingsStatutoryScreenState();
}

class _SettingsStatutoryScreenState extends State<SettingsStatutoryScreen> {
  final _ctrl = Get.find<StatutoryController>();

  static const _numberKeys = [
    'nssfEmployeePct', 'nssfEmployerPct', 'psssfEmployeePct', 'psssfEmployerPct', 'sdlPct', 'wcfPct', 'heslbPct', 'sdlMinEmployees',
  ];
  final Map<String, TextEditingController> _fields = {for (final k in _numberKeys) k: TextEditingController()};

  bool _pensionReducesPaye = true;
  bool _sdlEnabled = true;
  bool _wcfEnabled = true;
  bool _requireApproval = false;
  String _pensionBase = 'BASIC';
  String _heslbBase = 'BASIC';
  String _prorationBasis = 'NONE';

  bool _dirty = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl.loadSettings().then((_) => _fill());
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Shows the values the server has.
  void _fill() {
    final s = _ctrl.settings.value;
    if (s == null || !mounted) return;
    String text(Object? v) => v == null ? '' : plainAmount(v as num);
    setState(() {
      for (final k in _numberKeys) {
        _fields[k]!.text = text(s[k]);
      }
      _pensionReducesPaye = s['pensionReducesPaye'] == true;
      _sdlEnabled = s['sdlEnabled'] == true;
      _wcfEnabled = s['wcfEnabled'] == true;
      _requireApproval = s['requireApproval'] == true;
      _pensionBase = (s['pensionBase'] as String?) ?? 'BASIC';
      _heslbBase = (s['heslbBase'] as String?) ?? 'BASIC';
      _prorationBasis = (s['prorationBasis'] as String?) ?? 'NONE';
      _dirty = false;
      _error = null;
    });
  }

  void _touch() => setState(() => _dirty = true);

  Future<void> _save() async {
    final body = <String, dynamic>{};
    for (final k in _numberKeys) {
      final raw = _fields[k]!.text.trim().replaceAll(',', '.');
      final value = double.tryParse(raw);
      if (value == null) {
        setState(() => _error = 'Weka namba sahihi kwenye kila sehemu ya viwango.');
        return;
      }
      if (k != 'sdlMinEmployees' && (value < 0 || value > 100)) {
        setState(() => _error = 'Asilimia lazima iwe kati ya 0 na 100.');
        return;
      }
      body[k] = k == 'sdlMinEmployees' ? value.round() : value;
    }
    body.addAll({
      'pensionReducesPaye': _pensionReducesPaye,
      'sdlEnabled': _sdlEnabled,
      'wcfEnabled': _wcfEnabled,
      'requireApproval': _requireApproval,
      'pensionBase': _pensionBase,
      'heslbBase': _heslbBase,
      'prorationBasis': _prorationBasis,
    });
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await _ctrl.saveSettings(body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      setState(() => _error = failure);
      return;
    }
    _fill();
    trSnack('Imehifadhiwa', 'Viwango vimehifadhiwa. Vithibitishe ili ripoti zijue vimekaguliwa.');
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final failure = await _ctrl.confirmSettings();
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      setState(() => _error = failure);
    } else {
      trSnack('Imethibitishwa', 'Viwango vimethibitishwa.');
    }
  }

  Widget _pct(String label, String key, {String? helper, bool whole = false}) => AppTextField(
        label: label,
        controller: _fields[key]!,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(whole ? r'^\d*' : r'^\d*[.,]?\d{0,3}'))],
        helper: helper,
        suffix: whole ? null : const Padding(padding: EdgeInsets.only(right: 14), child: Align(widthFactor: 1, child: Text('%'))),
        onChanged: (_) => _touch(),
      );

  Widget _card(String title, IconData icon, List<Widget> children, {String? hint}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSection(title, icon: icon, hint: hint),
            ...children,
          ],
        ),
      );

  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
        value: value,
        onChanged: (v) {
          onChanged(v);
          _touch();
        },
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_ctrl.loadingSettings.value && _ctrl.settings.value == null) {
        return const AppLoadingIndicator(message: 'Inapakua viwango vya kisheria...');
      }
      if (_ctrl.settings.value == null) {
        return AppErrorRetryView(
            message: _ctrl.settingsError.value ?? 'Imeshindwa kupakua viwango.', onRetry: () => _ctrl.loadSettings().then((_) => _fill()));
      }
      final verified = _ctrl.ratesConfirmed;
      final by = _ctrl.settings.value?['verifiedBy'] as String?;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MIPANGILIO YA KISHERIA (STATUTORY SETTINGS)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Pal.brandText)),
            const SizedBox(height: 4),
            Text('Viwango vya NSSF/PSSSF, SDL, WCF na HESLB vinavyotumika kwenye payroll na ripoti za kisheria. Viwango vya kodi ya PAYE viko kwenye "TRA Formula Settings".',
                style: TextStyle(fontSize: 11.5, height: 1.35, color: Pal.textSecondary)),
            const SizedBox(height: 14),
            if (!verified)
              const FormNotice(
                'Viwango hivi bado HAVIJATHIBITISHWA. Ni thamani za kuanzia za programu. Vilinganishe na tovuti/ofisi rasmi za TRA, NSSF/PSSSF na WCF, vibadilishe kama inavyohitajika, kisha bonyeza "Thibitisha Viwango".',
                kind: NoticeKind.info,
              )
            else
              FormNotice('Viwango vimethibitishwa${by == null || by.isEmpty ? '' : ' na $by'}.', kind: NoticeKind.success),
            if (_error != null) FormNotice(_error!),
            _card('Pensheni: NSSF na PSSSF', Icons.savings_outlined, [
              FormGrid(children: [
                _pct('NSSF - mchango wa mfanyakazi', 'nssfEmployeePct', helper: 'Mfanyakazi mwenye kato la "NSSF" lake mwenyewe anabaki na kiwango chake.'),
                _pct('NSSF - mchango wa mwajiri', 'nssfEmployerPct'),
                _pct('PSSSF - mchango wa mfanyakazi', 'psssfEmployeePct'),
                _pct('PSSSF - mchango wa mwajiri', 'psssfEmployerPct'),
              ]),
              const SizedBox(height: 14),
              AppDropdown<String>(
                label: 'Pensheni inahesabiwa kwa',
                value: _pensionBase,
                items: const ['BASIC', 'GROSS'],
                labelOf: (v) => v == 'BASIC' ? 'Mshahara wa msingi (Basic)' : 'Mshahara ghafi (msingi + posho + malipo ya ziada)',
                onChanged: (v) {
                  setState(() => _pensionBase = v ?? _pensionBase);
                  _touch();
                },
              ),
              _switch('Pensheni ya mfanyakazi inapunguzwa kabla ya PAYE', 'Imewashwa: PAYE inahesabiwa baada ya kutoa pensheni.', _pensionReducesPaye,
                  (v) => setState(() => _pensionReducesPaye = v)),
              Text('Mfuko wa kila mfanyakazi (NSSF au PSSSF) unawekwa kwenye "Hali ya Mshahara" ya mfanyakazi.', style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
            ]),
            _card('SDL - Skills and Development Levy (mwajiri)', Icons.school_outlined, [
              _switch('SDL inatozwa', 'Inahesabiwa kwa mshahara ghafi wa wote kila mwezi.', _sdlEnabled, (v) => setState(() => _sdlEnabled = v)),
              FormGrid(children: [
                _pct('Kiwango cha SDL', 'sdlPct'),
                _pct('Idadi ya chini ya wafanyakazi', 'sdlMinEmployees', whole: true, helper: 'SDL inatozwa tu ikiwa wafanyakazi ni wengi kuliko au sawa na idadi hii.'),
              ]),
            ]),
            _card('WCF - Workers Compensation Fund (mwajiri)', Icons.health_and_safety_outlined, [
              _switch('WCF inatozwa', 'Inahesabiwa kwa mshahara ghafi kila mwezi.', _wcfEnabled, (v) => setState(() => _wcfEnabled = v)),
              FormGrid(children: [_pct('Kiwango cha WCF', 'wcfPct')]),
            ]),
            _card('HESLB - mkopo wa elimu ya juu', Icons.account_balance_outlined, [
              FormGrid(children: [
                _pct('Kiwango cha kato', 'heslbPct', helper: 'Kinakatwa kwa mfanyakazi aliyewekwa "ana mkopo wa HESLB".'),
                AppDropdown<String>(
                  label: 'Kinahesabiwa kwa',
                  value: _heslbBase,
                  items: const ['BASIC', 'GROSS'],
                  labelOf: (v) => v == 'BASIC' ? 'Mshahara wa msingi (Basic)' : 'Mshahara ghafi',
                  onChanged: (v) {
                    setState(() => _heslbBase = v ?? _heslbBase);
                    _touch();
                  },
                ),
              ]),
            ]),
            _card('Malipo ya sehemu ya mwezi', Icons.calendar_month_outlined, [
              AppDropdown<String>(
                label: 'Mfanyakazi aliyejiunga au kuondoka katikati ya mwezi analipwa',
                value: _prorationBasis,
                items: const ['NONE', 'CALENDAR', 'THIRTY'],
                labelOf: (v) => switch (v) {
                  'CALENDAR' => 'Kwa siku alizofanya kazi (siku halisi za mwezi)',
                  'THIRTY' => 'Kwa siku alizofanya kazi (mwezi wa siku 30)',
                  _ => 'Mshahara kamili daima (hakuna kukata kwa siku)',
                },
                onChanged: (v) {
                  setState(() => _prorationBasis = v ?? _prorationBasis);
                  _touch();
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Tarehe ya kujiunga inachukuliwa kutoka kwa mfanyakazi, na tarehe ya kuondoka kwenye "Hali ya Mshahara". Mtu ambaye hajajiunga bado au ameshaondoka hapati slip ya mwezi huo. Siku za likizo bila malipo zinahesabiwa kwa msingi huohuo.',
                style: TextStyle(fontSize: 10.5, height: 1.35, color: Pal.textMuted),
              ),
            ]),
            _card('Kufunga Mwezi na Idhini', Icons.how_to_reg_outlined, [
              _switch(
                'Idhini ya wawili kabla ya kufunga mwezi',
                'Aliyewasilisha payroll ya mwezi hawezi kuufunga mwenyewe: Admin mwingine anaidhinisha. Kisha hati zinaweza kutumwa kwa barua pepe.',
                _requireApproval,
                (v) => setState(() => _requireApproval = v),
              ),
            ]),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: (_saving || _dirty || verified) ? null : _confirm,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Thibitisha Viwango'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: (_saving || !_dirty) ? null : _save,
                  icon: _saving
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Pal.onPrimary))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Hifadhi Mabadiliko'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    });
  }
}
