import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../children/follow_up_call.dart';
import 'notification_router.dart';

/// The bell's list: newest first, unread in bold. Tapping an entry marks it
/// read and opens the screen it is about.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _repository = NotificationRepository();
  final _sectionKey = GlobalKey<AsyncSectionState<List<AppNotification>>>();

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      try {
        await _repository.markRead(n.id);
      } catch (_) {}
    }
    if (!mounted) return;
    await openNotification(context, n);
    if (mounted) await _reload();
  }

  /// The notification's own button: write the follow-up down without opening
  /// the child first.
  Future<void> _logCall(AppNotification n) async {
    final saved = await logFollowUp(
      context,
      childId: n.childId!,
      childName: n.body.split(' غاب ').first,
    );
    if (!saved || !mounted) return;
    if (!n.isRead) {
      try {
        await _repository.markRead(n.id);
      } catch (_) {}
    }
    await _reload();
  }

  /// The exact moment, then how long ago, so an old entry is not just
  /// "3 days ago".
  static String _when(AppNotification n) =>
      '${AppDateUtils.formatDateTime(n.createdAt)} · '
      '${AppDateUtils.sinceLabel(n.createdAt)}';

  Future<void> _markAll() async {
    try {
      await _repository.markAllRead();
    } catch (_) {}
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notificationsTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.markAllRead,
            icon: const Icon(Icons.done_all_rounded),
            onPressed: _markAll,
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncSection<List<AppNotification>>(
          loading: const SkeletonList(),
          key: _sectionKey,
          load: _repository.latest,
          builder: (context, items, reload) {
            if (items.isEmpty) {
              return const EmptyState(
                title: AppStrings.noNotifications,
                icon: Icons.notifications_none_rounded,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final n = items[i];
                final (icon, color) = notificationLook(n.kind);
                final card = Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: n.isRead ? null : color.withValues(alpha: 0.07),
                      child: ListTile(
                        onTap: () => _open(n),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: color.withValues(alpha: 0.16),
                          child: Icon(
                            icon,
                            color: AppColors.readable(color),
                            size: 24,
                          ),
                        ),
                        title: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                n.isRead ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                        subtitle: n.kind == 'announcement'
                            // A long announcement: its start here, the
                            // whole text when tapped.
                            ? Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                    text: n.body.length > 160
                                        ? '${n.body.substring(0, 160)}…'
                                        : n.body,
                                  ),
                                  TextSpan(
                                    text: '\n${_when(n)}',
                                  ),
                                ]),
                                style: const TextStyle(fontSize: 12),
                              )
                            : Text(
                                '${n.body}\n${_when(n)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                        isThreeLine: true,
                        trailing: n.kind == 'absence_child' && n.childId != null
                            ? TextButton.icon(
                                onPressed: () => _logCall(n),
                                icon: const Icon(Icons.call_rounded, size: 18),
                                label: const Text(AppStrings.logCall),
                              )
                            : n.isRead
                                ? null
                                : Icon(Icons.circle, size: 10, color: color),
                      ),
                    );
                // Swipe an unread one to mark it read; the row stays.
                return staggered(
                  i,
                  n.isRead
                      ? card
                      : Dismissible(
                          key: ValueKey('read-${n.id}'),
                          confirmDismiss: (_) async {
                            Haptics.select();
                            try {
                              await _repository.markRead(n.id);
                            } catch (_) {}
                            await _reload();
                            return false;
                          },
                          background: const _ReadSwipe(
                              AlignmentDirectional.centerStart),
                          secondaryBackground:
                              const _ReadSwipe(AlignmentDirectional.centerEnd),
                          child: card,
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReadSwipe extends StatelessWidget {
  const _ReadSwipe(this.alignment);

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.successTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.done_all_rounded, color: AppColors.success),
    );
  }
}

/// The icon and colour of a notification kind. One rounded style throughout,
/// and no two kinds share an icon (being added to a class used the same book
/// as a lesson prep, and was easy to mistake for it).
(IconData, Color) notificationLook(String kind) => switch (kind) {
      'signup' => (Icons.how_to_reg_rounded, AppColors.maroon),
      'announcement' => (Icons.campaign_rounded, AppColors.maroon),
      'decision' => (Icons.verified_rounded, AppColors.olive),
      'prep_submitted' => (Icons.menu_book_rounded, AppColors.sky),
      'prep_reviewed' => (Icons.rate_review_rounded, AppColors.gold),
      'lesson_changed' => (Icons.event_repeat_rounded, AppColors.coral),
      'birthdays' => (Icons.cake_rounded, AppColors.gold),
      'child_added' => (Icons.child_care_rounded, AppColors.olive),
      'attendance_taken' => (Icons.fact_check_rounded, AppColors.navy),
      'event_added' => (Icons.celebration_rounded, AppColors.olive),
      'competition_added' => (Icons.emoji_events_rounded, AppColors.gold),
      'class_assigned' => (Icons.group_add_rounded, AppColors.sky),
      'class_activity' => (Icons.edit_note_rounded, AppColors.sky),
      'missing_info' => (Icons.rule_rounded, AppColors.gold),
      'absence_followup' => (Icons.volunteer_activism_rounded, AppColors.coral),
      'absence_child' => (Icons.person_off_rounded, AppColors.coral),
      'class_removed' => (Icons.person_remove_rounded, AppColors.coral),
      'event_today' => (Icons.event_available_rounded, AppColors.gold),
      'lesson_prep_reminder' => (Icons.auto_stories_rounded, AppColors.navy),
      'app_update' => (Icons.system_update_rounded, AppColors.navy),
      'app_update_reminder' => (Icons.update_rounded, AppColors.gold),
      'profile_incomplete' => (Icons.badge_rounded, AppColors.gold),
      'attendance_missing' => (Icons.alarm_rounded, AppColors.coral),
      _ => (Icons.notifications_rounded, AppColors.navy),
    };
