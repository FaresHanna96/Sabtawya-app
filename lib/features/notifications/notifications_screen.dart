import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../announcements/announcement_dialog.dart';
import '../attendance/attendance_screen.dart';
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
import '../../data/repositories/servant_repository.dart';
import '../../data/models/event.dart';
import '../../data/repositories/event_repository.dart';
import '../children/absence_followup_screen.dart';
import '../children/birthday_screen.dart';
import '../children/missing_info_screen.dart';
import '../children/child_profile_screen.dart';
import '../children/follow_up_call.dart';
import '../classes/class_detail_screen.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../servant_activities/admin_servant_activities_screen.dart';
import '../servant_activities/lesson_prep_screen.dart';
import '../servant_activities/prep_review_sheet.dart';
import '../servant_activities/my_activities_screen.dart';
import '../servant_activities/servant_activity_detail_screen.dart';
import '../../state/session_controller.dart';
import '../competitions/competitions_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/events_screen.dart';
import '../lessons/lesson_schedule_screen.dart';
import '../servants/pending_requests_screen.dart';

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
    final session = context.read<SessionController>();
    final seesCompetitions = session.isAdmin || session.isGeneralServant;
    if (!n.isRead) {
      try {
        await _repository.markRead(n.id);
      } catch (_) {}
    }
    if (!mounted) return;
    final ref = n.refId;

    // A prep sent for review opens its review sheet; a reviewed one opens
    // that lesson's prep page. Entries made before the id was kept (they
    // carry a servant's id, or none) fall through to the pages below.
    final prep =
        (n.kind == 'prep_submitted' || n.kind == 'prep_reviewed') && ref != null
            ? await _prep(ref)
            : null;
    if (!mounted) return;
    // An announcement is read where it is: its whole text in a dialog.
    if (n.kind == 'announcement') {
      await showAnnouncementDialog(
        context,
        title: n.title,
        body: n.body,
        sentAt: n.createdAt,
      );
      if (mounted) await _reload();
      return;
    }
    if (prep != null && n.kind == 'prep_submitted') {
      await showPrepReviewSheet(
        context,
        prep: prep,
        onReview: (status, comment) => const ServantActivityRepository()
            .reviewPrep(prepId: prep.id, status: status, comment: comment),
      );
      if (mounted) await _reload();
      return;
    }

    final Widget? screen = switch (n.kind) {
      'signup' => const PendingRequestsScreen(),
      'lesson_changed' => const LessonScheduleScreen(),
      'birthdays' => const BirthdayScreen(),
      // The Saturday 5 PM reminder: the children whose record has gaps.
      'missing_info' => const MissingInfoScreen(),
      // The Sunday 5 PM reminder: children absent two Saturdays or more.
      'absence_followup' => const AbsenceFollowUpScreen(),
      'event_added' => const EventsScreen(),
      // The event itself when it can still be found, else the list.
      'event_today' =>
        (ref == null ? null : await _eventDetail(ref)) ?? const EventsScreen(),
      // Old notifications a plain servant may still hold: nothing to open.
      'competition_added' when seesCompetitions => const CompetitionsScreen(),
      'child_added' when ref != null => ChildProfileScreen(childId: ref),
      // A child's absences reached an alert level: their profile.
      'absence_child' when n.childId != null =>
        ChildProfileScreen(childId: n.childId!),
      // 'class_activity' about one child (edited, stopped, moved in, a visit):
      // that child's profile. Older entries carry only the class.
      'class_activity' when n.childId != null =>
        ChildProfileScreen(childId: n.childId!),
      // 'class_activity': somebody of this class did something in it.
      'class_assigned' ||
      'class_activity' when ref != null =>
        ClassDetailScreen(classId: ref),
      // That class's sheet for the Saturday the entry names.
      'attendance_taken' when ref != null => AttendanceScreen(
          showAppBar: true,
          initialClassId: ref,
          initialDate: n.mentionedDate,
        ),
      'prep_submitted' => (ref == null ? null : await _servantDetail(ref)) ??
          const AdminServantActivitiesScreen(),
      'prep_reviewed' => prep != null
          ? LessonPrepScreen(
              sessionId: prep.sessionId,
              sessionDate: prep.sessionDate,
            )
          : const MyActivitiesScreen(showAppBar: true),
      // The reminder is about the day it was sent.
      'attendance_missing' when ref != null => AttendanceScreen(
          showAppBar: true,
          initialClassId: ref,
          initialDate: n.createdAt,
        ),
      // 'decision' and 'class_removed' only inform: tapping marks them read.
      _ => null,
    };
    if (!mounted) return;
    if (screen != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => screen),
      );
    }
    await _reload();
  }

  /// The preparation a notification is about, or null (an older entry whose
  /// id is a servant's, a deleted prep, or no connection).
  Future<LessonPrep?> _prep(String id) async {
    try {
      return await const ServantActivityRepository().prepById(id);
    } catch (_) {
      return null;
    }
  }

  /// The page of the event a notification is about.
  Future<Widget?> _eventDetail(String eventId) async {
    try {
      final events = await const EventRepository().listEvents();
      final match = events.where((Event e) => e.id == eventId);
      return match.isEmpty ? null : EventDetailScreen(event: match.first);
    } catch (_) {
      return null;
    }
  }

  /// The activity page of the servant a prep notification is about.
  Future<Widget?> _servantDetail(String servantId) async {
    try {
      final servants = await const ServantRepository().servants();
      final match = servants.where((s) => s.id == servantId);
      if (match.isEmpty) return null;
      return ServantActivityDetailScreen(
        servantId: servantId,
        servantName: match.first.fullName,
      );
    } catch (_) {
      return null;
    }
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

  (IconData, Color) _look(String kind) => switch (kind) {
        'signup' => (Icons.how_to_reg_outlined, AppColors.maroon),
        'announcement' => (Icons.campaign_rounded, AppColors.maroon),
        'decision' => (Icons.verified_outlined, AppColors.olive),
        'prep_submitted' => (Icons.menu_book_outlined, AppColors.sky),
        'prep_reviewed' => (Icons.rate_review_outlined, AppColors.gold),
        'lesson_changed' => (Icons.event_repeat_outlined, AppColors.coral),
        'birthdays' => (Icons.cake_outlined, AppColors.coral),
        'child_added' => (Icons.child_care_outlined, AppColors.olive),
        'attendance_taken' => (Icons.fact_check_outlined, AppColors.navy),
        'event_added' => (Icons.celebration_outlined, AppColors.olive),
        'competition_added' => (Icons.emoji_events_outlined, AppColors.gold),
        'class_assigned' => (Icons.class_outlined, AppColors.sky),
        'class_activity' => (Icons.edit_note_rounded, AppColors.sky),
        'missing_info' => (Icons.rule_rounded, AppColors.gold),
        'absence_followup' => (
            Icons.volunteer_activism_rounded,
            AppColors.coral
          ),
        'absence_child' => (Icons.person_off_outlined, AppColors.coral),
        'class_removed' => (Icons.person_remove_outlined, AppColors.coral),
        'event_today' => (Icons.celebration_rounded, AppColors.gold),
        'attendance_missing' => (Icons.alarm_rounded, AppColors.coral),
        _ => (Icons.notifications_none_rounded, AppColors.navy),
      };

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
                final (icon, color) = _look(n.kind);
                final card = Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: n.isRead ? null : color.withValues(alpha: 0.07),
                      child: ListTile(
                        onTap: () => _open(n),
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(icon, color: color, size: 20),
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
