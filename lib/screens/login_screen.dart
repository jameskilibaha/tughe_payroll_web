import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../network/api_exception.dart';

const _brandBlue = Color(0xFF1E3A8A);

final List<User> _demoUsers = [
  const User(
    id: 'USR-DEMO-1',
    name: 'Msimamizi wa Mfumo',
    email: '',
    role: 'Msimamizi',
    designation: 'Mkurugenzi wa Mfumo',
    avatarInitials: 'MS',
    status: 'Active',
    username: 'admin',
  ),
  const User(
    id: 'USR-DEMO-2',
    name: 'Mhasibu Mkuu',
    email: '',
    role: 'Mhasibu Mkuu',
    designation: 'Mhasibu Mkuu wa Mshahara',
    avatarInitials: 'MH',
    status: 'Active',
    username: 'mhasibu',
  ),
  const User(
    id: 'USR-DEMO-3',
    name: 'Afisa Utumishi',
    email: '',
    role: 'Afisa Utumishi',
    designation: 'Afisa Rasilimali Watu',
    avatarInitials: 'AU',
    status: 'Active',
    username: 'utumishi',
  ),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController(text: "aaronsevere@tughe.or.tz");
  final _passwordCtrl = TextEditingController(text: "SEVERE");
  String _selectedRole = 'Msimamizi';
  bool _showPassword = false;
  bool _isLoading = false;
  String _errorMsg = '';

  final _roles = const {
    'Msimamizi': 'Msimamizi wa Mfumo (Admin)',
    'Mhasibu Mkuu': 'Mhasibu Mkuu (Chief Accountant)',
    'Afisa Utumishi': 'Afisa Utumishi (HR Officer)',
  };

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMsg = '');
    final username = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty) {
      setState(() => _errorMsg = 'Tafadhali weka Jina la Mtumiaji (Username).');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMsg = 'Tafadhali ingiza Nenosiri (Password).');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Get.find<AuthController>().login(username: username, password: password);
    } on ApiException catch (error) {
      setState(() => _errorMsg = error.message);
    } catch (error) {
      setState(() => _errorMsg = 'Imeshindwa kuingia. Jaribu tena.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Only prefills the username field with a sample account - it does not
  /// fabricate a session, since only the real backend can authenticate.
  void _quickLogin(User demoUser) {
    setState(() {
      _emailCtrl.text = demoUser.username ?? '';
      _selectedRole = demoUser.role;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEn = context.watch<LocaleProvider>().isEnglish;
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  tooltip: isEn ? 'Language: English (tap for Kiswahili)' : 'Lugha: Kiswahili (bonyeza kwa English)',
                  onPressed: () => context.read<LocaleProvider>().toggle(),
                  icon: Text(isEn ? 'EN' : 'SW',
                      style: const TextStyle(color: _brandBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: themeProvider.isDark ? 'Light Mode' : 'Dark Mode',
                  onPressed: () => themeProvider.toggle(),
                  icon: Icon(themeProvider.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 18, color: _brandBlue),
                ),
              ],
            ),
          ),
          Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBanner(isEn),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ingia Kwenye Akaunti Yako (Sign In)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Weka taarifa zako za kazi kuingia kwenye mfumo wa mshahara',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        if (_errorMsg.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_errorMsg,
                                      style: const TextStyle(
                                          color: Color(0xFF991B1B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        _label('Barua Pepe (Email / Username)'),
                        TextField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.mail_outline, size: 18),
                            hintText: 'mfano: admin',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label('Nenosiri (Password)'),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label('Wadhifa / Cheo Mfumoni (Role)'),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          items: _roles.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedRole = v ?? _selectedRole),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Get.snackbar(
                              'Umesahau Nenosiri?',
                              'Wasiliana na Msimamizi Mkuu wa Mfumo TUGHE ili kubadilisha nenosiri.',
                            ),
                            child: Text(t('Umesahau Nenosiri?', isEnglish: isEn),
                                style: const TextStyle(color: _brandBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18, width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(t('INGIA MFUMONI (SIGN IN)', isEnglish: isEn),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          t('AU INGIA HARAKA KWA AKAUNTI ZA JARIBIO (QUICK DEMO)', isEnglish: isEn),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 8),
                        ..._demoUsers.map((u) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: _isLoading ? null : () => _quickLogin(u),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28, height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(8)),
                                        child: Text(u.avatarInitials,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            Text('${u.role} (@${u.username})',
                                                style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.black38),
                                    ],
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: const Color(0xFFF8FAFC),
                    child: const Text(
                      'TUGHE PAYROLL SYSTEM v2.5 • ALL RIGHTS RESERVED © 2026',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 0.4)),
      );

  Widget _buildBanner(bool isEn) {
    return Container(
      width: double.infinity,
      color: _brandBlue,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 48, height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Text('T', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: _brandBlue)),
          ),
          const SizedBox(height: 12),
          Text(t('MFUMO WA TUGHE PAYROLL', isEnglish: isEn),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(t('Chama cha Wafanyakazi wa Serikali na Afya Tanzania', isEnglish: isEn),
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, size: 14, color: Color(0xFF34D399)),
                const SizedBox(width: 6),
                Text(t('PORTAL YA UHAKIKI NA INGIA (AUTHENTICATION)', isEnglish: isEn),
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
