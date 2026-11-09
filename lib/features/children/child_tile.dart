import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/child.dart';
import 'child_avatar.dart';
import 'child_filters.dart';

/// One child in a list. Shared by the children directory and class details so
/// both read identically.
class ChildTile extends StatelessWidget {
  const ChildTile({
    super.key,
    required this.child,
    required this.onTap,
    this.className,
    this.presentStreak = 0,
  });

  final Child child;
  final VoidCallback onTap;
  final String? className;

  /// Saturdays attended in a row; a flame shows from 3 up.
  final int presentStreak;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (child.code != null && child.code!.isNotEmpty) child.code!,
      if (className != null) className!,
      if (child.ageLabel != null) child.ageLabel!,
      if (child.mobile != null) child.mobile!,
      if (child.school != null) child.school!,
    ].join(' • ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: child.isActive
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: child.gender == Gender.boy
                            ? const [AppColors.sky, AppColors.navyLight]
                            : const [AppColors.coral, AppColors.gold],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.muted, AppColors.muted],
                      ),
              ),
            ),
            Expanded(
              child: ListTile(
                onTap: onTap,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: ChildAvatar(child: child),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        child.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    if (presentStreak >= 3) ...[
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 16, color: AppColors.coral),
                          Text(
                            '$presentStreak',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.coral,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 6),
                    GenderBadge(gender: child.gender, compact: true),
                  ],
                ),
                subtitle: subtitle.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ),
                trailing: child.isActive
                    ? const Icon(Icons.chevron_left, color: AppColors.muted)
                    : const StatusBadge(isActive: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
