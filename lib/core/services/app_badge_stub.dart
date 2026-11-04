import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

/// Native builds: puts the unread count on the launcher icon where the phone
/// supports it (Samsung, Huawei, Sony and others show a number; stock Android
/// shows a dot from the delivered notification on its own).
void setAppBadge(int count) {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  try {
    AppBadgePlus.updateBadge(count < 0 ? 0 : count).catchError((_) {});
  } catch (_) {
    // A badge is a nicety; never let it break the app.
  }
}
