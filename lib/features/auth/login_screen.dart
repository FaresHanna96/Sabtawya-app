import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../state/session_controller.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    try {
      await context.read<SessionController>().signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      // The auth listener in SessionController takes over from here and the
      // gate swaps this screen for the dashboard.
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Gradient header with logos
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppGradients.navyHeader,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
            child: Column(
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const AppLogo(size: 64),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const ChurchLogo(size: 64),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppStrings.churchName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  AppStrings.appTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Animated form area
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: FadeSlideIn(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: AppStrings.email,
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: AppStrings.password,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? AppStrings.showPassword
                                        : AppStrings.hidePassword,
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                        ? AppStrings.passwordRequired
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
                                    : const Text(AppStrings.login),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                ForgotPasswordScreen(
                                              initialEmail:
                                                  _emailController.text,
                                            ),
                                          ),
                                        ),
                                child: const Text(AppStrings.forgotPassword),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const SignUpScreen(),
                                          ),
                                        ),
                                child: const Text(AppStrings.noAccountYet),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return AppStrings.emailRequired;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return valid ? null : AppStrings.emailInvalid;
  }
}

/// Reused by the forgot-password screen and the teacher invite form.
String? validateEmailField(String? value) =>
    _LoginScreenState._validateEmail(value);
