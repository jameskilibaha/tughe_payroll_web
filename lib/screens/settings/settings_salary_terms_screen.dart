import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/salary_terms_controller.dart';
import '../../models/tra_salary_term.dart';
import '../widgets/responsive_header_bar.dart';
import '../widgets/app_status_views.dart';

const _brandBlue = Color(0xFF1E3A8A);

class SettingsSalaryTermsScreen extends StatefulWidget {
  const SettingsSalaryTermsScreen({super.key});

  @override
  State<SettingsSalaryTermsScreen> createState() => _SettingsSalaryTermsScreenState();
}

class _SettingsSalaryTermsScreenState extends State<SettingsSalaryTermsScreen> {
  late final SalaryTermsController _ctrl = Get.find<SalaryTermsController>();
  late List<Map<String, TextEditingController>> _controllers;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  void _syncControllers() {
    _controllers = _ctrl.traTerms
        .map((t) => {
              'min': TextEditingController(text: t.minSalary.toStringAsFixed(0)),
              'max': TextEditingController(text: t.maxSalary >= 999999999 ? '' : t.maxSalary.toStringAsFixed(0)),
              'percentage': TextEditingController(text: t.percentage.toStringAsFixed(0)),
              'addition': TextEditingController(text: t.additionAmount.toStringAsFixed(0)),
            })
        .toList();
  }

  void _save() {
    final updated = <TRASalaryTerm>[];
    for (var i = 0; i < _ctrl.traTerms.length; i++) {
      final term = _ctrl.traTerms[i];
      final c = _controllers[i];
      updated.add(term.copyWith(
        minSalary: double.tryParse(c['min']!.text) ?? term.minSalary,
        maxSalary: c['max']!.text.trim().isEmpty ? 999999999 : (double.tryParse(c['max']!.text) ?? term.maxSalary),
        percentage: double.tryParse(c['percentage']!.text) ?? term.percentage,
        additionAmount: double.tryParse(c['addition']!.text) ?? term.additionAmount,
      ));
    }
    _ctrl.saveTerms(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fomula ya TRA PAYE imehifadhiwa.')),
    );
  }

  void _reset() {
    _ctrl.resetToDefault();
    setState(_syncControllers);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_controllers.length != _ctrl.traTerms.length) _syncControllers();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveHeaderBar(
            title: const Text('TRA FORMULA SETTINGS (SALARY TERMS)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _brandBlue)),
            subtitle: const Text(
              'Simamia viwango vya kodi ya TRA PAYE (Term 1 hadi 5) yanayotumika '
              'kukokotoa kodi ya mshahara kwa wafanyakazi wote.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Rudisha Chaguo-msingi', style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton.icon(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Hifadhi Fomula', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _ctrl.isLoading.value
                ? const AppLoadingIndicator(message: 'Inapakua Vigezo vya Kodi (TRA)...')
                : (_ctrl.errorMessage.value.isNotEmpty && _ctrl.traTerms.isEmpty)
                    ? AppErrorRetryView(message: _ctrl.errorMessage.value, onRetry: _ctrl.refreshFromBackend)
                    : _ctrl.traTerms.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Hakuna Vigezo vya Kodi vilivyowekwa bado.',
                                    style: TextStyle(color: Colors.black45)),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _reset,
                                  icon: const Icon(Icons.restore, size: 16),
                                  label: const Text('Weka Chaguo-msingi la TRA', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _ctrl.traTerms.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final term = _ctrl.traTerms[i];
                              final c = _controllers[i];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Term ${term.termNumber}',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _brandBlue)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _numField('Kiwango cha Chini (Min)', c['min']!),
                                        _numField('Kiwango cha Juu (Max, tupu = Zaidi)', c['max']!),
                                        _numField('Asilimia (%)', c['percentage']!),
                                        _numField('Nyongeza ya Kodi (Addition)', c['addition']!),
                                      ],
                                    ),
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

  Widget _numField(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 10), isDense: true),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
