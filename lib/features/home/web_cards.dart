import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/push_service.dart';
import '../../core/services/web_device_stub.dart'
    if (dart.library.js_interop) '../../core/services/web_device_web.dart';
import '../../core/services/web_pwa_stub.dart'
    if (dart.library.js_interop) '../../core/services/web_pwa_web.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';

/// Remembers that the "add to the home screen" card was closed on this phone.
/// It comes back after [hideFor]: without the app installed an iPhone gets no
/// notifications at all.
class InstallCardStore {
  const InstallCardStore();

  static const _boxName = 'whats_new';
  static const _key = 'install_card_closed';

  static const hideFor = Duration(days: 14);

  /// True (do not show) when it cannot be read.
  Future<bool> closed() async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      return stillClosed(box.get(_key), DateTime.now());
    } catch (_) {
      return true;
    }
  }

  /// [stored] is when it was closed. An older version only kept `true`, with no
  /// time, so that one is shown again.
  static bool stillClosed(Object? stored, DateTime now) {
    final at = stored is String ? DateTime.tryParse(stored) : null;
    return at != null && now.difference(at) < hideFor;
  }

  Future<void> close() async {
    try {
      await (await Hive.openBox<dynamic>(_boxName))
          .put(_key, DateTime.now().toIso8601String());
    } catch (_) {}
  }
}

/// The website's nudges, above the tabs: on an iPhone in a Safari tab, how to
/// add the app to the home screen; where the browser can install it, a button
/// that does; otherwise, a button that turns notifications on (a browser only
/// lets a tap ask).
class WebCards extends StatefulWidget {
  const WebCards({
    super.key,
    this.web = kIsWeb,
    this.ios,
    this.installed,
    this.store = const InstallCardStore(),
    this.permission,
    this.enable,
    this.canInstall,
    this.install,
  });

  final bool web;

  /// Replace the browser's answers; tests give their own.
  final bool? ios;
  final bool? installed;
  final InstallCardStore store;
  final ValueListenable<PushPermission>? permission;
  final Future<void> Function()? enable;
  final ValueListenable<bool>? canInstall;
  final Future<bool> Function()? install;

  @override
  State<WebCards> createState() => _WebCardsState();
}

class _WebCardsState extends State<WebCards> {
  bool _installClosed = true;

  /// "Not now" on the notifications card, until the app is opened again.
  bool _notNow = false;
  bool _asking = false;

  /// An iPhone showing the site in a tab: it gets no notifications there.
  bool get _inSafari =>
      (widget.ios ?? isIosBrowser) &&
      !(widget.installed ?? isInstalledWebApp);

  @override
  void initState() {
    super.initState();
    if (widget.web && !(widget.installed ?? isInstalledWebApp)) {
      widget.store.closed().then((closed) {
        if (mounted) setState(() => _installClosed = closed);
      });
    }
  }

  Future<void> _enable() async {
    setState(() => _asking = true);
    await (widget.enable ?? PushService.instance.enableFromTap)();
    if (!mounted) return;
    setState(() => _asking = false);
    final now =
        (widget.permission ?? PushService.instance.permission).value;
    if (now == PushPermission.granted) {
      Ui.success(context, AppStrings.notificationsOn);
    } else if (now == PushPermission.denied) {
      Ui.info(context, AppStrings.notificationsDenied);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.web) return const SizedBox.shrink();
    if (_inSafari) {
      if (_installClosed) return const SizedBox.shrink();
      return _NudgeCard(
        icon: Icons.add_to_home_screen_rounded,
        title: AppStrings.installTitle,
        body: AppStrings.installSteps,
        onClose: () {
          setState(() => _installClosed = true);
          widget.store.close();
        },
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: widget.canInstall ?? installAvailable,
      builder: (context, canInstall, _) {
        if (canInstall && !_installClosed) {
          return _NudgeCard(
            icon: Icons.add_to_home_screen_rounded,
            title: AppStrings.installRow,
            body: AppStrings.installBody,
            action: AppStrings.installAction,
            onAction: () => (widget.install ?? promptInstall)(),
            onClose: () {
              setState(() => _installClosed = true);
              widget.store.close();
            },
          );
        }
        return _notificationsCard();
      },
    );
  }

  Widget _notificationsCard() {
    return ValueListenableBuilder<PushPermission>(
      valueListenable: widget.permission ?? PushService.instance.permission,
      builder: (context, permission, _) {
        if (permission != PushPermission.notAsked || _notNow) {
          return const SizedBox.shrink();
        }
        return _NudgeCard(
          icon: Icons.notifications_active_rounded,
          title: AppStrings.enableNotifications,
          body: AppStrings.enableNotificationsBody,
          action: AppStrings.enableNotifications,
          onAction: _asking ? null : _enable,
          onClose: () => setState(() => _notNow = true),
        );
      },
    );
  }
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onClose,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onClose;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Material(
        color: AppColors.goldTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.navy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.close,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(body,
                        style: const TextStyle(fontSize: 12.5, height: 1.7)),
                    if (action != null) ...[
                      const SizedBox(height: 8),
                      FilledButton(onPressed: onAction, child: Text(action!)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
