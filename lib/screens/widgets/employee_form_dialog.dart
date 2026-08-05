import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/employee_controller.dart';
import '../../models/employee.dart';

const _brandBlue = Color(0xFF1E3A8A);

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
  String _errorMsg = '';

  bool get _isEditing => widget.existing != null;

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
    _dobCtrl = TextEditingController(text: e?.dateOfBirth ?? '1992-05-15');
    _doeCtrl = TextEditingController(
        text: e?.dateOfEmployment ?? DateTime.now().toIso8601String().substring(0, 10));
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

  bool _isSaving = false;

  Future<void> _submit() async {
    setState(() => _errorMsg = '');
    if (_idCtrl.text.trim().isEmpty || _firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Tafadhali jaza Namba ya Wafanyakazi, Jina la Kwanza na Jina la Mwisho.');
      return;
    }

    setState(() => _isSaving = true);
    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        gender: _gender,
        maritalStatus: _maritalStatus,
        nationality: _nationalityCtrl.text.trim(),
        residentialDistrict: _districtCtrl.text.trim(),
        mobileNumber: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim(),
        dateOfEmployment: _doeCtrl.text.trim(),
      );
      await _ctrl.updateEmployee(updated);
    } else {
      final idTrimmed = _idCtrl.text.trim();
      if (_ctrl.employees.any((e) => e.id.toLowerCase() == idTrimmed.toLowerCase())) {
        setState(() {
          _errorMsg = 'Namba ya ID $idTrimmed ipo tayari. Tumia ID nyengine.';
          _isSaving = false;
        });
        return;
      }
      final newEmp = Employee(
        id: idTrimmed,
        employeeIdNumber: idTrimmed,
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        gender: _gender,
        maritalStatus: _maritalStatus,
        nationality: _nationalityCtrl.text.trim(),
        residentialDistrict: _districtCtrl.text.trim(),
        mobileNumber: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim(),
        dateOfEmployment: _doeCtrl.text.trim(),
        status: 'Active',
      );
      await _ctrl.addEmployee(newEmp);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_isEditing ? 'Hariri Taarifa za Mfanyakazi' : 'Sajili Mfanyakazi Mpya',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _brandBlue)),
                const SizedBox(height: 12),
                if (_errorMsg.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMsg, style: TextStyle(color: Colors.red.shade800, fontSize: 11)),
                  ),
                Row(children: [
                  Expanded(child: _field('Namba ya Mfanyakazi (ID)', _idCtrl, enabled: !_isEditing)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Tarehe ya Kuajiriwa', _doeCtrl)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('Jina la Kwanza', _firstNameCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Jina la Kati', _middleNameCtrl)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('Jina la Mwisho', _lastNameCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Tarehe ya Kuzaliwa', _dobCtrl)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _dropdown('Jinsia', _gender, const ['Male', 'Female'], (v) => setState(() => _gender = v!)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown('Hali ya Ndoa', _maritalStatus,
                        const ['Single', 'Married', 'Divorced', 'Widowed'], (v) => setState(() => _maritalStatus = v!)),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('Uraia (Nationality)', _nationalityCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Wilaya ya Makazi', _districtCtrl)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('Namba ya Simu', _mobileCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Barua Pepe', _emailCtrl)),
                ]),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Ghairi')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing ? 'Hifadhi Mabadiliko' : 'Sajili Mfanyakazi'),
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

  Widget _field(String label, TextEditingController ctrl, {bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11), isDense: true),
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11), isDense: true),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: onChanged,
    );
  }
}
