import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/session_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    try {
      await context.read<SessionController>().sendPasswordReset(
            _emailController.text,
          );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.resetPassword)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _sent ? _buildSent() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.mark_email_read_outlined,
            size: 64, color: AppColors.success),
        const SizedBox(height: 16),
        const Text(
          AppStrings.resetLinkSent,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _emailController.text.trim(),
          textDirection: TextDirection.ltr,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.backToLogin),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Center(child: AppLogo(size: 100)),
          const SizedBox(height: 24),
          const Text(
            AppStrings.resetPasswordHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: AppStrings.email,
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return AppStrings.emailRequired;
              final valid =
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
              return valid ? null : AppStrings.emailInvalid;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text(AppStrings.sendResetLink),
          ),
        ],
      ),
    );
  }
}
