import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/employee_controller.dart';
import '../../models/employee.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import 'form_kit.dart';
import 'modal_header_banner.dart';

const _blue900 = Color(0xFF1E3A8A);
const _indigo900 = Color(0xFF312E81);

/// Register a new employee / edit an existing one.
class EmployeeFormDialog extends StatefulWidget {
  const EmployeeFormDialog({super.key, this.existing});

  final Employee? existing;

  @override
  State<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<EmployeeFormDialog> {
  late final EmployeeController _ctrl = Get.find<EmployeeController>();

  late final TextEditingController _idCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _doeCtrl;
  late final TextEditingController _nationalityCtrl;

  String _gender = 'Male';
  String _maritalStatus = 'Single';

  /// Message shown on top of the form, and the message of each wrong field (by key).
  String _errorMsg = '';
  final Map<String, String> _errors = {};
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  static const _genders = ['Male', 'Female'];
  static const _maritalStatuses = ['Single', 'Married', 'Divorced', 'Widowed'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idCtrl = TextEditingController(text: e?.id ?? _ctrl.generateNextEmployeeId());
    _firstNameCtrl = TextEditingController(text: e?.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: e?.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: e?.lastName ?? '');
    _districtCtrl = TextEditingController(text: e?.residentialDistrict ?? '');
    _mobileCtrl = TextEditingController(text: e?.mobileNumber ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    // The date of birth decides the retirement date: it must be chosen, never silently defaulted.
    _dobCtrl = TextEditingController(text: e?.dateOfBirth ?? '');
    _doeCtrl = TextEditingController(text: e?.dateOfEmployment ?? DateTime.now().toIso8601String().substring(0, 10));
    _nationalityCtrl = TextEditingController(text: e?.nationality ?? 'Mtanzania');
    _gender = e?.gender ?? 'Male';
    _maritalStatus = e?.maritalStatus ?? 'Single';
  }

  @override
  void dispose() {
    for (final c in [
      _idCtrl, _firstNameCtrl, _middleNameCtrl, _lastNameCtrl, _districtCtrl,
      _mobileCtrl, _emailCtrl, _dobCtrl, _doeCtrl, _nationalityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clear(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  String _t(TextEditingController c) => c.text.trim();

  /// Checks every field; each wrong one shows its own message in red.
  bool _validate() {
    final e = <String, String>{};
    if (_t(_idCtrl).isEmpty) e['id'] = 'Weka namba ya mfanyakazi.';
    if (_t(_firstNameCtrl).isEmpty) e['first'] = 'Weka jina la kwanza.';
    if (_t(_lastNameCtrl).isEmpty) e['last'] = 'Weka jina la mwisho.';
    final email = _t(_emailCtrl);
    if (email.isEmpty) {
      e['email'] = 'Weka barua pepe (ndiyo jina la kuingia).';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      e['email'] = 'Barua pepe si sahihi (mfano: jina@mfano.com).';
    }
    if (_t(_mobileCtrl).isEmpty) e['mobile'] = 'Weka namba ya simu.';
    if (_t(_districtCtrl).isEmpty) e['district'] = 'Weka wilaya ya makazi.';
    if (_t(_nationalityCtrl).isEmpty) e['nationality'] = 'Weka uraia.';
    final dob = DateTime.tryParse(_t(_dobCtrl));
    if (dob == null) {
      e['dob'] = 'Chagua tarehe ya kuzaliwa.';
    } else if (dob.isAfter(DateTime.now())) {
      e['dob'] = 'Tarehe ya kuzaliwa haiwezi kuwa ya baadaye.';
    }
    if (DateTime.tryParse(_t(_doeCtrl)) == null) e['doe'] = 'Chagua tarehe ya kuajiriwa.';

    setState(() {
      _errors
        ..clear()
        ..addAll(e);
      _errorMsg = e.isEmpty ? '' : 'Rekebisha sehemu zilizoandikwa kwa rangi nyekundu, kisha jaribu tena.';
    });
    return e.isEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isSaving = true);
    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        firstName: _t(_firstNameCtrl),
        middleName: _t(_middleNameCtrl),
        lastName: _t(_lastNameCtrl),
        gender: _gender,
        maritalStatus: _maritalStatus,
        nationality: _t(_nationalityCtrl),
        residentialDistrict: _t(_districtCtrl),
        mobileNumber: _t(_mobileCtrl),
        email: _t(_emailCtrl),
        dateOfBirth: _t(_dobCtrl),
        dateOfEmployment: _t(_doeCtrl),
      );
      await _ctrl.updateEmployee(updated);
    } else {
      final idTrimmed = _t(_idCtrl);
      if (_ctrl.employees.any((e) => e.id.toLowerCase() == idTrimmed.toLowerCase())) {
        setState(() {
          _errors['id'] = 'Namba ya ID $idTrimmed ipo tayari. Tumia ID nyingine.';
          _errorMsg = 'Namba ya mfanyakazi imetumika tayari.';
          _isSaving = false;
        });
        return;
      }
      final newEmp = Employee(
        id: idTrimmed,
        employeeIdNumber: idTrimmed,
        firstName: _t(_firstNameCtrl),
        middleName: _t(_middleNameCtrl),
        lastName: _t(_lastNameCtrl),
        gender: _gender,
        maritalStatus: _maritalStatus,
        nationality: _t(_nationalityCtrl),
        residentialDistrict: _t(_districtCtrl),
        mobileNumber: _t(_mobileCtrl),
        email: _t(_emailCtrl),
        dateOfBirth: _t(_dobCtrl),
        dateOfEmployment: _t(_doeCtrl),
        status: 'Active',
      );
      await _ctrl.addEmployee(newEmp);
    }
    // a NEW employee: hand back his number so that the list can open the "complete the registration" steps
    if (mounted) Navigator.of(context).pop(_isEditing ? null : _t(_idCtrl)); 
  }

  String _genderLabel(String v) => v == 'Male' ? 'Mwanamume (Male)' : 'Mwanamke (Female)';

  String _maritalLabel(String v) => switch (v) {
        'Married' => 'Ameoa / Ameolewa (Married)',
        'Divorced' => 'Ametalikiana (Divorced)',
        'Widowed' => 'Mjane / Mgane (Widowed)',
        _ => 'Hajaoa / Hajaolewa (Single)',
      };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700, maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModalHeaderBanner(
              icon: _isEditing ? Icons.edit_outlined : Icons.person_add_alt_1,
              title: _isEditing ? 'Hariri Taarifa za Mfanyakazi' : 'Sajili Mfanyakazi Mpya',
              subtitle: 'Jaza taarifa za mfanyakazi. Sehemu zenye * ni lazima.',
              gradientColors: const [_blue900, _indigo900],
              iconColor: Colors.white,
              subtitleColor: Colors.blue.shade100,
              onClose: _isSaving ? null : () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMsg.isNotEmpty) FormNotice(_errorMsg),
                    const FormSection('Utambulisho', icon: Icons.badge_outlined),
                    FormGrid(children: [
                      AppTextField(
                        label: 'Namba ya Mfanyakazi (ID)',
                        controller: _idCtrl,
                        icon: Icons.tag,
                        required: true,
                        enabled: !_isEditing,
                        errorText: _errors['id'],
                        onChanged: (_) => _clear('id'),
                      ),
                      AppDateField(
                        label: 'Tarehe ya Kuajiriwa',
                        controller: _doeCtrl,
                        required: true,
                        errorText: _errors['doe'],
                        onPicked: () => _clear('doe'),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    FormGrid(columns: 3, children: [
                      AppTextField(
                        label: 'Jina la Kwanza',
                        controller: _firstNameCtrl,
                        required: true,
                        textCapitalization: TextCapitalization.words,
                        errorText: _errors['first'],
                        onChanged: (_) => _clear('first'),
                      ),
                      AppTextField(label: 'Jina la Kati', controller: _middleNameCtrl, textCapitalization: TextCapitalization.words),
                      AppTextField(
                        label: 'Jina la Mwisho',
                        controller: _lastNameCtrl,
                        required: true,
                        textCapitalization: TextCapitalization.words,
                        errorText: _errors['last'],
                        onChanged: (_) => _clear('last'),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    const FormSection('Taarifa binafsi', icon: Icons.person_outline),
                    FormGrid(children: [
                      AppDropdown<String>(
                        label: 'Jinsia',
                        value: _gender,
                        items: _genders,
                        labelOf: _genderLabel,
                        onChanged: (v) => setState(() => _gender = v ?? _gender),
                      ),
                      AppDropdown<String>(
                        label: 'Hali ya Ndoa',
                        value: _maritalStatus,
                        items: _maritalStatuses,
                        labelOf: _maritalLabel,
                        onChanged: (v) => setState(() => _maritalStatus = v ?? _maritalStatus),
                      ),
                      AppDateField(
                        label: 'Tarehe ya Kuzaliwa',
                        controller: _dobCtrl,
                        required: true,
                        errorText: _errors['dob'],
                        lastDate: DateTime.now(),
                        onPicked: () => _clear('dob'),
                      ),
                      AppTextField(
                        label: 'Uraia (Nationality)',
                        controller: _nationalityCtrl,
                        required: true,
                        errorText: _errors['nationality'],
                        onChanged: (_) => _clear('nationality'),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    const FormSection('Mawasiliano na makazi', icon: Icons.contact_phone_outlined),
                    FormGrid(children: [
                      AppTextField(
                        label: 'Namba ya Simu',
                        controller: _mobileCtrl,
                        icon: Icons.phone_outlined,
                        required: true,
                        keyboardType: TextInputType.phone,
                        errorText: _errors['mobile'],
                        onChanged: (_) => _clear('mobile'),
                      ),
                      AppTextField(
                        label: 'Barua Pepe',
                        controller: _emailCtrl,
                        icon: Icons.mail_outline,
                        required: true,
                        keyboardType: TextInputType.emailAddress,
                        helper: _isEditing ? null : 'Ndiyo jina lake la kuingia kwenye app.',
                        errorText: _errors['email'],
                        onChanged: (_) => _clear('email'),
                      ),
                      AppTextField(
                        label: 'Wilaya ya Makazi',
                        controller: _districtCtrl,
                        icon: Icons.location_on_outlined,
                        required: true,
                        textCapitalization: TextCapitalization.words,
                        errorText: _errors['district'],
                        onChanged: (_) => _clear('district'),
                      ),
                    ]),
                    if (!_isEditing) ...[
                      const SizedBox(height: 14),
                      const FormNotice(
                        'Akaunti ya kuingia inatengenezwa yenyewe: jina la mtumiaji ni barua pepe yake, na nenosiri la awali ni jina lake la mwisho kwa HERUFI KUBWA.',
                        kind: NoticeKind.info,
                      ),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            FormActions(
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
              busy: _isSaving,
              submitLabel: _isEditing ? 'Hifadhi Mabadiliko' : 'Sajili Mfanyakazi',
            ),
          ],
        ),
      ),
    );
  }
}
