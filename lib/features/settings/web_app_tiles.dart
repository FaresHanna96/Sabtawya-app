import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/web_device_stub.dart'
    if (dart.library.js_interop) '../../core/services/web_device_web.dart';
import '../../core/services/web_pwa_stub.dart'
    if (dart.library.js_interop) '../../core/services/web_pwa_web.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../state/session_controller.dart';
import '../lock/app_lock.dart';

/// «أضف للشاشة الرئيسية»: the website, not yet opened from its own icon. Asks
/// the browser to install it, or explains the steps where only the person can.
class InstallTile extends StatelessWidget {
  const InstallTile({
    super.key,
    this.web = kIsWeb,
    this.ios,
    this.installed,
    this.available,
    this.install,
  });

  final bool web;
  final bool? ios;
  final bool? installed;
  final ValueListenable<bool>? available;
  final Future<bool> Function()? install;

  @override
  Widget build(BuildContext context) {
    if (!web || (installed ?? isInstalledWebApp)) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: available ?? installAvailable,
      builder: (context, canPrompt, _) => ListTile(
        leading: const Icon(Icons.add_to_home_screen_rounded,
            color: AppColors.navy),
        title: const Text(AppStrings.installRow),
        onTap: () async {
          if (canPrompt) {
            await (install ?? promptInstall)();
            return;
          }
          await showDialog<void>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: const Text(AppStrings.installRow),
              content: Text((ios ?? isIosBrowser)
                  ? AppStrings.installSteps
                  : AppStrings.installStepsOther),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialog).pop(),
                  child: const Text(AppStrings.close),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// «قفل التطبيق بالبصمة»: the website's screen lock, shown only where the
/// device has a fingerprint, Face ID or screen code the browser can ask for.
class AppLockTile extends StatefulWidget {
  const AppLockTile({
    super.key,
    this.web = kIsWeb,
    this.store = const AppLockStore(),
    this.supported = passkeySupported,
    this.create = createPasskey,
    this.check = checkPasskey,
  });

  final bool web;
  final AppLockStore store;
  final Future<bool> Function() supported;
  final Future<String?> Function(String name) create;
  final Future<bool> Function(String id) check;

  @override
  State<AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends State<AppLockTile> {
  bool _supported = false;
  bool _on = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.web) _read();
  }

  Future<void> _read() async {
    final supported = await widget.supported();
    final id = await widget.store.passkey();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _on = id != null;
    });
  }

  Future<void> _change(bool on) async {
    final session = context.read<SessionController>();
    setState(() => _busy = true);
    if (on) {
      final id = await widget.create(session.displayName);
      if (id != null) await widget.store.save(id);
    } else {
      // Only whoever can open the lock may remove it.
      final id = await widget.store.passkey();
      if (id == null || await widget.check(id)) await widget.store.clear();
    }
    final now = await widget.store.passkey() != null;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _on = now;
    });
    if (now != on) Ui.info(context, AppStrings.appLockNotChanged);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.web || !_supported) return const SizedBox.shrink();
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.navy),
      title: const Text(AppStrings.appLockRow),
      subtitle: const Text(AppStrings.appLockHelp),
      value: _on,
      onChanged: _busy ? null : _change,
    );
  }
}
