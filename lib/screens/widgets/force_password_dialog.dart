import 'package:flutter/material.dart' hide Text;

import '../../controllers/auth_controller.dart';
import '../../core/tr_text.dart';
import '../../network/api_exception.dart';
import 'form_kit.dart';

/// Shown right after signing in with a password that somebody else chose (the initial one, or one an Admin
/// reset): the person has to choose his own before anything else. Pops the new password when it is saved.
class ForcePasswordDialog extends StatefulWidget {
  const ForcePasswordDialog({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ForcePasswordDialog> createState() => _ForcePasswordDialogState();
}

class _ForcePasswordDialogState extends State<ForcePasswordDialog> {
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _saving = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _new.text;
    if (password.length < 8) {
      setState(() => _error = 'Nenosiri jipya liwe na angalau herufi/namba 8.');
      return;
    }
    if (password != _repeat.text) {
      setState(() => _error = 'Nenosiri jipya na uthibitisho havina usawa.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.auth.completePasswordChange(password);
      if (mounted) Navigator.of(context).pop(password);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Imeshindwa kubadilisha nenosiri. Jaribu tena.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.lock_reset, size: 30),
      title: const Text('Chagua Nenosiri Jipya'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormNotice(
                'Nenosiri ulilotumia liliwekwa na mtu mwingine. Kwa usalama wako, chagua nenosiri lako mwenyewe kabla ya kuendelea.',
                kind: NoticeKind.info,
              ),
              if (_error != null) FormNotice(_error!),
              AppTextField(
                label: 'Nenosiri Jipya',
                controller: _new,
                obscure: !_show,
                required: true,
                icon: Icons.lock_outline,
                autofocus: true,
                helper: 'Angalau herufi/namba 8; lisiwe jina lako la mwisho wala jina la mtumiaji.',
                suffix: IconButton(icon: Icon(_show ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: () => setState(() => _show = !_show)),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Rudia Nenosiri Jipya',
                controller: _repeat,
                obscure: !_show,
                required: true,
                icon: Icons.lock_outline,
                onSubmitted: (_) => _save(),
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(null), child: const Text('Ghairi')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Hifadhi na Endelea'),
        ),
      ],
    );
  }
}
