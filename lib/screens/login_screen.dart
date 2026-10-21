import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'widgets/force_password_dialog.dart';
import '../utils/quick_accounts_store.dart';
import 'widgets/tughe_logo.dart';
import '../network/api_exception.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import '../core/tr_snack.dart';

const _brandBlue = Color(0xFF1E3A8A);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Credentials are never pre-filled (they used to be hard-coded in the source).

  // final _emailCtrl = TextEditingController(text: "aaronsevere@tughe.or.tz");
  // final _passwordCtrl = TextEditingController(text: "SEVERE123456");
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  final _quickStore = QuickAccountsStore();
  List<QuickAccount> _quick = [];
  bool _saveQuick = false;
  bool _showPassword = false;
  bool _isLoading = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _quickStore.load().then((list) {
      if (mounted) setState(() => _quick = list);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
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
      final auth = Get.find<AuthController>();
      var savedPassword = password;
      if (await auth.login(username: username, password: password)) {
        // the password was set by somebody else: nothing else is allowed until the person has chosen his own
        if (!mounted) return;
        final chosen = await showDialog<String>(context: context, barrierDismissible: false, builder: (_) => ForcePasswordDialog(auth: auth));
        if (chosen == null) {
          await auth.cancelPasswordChange();
          setState(() => _errorMsg = 'Lazima ubadilishe nenosiri ili kuendelea.');
          return;
        }
        savedPassword = chosen;
      }
      if (_saveQuick) await _rememberQuickAccount(username, savedPassword);
    } on ApiException catch (error) {
      setState(() => _errorMsg = error.message);
    } catch (error) {
      setState(() => _errorMsg = 'Imeshindwa kuingia. Jaribu tena.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Tap on a saved account: with a saved password it signs in at once; otherwise it
  /// fills the username and puts the cursor in the password box.
  Future<void> _quickLogin(QuickAccount account) async {
    _emailCtrl.text = account.username;
    if (account.hasPassword) {
      _passwordCtrl.text = account.password!;
      await _submit();
    } else {
      _passwordCtrl.clear();
      _passwordFocus.requestFocus();
      setState(() => _errorMsg = '');
    }
  }

  Future<void> _rememberQuickAccount(String username, String password) async {
    final exists = _quick.any((a) => a.username.toLowerCase() == username.toLowerCase());
    if (exists) return;
    final updated = [..._quick, QuickAccount(label: username, username: username, password: password)];
    await _quickStore.save(updated);
    if (mounted) setState(() => _quick = updated);
  }

  Future<void> _deleteQuick(QuickAccount account) async {
    final updated = _quick.where((a) => a.username != account.username).toList();
    await _quickStore.save(updated);
    if (mounted) setState(() => _quick = updated);
  }

  Future<void> _addQuickAccount() async {
    final labelCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var savePassword = false;
    var show = false;
    String error = '';

    final created = await showDialog<QuickAccount>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Ongeza Akaunti ya Kuingia Haraka'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(labelText: tr('Jina la kuonyesha (hiari)'), isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: userCtrl,
                  decoration: InputDecoration(labelText: tr('Jina la Mtumiaji / Barua Pepe (Username)'), isDense: true),
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: savePassword,
                  onChanged: (v) => setLocal(() => savePassword = v ?? false),
                  title: const Text('Hifadhi nenosiri pia (ingia kwa kubofya mara moja)', style: TextStyle(fontSize: 11.5)),
                ),
                if (savePassword) ...[
                  TextField(
                    controller: passCtrl,
                    obscureText: !show,
                    decoration: InputDecoration(
                      labelText: tr('Nenosiri (Password)'),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setLocal(() => show = !show),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nenosiri litahifadhiwa kwenye kivinjari hiki tu, bila usimbaji fiche. Tumia kompyuta yako binafsi pekee.',
                    style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
                  ),
                ],
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error, style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Ghairi')),
            ElevatedButton(
              onPressed: () {
                final username = userCtrl.text.trim();
                if (username.isEmpty) {
                  setLocal(() => error = 'Weka Jina la Mtumiaji.');
                  return;
                }
                if (savePassword && passCtrl.text.isEmpty) {
                  setLocal(() => error = 'Weka nenosiri, au ondoa tiki ya "Hifadhi nenosiri".');
                  return;
                }
                Navigator.of(dialogContext).pop(QuickAccount(
                  label: labelCtrl.text.trim().isEmpty ? username : labelCtrl.text.trim(),
                  username: username,
                  password: savePassword ? passCtrl.text : null,
                ));
              },
              child: const Text('Hifadhi'),
            ),
          ],
        ),
      ),
    );
    labelCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    if (created == null) return;
    // the same username replaces the old entry
    final updated = [..._quick.where((a) => a.username.toLowerCase() != created.username.toLowerCase()), created];
    await _quickStore.save(updated);
    if (mounted) setState(() => _quick = updated);
  }

  Widget _quickSection(bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('INGIA KWA HARAKA (QUICK LOGIN)', isEnglish: isEn),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Pal.textMuted, letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        if (_quick.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              t('Hakuna akaunti zilizohifadhiwa. Ongeza ili uingie kwa kubofya mara moja.', isEnglish: isEn),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: Pal.textMuted),
            ),
          ),
        ..._quick.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: _isLoading ? null : () => _quickLogin(a),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                  decoration: BoxDecoration(
                    color: Pal.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Pal.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(8)),
                        child: Text(a.initials,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('@${a.username}', style: TextStyle(fontSize: 10, color: Pal.textSecondary)),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: a.hasPassword ? tr('Inaingia mara moja (nenosiri limehifadhiwa)') : tr('Inajaza jina tu - andika nenosiri'),
                        child: Icon(a.hasPassword ? Icons.bolt : Icons.person_outline, size: 17, color: Pal.textMuted),
                      ),
                      IconButton(
                        tooltip: tr('Ondoa akaunti hii'),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.close, size: 16, color: Pal.textMuted),
                        onPressed: () => _deleteQuick(a),
                      ),
                    ],
                  ),
                ),
              ),
            )),
        const SizedBox(height: 2),
        TextButton.icon(
          onPressed: _isLoading ? null : _addQuickAccount,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Ongeza Akaunti', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = context.watch<LocaleProvider>().isEnglish;
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      style: TextStyle(color: Pal.brandText, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: themeProvider.isDark ? 'Light Mode' : 'Dark Mode',
                  onPressed: () => themeProvider.toggle(),
                  icon: Icon(themeProvider.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 18, color: Pal.brandText),
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
                color: Pal.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Pal.border),
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
                        Text(
                          'Weka taarifa zako za kazi kuingia kwenye mfumo wa mshahara',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Pal.textSecondary),
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
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.mail_outline, size: 18),
                            hintText: tr('mfano: admin'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label('Nenosiri (Password)'),
                        TextField(
                          controller: _passwordCtrl,
                          focusNode: _passwordFocus,
                          obscureText: !_showPassword,
                          onSubmitted: (_) => _submit(),
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
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _saveQuick,
                          onChanged: (v) => setState(() => _saveQuick = v ?? false),
                          title: Text(t('Hifadhi akaunti hii kwa kuingia haraka', isEnglish: isEn), style: const TextStyle(fontSize: 11.5)),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => trSnack(
                              'Umesahau Nenosiri?',
                              'Wasiliana na Msimamizi Mkuu wa Mfumo TUGHE ili kubadilisha nenosiri.',
                            ),
                            child: Text(t('Umesahau Nenosiri?', isEnglish: isEn),
                                style: TextStyle(color: Pal.brandText, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 18, width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Pal.onPrimary))
                                : Text(t('INGIA MFUMONI (SIGN IN)', isEnglish: isEn),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),
                        _quickSection(isEn),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: Pal.surfaceAlt,
                    child: Text(
                      'TUGHE PAYROLL SYSTEM v2.5 • ALL RIGHTS RESERVED © 2026',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Pal.textMuted, letterSpacing: 0.6),
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
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Pal.textSecondary, letterSpacing: 0.4)),
      );

  Widget _buildBanner(bool isEn) {
    return Container(
      width: double.infinity,
      color: _brandBlue,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const TugheLogo(size: 72, radius: 16),
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
