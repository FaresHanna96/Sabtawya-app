import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../data/models/child.dart';
import '../../data/models/profile.dart';
import '../../state/session_controller.dart';
import 'login_screen.dart';

/// What a person signs up as. خادم and خادمة are the same role with a different
/// gender (only the wording differs); خادم عام is its own role.
enum _SignUpType {
  servant(AppRole.servant, Gender.boy),
  servantFemale(AppRole.servant, Gender.girl),
  general(AppRole.generalServant, null);

  const _SignUpType(this.role, this.gender);

  final AppRole role;
  final Gender? gender;
}

/// Open sign-up for a servant. The database creates an inactive profile with
/// the requested role (never admin), and أمين الخدمة accepts or rejects it.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _SignUpType _type = _SignUpType.servant;
  DateTime? _birthDate;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    try {
      final signedIn = await context.read<SessionController>().signUp(
            email: _emailController.text,
            password: _passwordController.text,
            fullName: _nameController.text,
            role: _type.role,
            gender: _type.gender,
            mobile: _mobileController.text,
            birthDate: _birthDate,
          );
      if (!mounted) return;
      if (signedIn) {
        Ui.success(context, AppStrings.signUpSuccess);
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(AppStrings.confirmEmailTitle),
          content: const Text(AppStrings.confirmEmailBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.backToLogin),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.signUp)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FadeSlideIn(
                      child: Center(child: Pulse(child: AppLogo(size: 84))),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      AppStrings.signUpHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: AppStrings.fullName,
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return AppStrings.fullNameRequired;
                        if (!RegExp(r'^[؀-ۿ\s]+$').hasMatch(v)) {
                          return AppStrings.nameArabicOnly;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: AppStrings.role,
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      child: SegmentedButton<_SignUpType>(
                        segments: const [
                          ButtonSegment<_SignUpType>(
                            value: _SignUpType.servant,
                            label: Text(AppStrings.roleServant),
                          ),
                          ButtonSegment<_SignUpType>(
                            value: _SignUpType.servantFemale,
                            label: Text(AppStrings.roleServantFemale),
                          ),
                          ButtonSegment<_SignUpType>(
                            value: _SignUpType.general,
                            label: Text(AppStrings.roleGeneralServant),
                          ),
                        ],
                        selected: <_SignUpType>{_type},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) =>
                            setState(() => _type = selection.first),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: AppStrings.email,
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: validateEmailField,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: AppStrings.mobile,
                        helperText: AppStrings.optional,
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _BirthDateField(
                      value: _birthDate,
                      onChanged: (d) => setState(() => _birthDate = d),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: AppStrings.password,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppStrings.passwordRequired;
                        }
                        if (value.length < 8) return AppStrings.passwordTooShort;
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: AppStrings.confirmPassword,
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? AppStrings.passwordsDoNotMatch
                          : null,
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
                          : const Text(AppStrings.signUp),
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

class _BirthDateField extends StatelessWidget {
  const _BirthDateField({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: AppStrings.pickBirthDate,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: AppStrings.birthDate,
          helperText: AppStrings.optional,
          prefixIcon: const Icon(Icons.cake_outlined),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined, size: 20)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          value == null
              ? AppStrings.pickBirthDate
              : AppDateUtils.formatDate(value!),
          style: TextStyle(
            fontSize: 15,
            color: value == null ? AppColors.muted : null,
          ),
        ),
      ),
    );
  }
}
