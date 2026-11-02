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
  });

  final Child child;
  final VoidCallback onTap;
  final String? className;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (child.code != null && child.code!.isNotEmpty) child.code!,
      if (className != null) className!,
      if (child.ageLabel != null) child.ageLabel!,
      if (child.mobile != null) child.mobile!,
      if (child.school != null) child.school!,
    ].join(' • ');

    final accentColor = child.isActive ? AppColors.navy : AppColors.muted;

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
                    ? AppGradients.navyHeader
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
