import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../state/session_controller.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!Ui.requireOnline(context)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      final session = context.read<SessionController>();
      final email = session.profile?.email ?? '';

      // Re-authenticate with current password to confirm identity.
      await session.signIn(
        email: email,
        password: _currentPasswordController.text,
      );

      if (!mounted) return;
      await session.updatePassword(_newPasswordController.text);

      if (!mounted) return;
      Ui.success(context, AppStrings.passwordChanged);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.changePassword)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FadeSlideIn(
                      child: Center(child: Pulse(child: AppLogo(size: 76))),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: AppStrings.currentPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscureCurrent
                              ? AppStrings.showPassword
                              : AppStrings.hidePassword,
                          icon: Icon(_obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? AppStrings.currentPasswordRequired
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: AppStrings.newPassword,
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          tooltip: _obscureNew
                              ? AppStrings.showPassword
                              : AppStrings.hidePassword,
                          icon: Icon(_obscureNew
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppStrings.newPasswordRequired;
                        }
                        if (v.length < 8) return AppStrings.passwordTooShort;
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: AppStrings.confirmNewPassword,
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirm
                              ? AppStrings.showPassword
                              : AppStrings.hidePassword,
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppStrings.confirmNewPasswordRequired;
                        }
                        if (v != _newPasswordController.text) {
                          return AppStrings.passwordsDoNotMatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
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
                          : const Text(AppStrings.save),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
