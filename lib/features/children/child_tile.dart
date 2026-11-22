import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/class_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/child.dart';
import 'child_avatar.dart';
import 'child_filters.dart';
import 'contact_cards.dart';

/// One child in a list. Shared by the children directory and class details so
/// both read identically.
class ChildTile extends StatelessWidget {
  const ChildTile({
    super.key,
    required this.child,
    required this.onTap,
    this.className,
    this.presentStreak = 0,
    this.onContact,
  });

  final Child child;
  final VoidCallback onTap;
  final String? className;

  /// Saturdays attended in a row; a flame shows from 3 up.
  final int presentStreak;

  /// Opens call / WhatsApp for the child and parents. When given and the
  /// child has a number, a phone button replaces the arrow.
  final VoidCallback? onContact;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (child.code != null && child.code!.isNotEmpty) child.code!,
      if (className != null) className!,
      if (child.ageLabel != null) child.ageLabel!,
      if (child.mobile != null) child.mobile!,
      if (child.school != null) child.school!,
    ].join(' • ');

    final card = Card(
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
                        // Gender first, then the class's own colour.
                        colors: [
                          child.gender == Gender.boy
                              ? AppColors.sky
                              : AppColors.coral,
                          classAccent(child.classId),
                        ],
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
                leading: ChildAvatar(child: child, heroTag: 'child-${child.id}'),
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
                trailing: !child.isActive
                    ? const StatusBadge(isActive: false)
                    : onContact != null &&
                            ContactPerson.forChild(child).isNotEmpty
                        ? IconButton.filledTonal(
                            tooltip: AppStrings.call,
                            onPressed: onContact,
                            icon: const Icon(Icons.call_rounded,
                                color: AppColors.success),
                          )
                        : const Icon(AppIcons.forward, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );

    // Swipe the row to call or message: the row springs back, the contact
    // sheet opens.
    if (onContact == null || !child.isActive) return card;
    return Dismissible(
      key: ValueKey('swipe-${child.id}'),
      confirmDismiss: (_) async {
        Haptics.select();
        onContact!();
        return false;
      },
      background: const _SwipeBackground(AlignmentDirectional.centerStart),
      secondaryBackground:
          const _SwipeBackground(AlignmentDirectional.centerEnd),
      child: card,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground(this.alignment);

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.successTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.call_rounded, color: AppColors.success),
    );
  }
}

