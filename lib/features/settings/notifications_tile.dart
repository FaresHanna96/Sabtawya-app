import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/push_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';

/// The website's notifications row in الإعدادات: on, off (tap to turn on) or
/// refused (how to allow them). Hidden in the phone app, which asks by itself.
class NotificationsTile extends StatelessWidget {
  const NotificationsTile({
    super.key,
    this.web = kIsWeb,
    this.permission,
    this.enable,
  });

  final bool web;
  final ValueListenable<PushPermission>? permission;
  final Future<void> Function()? enable;

  @override
  Widget build(BuildContext context) {
    if (!web) return const SizedBox.shrink();
    final listen = permission ?? PushService.instance.permission;
    return ValueListenableBuilder<PushPermission>(
      valueListenable: listen,
      builder: (context, state, _) {
        // A browser with no notifications at all has nothing to offer.
        if (state == PushPermission.unknown) return const SizedBox.shrink();
        return ListTile(
          leading: Icon(
            state == PushPermission.granted
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            color: AppColors.maroon,
          ),
          title: const Text(
            AppStrings.notificationsTitle,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            switch (state) {
              PushPermission.granted => AppStrings.notificationsOn,
              PushPermission.denied => AppStrings.notificationsDenied,
              _ => AppStrings.enableNotificationsBody,
            },
            style: const TextStyle(fontSize: 12),
          ),
          onTap: state != PushPermission.notAsked
              ? null
              : () async {
                  await (enable ?? PushService.instance.enableFromTap)();
                  if (context.mounted &&
                      listen.value == PushPermission.denied) {
                    Ui.info(context, AppStrings.notificationsDenied);
                  }
                },
        );
      },
    );
  }
}
