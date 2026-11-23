import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/badges.dart';
import '../../data/models/child.dart';
import 'badge_look.dart';

/// One child and the badge they just won.
typedef BadgeWin = ({Child child, KidBadge badge});

/// The badges a save just won: the ones earned now and dated [day] (the
/// Saturday saved) that were not earned before the save. Comparing with
/// [before] keeps a re-saved old Saturday from announcing its badges again.
List<({String childId, KidBadge badge})> newlyWon({
  required Iterable<ChildBadge> before,
  required Iterable<ChildBadge> after,
  required DateTime day,
}) {
  final had = {
    for (final b in before)
      if (b.earned) '${b.childId}|${b.badge.id}',
  };
  return [
    for (final b in ChildBadge.wonOn(after, day))
      if (!had.contains('${b.childId}|${b.badge.id}'))
        (childId: b.childId, badge: b.badge),
  ];
}

/// «وسام جديد»: one child gets the big card, several a list. Each child with
/// a family number gets a WhatsApp congratulation button.
Future<void> showBadgesEarned(BuildContext context, List<BadgeWin> wins) {
  if (wins.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (_) => BadgeEarnedDialog(wins: wins),
  );
}

@visibleForTesting
class BadgeEarnedDialog extends StatelessWidget {
  const BadgeEarnedDialog({super.key, required this.wins});

  final List<BadgeWin> wins;

  static Future<void> _congratulate(BadgeWin win) async {
    final number = WhatsApp.numberFor(win.child);
    if (number == null) return;
    await launchUrl(
      WhatsApp.link(
        number,
        AppStrings.congratsMessage(
          win.child.fullName,
          win.badge.title,
          girl: win.child.gender == Gender.girl,
        ),
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: wins.length == 1 ? _One(win: wins.first) : _Many(wins: wins),
      ),
    );
  }
}

class _One extends StatelessWidget {
  const _One({required this.win});

  final BadgeWin win;

  @override
  Widget build(BuildContext context) {
    final girl = win.child.gender == Gender.girl;
    final canSend = WhatsApp.numberFor(win.child) != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Pulse(
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: win.badge.color, width: 3),
              ),
              child: BadgeMedal(badge: win.badge, earned: true, size: 92),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: statusTint(win.badge.color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AppStrings.newBadge,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.readable(win.badge.color),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${win.badge.title}!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.badgeWonBy(win.child.fullName, win.badge.title,
              girl: girl),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 15, color: AppColors.muted, height: 1.6),
        ),
        const SizedBox(height: 4),
        Text(
          win.badge.rule,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  AppStrings.badgeBonus(kBadgeBonus),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (canSend) ...[
          FilledButton.icon(
            onPressed: () => BadgeEarnedDialog._congratulate(win),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: const Color(0xFF0B3D20),
            ),
            icon: const Icon(Icons.chat_rounded),
            label: Text(AppStrings.congratsParents(girl: girl)),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text(AppStrings.badgeOk),
        ),
      ],
    );
  }
}

class _Many extends StatelessWidget {
  const _Many({required this.wins});

  final List<BadgeWin> wins;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.emoji_events_rounded, size: 44, color: AppColors.gold),
        const SizedBox(height: 8),
        Text(
          AppStrings.newBadgesCount(wins.length),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final w in wins)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      BadgeMedal(badge: w.badge, earned: true, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.child.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              w.badge.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.readable(w.badge.color),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (WhatsApp.numberFor(w.child) != null)
                        IconButton(
                          tooltip: AppStrings.sendCongratsTo(w.child.fullName),
                          onPressed: () => BadgeEarnedDialog._congratulate(w),
                          icon: const Icon(Icons.chat_rounded,
                              color: Color(0xFF1E8E4B)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text(AppStrings.badgeOk),
        ),
      ],
    );
  }
}
