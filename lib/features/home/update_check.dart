import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_version.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/page_reload_stub.dart'
    if (dart.library.js_interop) '../../core/services/page_reload_web.dart';
import '../../core/services/update_service.dart';
import '../../core/utils/ui.dart';

/// «التحقق من التحديثات» in المزيد: checks now and always answers.
///
/// - Up to date, or the check failed: says so.
/// - A newer build on a phone: [onFound] hands it to the shell, whose banner
///   (or forced screen) installs it, even after the banner was closed.
/// - A newer build on the website: offers to reload the page into it.
Future<void> checkForUpdatesNow(
  BuildContext context, {
  required ValueChanged<AppUpdate> onFound,
  Future<UpdateCheck> Function()? check,
  Future<void> Function()? reload,
  bool web = kIsWeb,
}) async {
  Ui.info(context, AppStrings.checkingForUpdates);
  final result = await (check ?? UpdateService.checkNow)();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  switch (result.status) {
    case UpdateStatus.upToDate:
      Ui.success(context, AppStrings.upToDate(kAppVersion));
    case UpdateStatus.failed:
      Ui.info(context, AppStrings.updateCheckFailed);
    case UpdateStatus.available:
      final update = result.update!;
      if (!web) return onFound(update);
      final yes = await Ui.confirm(
        context,
        title: AppStrings.updateAvailable(update.version),
        message: AppStrings.updateReloadBody,
        confirmLabel: AppStrings.updateReload,
      );
      if (yes) await (reload ?? reloadPage)();
  }
}
