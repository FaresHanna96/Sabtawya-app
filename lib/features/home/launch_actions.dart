import 'package:flutter/material.dart';

import 'more_entries.dart';
import 'quick_actions.dart';

/// What an icon shortcut (manifest.json, `?go=`) leads to.
sealed class LaunchTarget {
  const LaunchTarget();
}

/// One of the bottom bar's tabs.
class LaunchTab extends LaunchTarget {
  const LaunchTab(this.tab);
  final HomeTab tab;
}

/// A page from المزيد.
class LaunchPage extends LaunchTarget {
  const LaunchPage(this.open);
  final Widget Function() open;
}

/// Where the shortcut [go] leads for [role]; null for an unknown one, or a page
/// this role does not have.
LaunchTarget? launchTarget(String? go, MoreRole role) {
  if (go == 'attendance') return const LaunchTab(HomeTab.attendance);
  if (go != 'absence' && go != 'birthdays') return null;
  for (final e in MoreCatalog.entriesFor(role)) {
    final open = e.open;
    if (e.id == go && open != null) return LaunchPage(open);
  }
  return null;
}
