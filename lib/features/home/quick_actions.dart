import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import 'more_entries.dart';

/// The bottom bar's tabs, as far as their shortcuts care.
enum HomeTab { home, classes, children, attendance, activities, more }

/// One line of a tab's shortcut sheet.
class QuickAction {
  const QuickAction({
    required this.id,
    required this.icon,
    required this.title,
    required this.color,
    this.open,
  });

  static const searchId = 'search';
  static const notificationsId = 'notifications';
  static const addChildId = 'addChild';

  final String id;
  final IconData icon;
  final String title;
  final Color color;

  /// The page it leads to; null for the ones the home shell runs itself
  /// (search, notifications, adding a child).
  final Widget Function()? open;
}

const _search = QuickAction(
  id: QuickAction.searchId,
  icon: Icons.search_rounded,
  title: AppStrings.search,
  color: AppColors.navy,
);

const _notifications = QuickAction(
  id: QuickAction.notificationsId,
  icon: Icons.notifications_rounded,
  title: AppStrings.notificationsTitle,
  color: AppColors.maroon,
);

const _addChild = QuickAction(
  id: QuickAction.addChildId,
  icon: Icons.person_add_alt_1_rounded,
  title: AppStrings.addChild,
  color: AppColors.olive,
);

/// The shortcuts of [tab] for [role]. Pages come from المزيد's catalogue, so
/// nobody is offered one they do not have there.
List<QuickAction> quickActionsFor(HomeTab tab, MoreRole role) {
  final mine = {for (final e in MoreCatalog.entriesFor(role)) e.id: e};
  List<QuickAction> pages(List<String> ids) => [
        for (final id in ids)
          if (mine[id]?.open != null)
            QuickAction(
              id: id,
              icon: mine[id]!.icon,
              title: mine[id]!.title,
              color: mine[id]!.color,
              open: mine[id]!.open,
            ),
      ];
  return switch (tab) {
    HomeTab.home => const [_search, _notifications],
    HomeTab.classes => [_search, ...pages(['committed'])],
    HomeTab.children => [
        _search,
        // The general servant reads the children but does not add them.
        if (role != MoreRole.generalServant) _addChild,
        ...pages(['birthdays', 'missingInfo']),
      ],
    HomeTab.attendance => pages(['attendanceHistory', 'absence']),
    HomeTab.activities => pages(['preps']),
    HomeTab.more => pages(['settings']),
  };
}

/// The sheet a long press on a tab opens. Returns the chosen action.
Future<QuickAction?> showQuickActions(
  BuildContext context, {
  required String title,
  required List<QuickAction> actions,
}) {
  Haptics.select();
  return showModalBottomSheet<QuickAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
            for (final action in actions)
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    action.icon,
                    size: 22,
                    color: AppColors.readable(action.color),
                  ),
                ),
                title: Text(
                  action.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(action),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Remembers that this phone has been told about the long press.
class QuickActionsHint {
  const QuickActionsHint();

  static const _boxName = 'whats_new';
  static const _key = 'quick_actions_hint';

  /// True the first time only; false too when it cannot be remembered, so it
  /// is never shown on every start.
  Future<bool> take() async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      if (box.get(_key) == true) return false;
      await box.put(_key, true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
