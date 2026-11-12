import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/l10n/app_strings.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/ui.dart';
import 'core/widgets/app_widgets.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'state/session_controller.dart';

/// Arabic-only, right-to-left. The locale is pinned rather than following the
/// device so the interface never flips to an untranslated language.
const List<Locale> _supportedLocales = <Locale>[Locale('ar')];

final List<LocalizationsDelegate<dynamic>> _localizationDelegates =
    <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The widest the app is drawn. The screens are designed for a phone; on a
/// tablet or a desktop browser they sit in a centred column of this width
/// instead of stretching every card and bar from edge to edge.
const double kMaxAppWidth = 720;

/// `MaterialApp.builder` for both apps: right-to-left, and capped in width.
/// Dialogs, sheets and pushed screens live under it, so they are capped too.
Widget appFrame(BuildContext context, Widget? child) {
  final content = Directionality(
    textDirection: TextDirection.rtl,
    child: child ?? const SizedBox.shrink(),
  );
  final media = MediaQuery.of(context);
  if (media.size.width <= kMaxAppWidth) return content;
  return ColoredBox(
    color: AppColors.navyDark,
    child: Center(
      child: SizedBox(
        width: kMaxAppWidth,
        // Screens that measure the window must see the column, not the window.
        child: MediaQuery(
          data: media.copyWith(size: Size(kMaxAppWidth, media.size.height)),
          child: ClipRect(child: content),
        ),
      ),
    ),
  );
}

class SabtawyaApp extends StatelessWidget {
  const SabtawyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(),
        ),
        ChangeNotifierProvider<ConnectivityService>.value(
          value: ConnectivityService.instance,
        ),
        ChangeNotifierProvider<SyncService>(
          create: (context) {
            final session = context.read<SessionController>();
            SyncService.onSynced = session.markChanged;
            return SyncService();
          },
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: _supportedLocales,
        localizationsDelegates: _localizationDelegates,
        builder: appFrame,
        home: const AuthGate(),
      ),
    );
  }
}

/// Shown when the build was made without Supabase credentials.
class SabtawyaSetupApp extends StatelessWidget {
  const SabtawyaSetupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: _supportedLocales,
      localizationsDelegates: _localizationDelegates,
      builder: appFrame,
      home: const Scaffold(
        body: EmptyState(
          icon: Icons.settings_suggest_outlined,
          title: AppStrings.setupMissingTitle,
          body: AppStrings.setupMissingBody,
        ),
      ),
    );
  }
}

/// Routes to the login screen, the dashboard, or an "awaiting activation"
/// message based on the session state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  SessionStatus? _previous;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    // Screens pushed on top of the gate (settings, a class, a form) would stay
    // visible after the session ends and show data of the previous user.
    final leftSession = session.status == SessionStatus.signedOut &&
        _previous != null &&
        _previous != SessionStatus.signedOut;
    _previous = session.status;
    if (leftSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }

    switch (session.status) {
      case SessionStatus.loading:
        return const _SplashScreen();
      case SessionStatus.signedOut:
        return const LoginScreen();
      case SessionStatus.passwordRecovery:
        return const _PasswordRecoveryScreen();
      case SessionStatus.ready:
        return const HomeShell();
      case SessionStatus.notFound:
        return const _NotFoundScreen();
      case SessionStatus.rejected:
        return const _RejectedScreen();
      case SessionStatus.inactive:
        return const _InactiveAccountScreen();
      case SessionStatus.error:
        return _SessionErrorScreen(message: session.errorMessage);
    }
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.loginBackground),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const AppLogo(size: 100),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            AppStrings.churchName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            AppStrings.appTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.appSubtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRecoveryScreen extends StatefulWidget {
  const _PasswordRecoveryScreen();

  @override
  State<_PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<_PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context
          .read<SessionController>()
          .updatePassword(_passwordController.text);
      if (!mounted) return;
      Ui.success(context, AppStrings.passwordChanged);
      // Sign out so the user logs in fresh with the new password.
      await context.read<SessionController>().signOut();
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.setNewPassword)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: AppStrings.newPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? AppStrings.showPassword
                              : AppStrings.hidePassword,
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppStrings.passwordRequired;
                        }
                        if (v.length < 8) return AppStrings.passwordTooShort;
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
                        labelText: AppStrings.confirmNewPassword,
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v != _passwordController.text
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
                          : const Text(AppStrings.setNewPassword),
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

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.person_search_outlined,
          title: AppStrings.accountNotFoundTitle,
          body: AppStrings.accountNotFoundBody,
          action: OutlinedButton.icon(
            onPressed: session.signOut,
            icon: const Icon(Icons.logout),
            label: const Text(AppStrings.logoutAndRetry),
          ),
        ),
      ),
    );
  }
}

class _RejectedScreen extends StatelessWidget {
  const _RejectedScreen();

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.block_outlined,
          title: AppStrings.accountRejectedTitle,
          body: AppStrings.accountRejectedBody,
          action: OutlinedButton.icon(
            onPressed: session.signOut,
            icon: const Icon(Icons.logout),
            label: const Text(AppStrings.logoutAndRetry),
          ),
        ),
      ),
    );
  }
}

class _InactiveAccountScreen extends StatelessWidget {
  const _InactiveAccountScreen();

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.hourglass_empty,
          title: AppStrings.accountInactiveTitle,
          body: AppStrings.accountInactiveBody,
          action: OutlinedButton.icon(
            onPressed: session.signOut,
            icon: const Icon(Icons.logout),
            label: const Text(AppStrings.logoutAndRetry),
          ),
        ),
      ),
    );
  }
}

class _SessionErrorScreen extends StatelessWidget {
  const _SessionErrorScreen({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ErrorView(
                message: message ?? AppStrings.somethingWentWrong,
                onRetry: session.load,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextButton.icon(
                onPressed: session.signOut,
                icon: const Icon(Icons.logout),
                label: const Text(AppStrings.logout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Version string shown on the settings screen.
const String appVersionLabel = '${AppConfig.appName} 1.0.1';
