import 'package:flutter/material.dart';

import '../attendance/attendance_screen.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../calendar/calendar_screen.dart';
import '../children/child_profile_screen.dart';
import '../classes/class_detail_screen.dart';
import '../servant_activities/admin_servant_activities_screen.dart';
import '../servant_activities/my_activities_screen.dart';
import '../servant_activities/servant_activity_detail_screen.dart';
import '../competitions/competitions_screen.dart';
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
    if (!n.isRead) {
      try {
        await _repository.markRead(n.id);
      } catch (_) {}
    }
    if (!mounted) return;
    final ref = n.refId;
    final Widget? screen = switch (n.kind) {
      'signup' => const PendingRequestsScreen(),
      'lesson_changed' => const LessonScheduleScreen(),
      'birthdays' => const CalendarScreen(),
      'event_added' => const EventsScreen(),
      'competition_added' => const CompetitionsScreen(),
      'child_added' when ref != null => ChildProfileScreen(childId: ref),
      'attendance_taken' ||
      'class_assigned' when ref != null =>
        ClassDetailScreen(classId: ref),
      'prep_submitted' => (ref == null ? null : await _servantDetail(ref)) ??
          const AdminServantActivitiesScreen(),
      'prep_reviewed' => const MyActivitiesScreen(showAppBar: true),
      'attendance_missing' when ref != null =>
        AttendanceScreen(showAppBar: true, initialClassId: ref),
      // 'event_today' only informs: tapping it marks it read.
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

  Future<void> _markAll() async {
    try {
      await _repository.markAllRead();
    } catch (_) {}
    await _reload();
  }

  (IconData, Color) _look(String kind) => switch (kind) {
        'signup' => (Icons.how_to_reg_outlined, AppColors.maroon),
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
                return staggered(
                    i,
                    Card(
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
                        subtitle: Text(
                          '${n.body}\n${AppDateUtils.sinceLabel(n.createdAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: n.isRead
                            ? null
                            : Icon(Icons.circle, size: 10, color: color),
                      ),
                    ));
              },
            );
          },
        ),
      ),
    );
  }
}
