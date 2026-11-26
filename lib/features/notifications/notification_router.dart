import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/attendance.dart';
import '../../data/models/competition.dart';
import '../../data/models/event.dart';
import '../../data/models/lesson.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/competition_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../state/session_controller.dart';
import '../announcements/announcement_dialog.dart';
import '../attendance/attendance_screen.dart';
import '../children/absence_followup_screen.dart';
import '../children/birthday_screen.dart';
import '../children/child_profile_screen.dart';
import '../children/missing_info_screen.dart';
import '../classes/class_detail_screen.dart';
import '../competitions/competition_detail_screen.dart';
import '../competitions/competitions_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/events_screen.dart';
import '../home/update_check.dart';
import '../lessons/lesson_schedule_screen.dart';
import '../profile/my_profile_screen.dart';
import '../servant_activities/admin_servant_activities_screen.dart';
import '../servant_activities/lesson_prep_screen.dart';
import '../servant_activities/my_activities_screen.dart';
import '../servant_activities/prep_review_sheet.dart';
import '../servant_activities/servant_activity_detail_screen.dart';
import '../servants/pending_requests_screen.dart';

/// What opening a notification does. The bell and a tapped push share it.
sealed class NotificationTarget {
  const NotificationTarget();
}

/// A page about the thing the notification names.
class OpenScreen extends NotificationTarget {
  const OpenScreen(this.screen);
  final Widget screen;
}

/// Nothing to open (or no longer allowed to): the whole text in a dialog.
class ShowText extends NotificationTarget {
  const ShowText();
}

/// A preparation waiting for the admin's review.
class ReviewPrep extends NotificationTarget {
  const ReviewPrep(this.prep);
  final LessonPrep prep;
}

/// "A new version is out": check for it now.
class CheckForUpdate extends NotificationTarget {
  const CheckForUpdate();
}

/// Who is looking, as far as routing cares.
class NotificationViewer {
  const NotificationViewer({
    this.isAdmin = false,
    this.isGeneralServant = false,
    this.year,
  });

  final bool isAdmin;
  final bool isGeneralServant;
  final AttendanceYear? year;
}

/// The reads routing needs. Each answers null when the thing is gone, not
/// visible to this person, or there is no connection.
class NotificationLookups {
  const NotificationLookups();

  Future<T?> _safe<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  Future<LessonPrep?> prep(String id) =>
      _safe(() => const ServantActivityRepository().prepById(id));

  Future<Event?> event(String id) => _safe(() async {
        final all = await const EventRepository().listEvents();
        return all.where((e) => e.id == id).firstOrNull;
      });

  Future<Competition?> competition(String id) => _safe(() async {
        final all = await const CompetitionRepository().listCompetitions();
        return all.where((c) => c.id == id).firstOrNull;
      });

  Future<String?> servantName(String id) => _safe(() async {
        final all = await const ServantRepository().servants();
        return all.where((s) => s.id == id).firstOrNull?.fullName;
      });

  /// The class's attendance session on [day], where its preparation goes.
  Future<AttendanceSession?> session(String classId, DateTime day) =>
      _safe(() async {
        final all = await const ServantActivityRepository()
            .sessionsForClasses([classId]);
        return all
            .where((s) => DateUtils.isSameDay(s.sessionDate, day))
            .firstOrNull;
      });

  /// The Saturday of [year] on which the lesson [lessonId] is taught.
  Future<DateTime?> lessonDay(String lessonId, AttendanceYear year) =>
      _safe(() async {
        const repository = LessonRepository();
        final slot = await repository.slotOfLesson(lessonId);
        if (slot == null) return null;
        return dayOfSlot(await repository.programme(), year, slot);
      });
}

/// The first session day of [year] whose lesson is [slot], or null.
DateTime? dayOfSlot(
  LessonProgramme programme,
  AttendanceYear year,
  LessonSlot slot,
) {
  final first =
      LessonProgramme.programmeStart(year.startDate, year.sessionWeekday);
  for (var day = first;
      !day.isAfter(year.endDate);
      day = DateTime(day.year, day.month, day.day + 7)) {
    if (programme.slotOn(day, first) == slot) return day;
  }
  return null;
}

/// Where [n] leads for [viewer].
Future<NotificationTarget> notificationTarget(
  AppNotification n, {
  required NotificationViewer viewer,
  NotificationLookups lookups = const NotificationLookups(),
}) async {
  final ref = n.refId;
  final seesCompetitions = viewer.isAdmin || viewer.isGeneralServant;
  final sent = AppDateUtils.dateOnly(n.createdAt);

  NotificationTarget open(Widget screen) => OpenScreen(screen);

  switch (n.kind) {
    case 'signup':
      return viewer.isAdmin
          ? open(PendingRequestsScreen(highlightId: ref))
          : const ShowText();
    case 'decision' || 'profile_incomplete':
      return open(const MyProfileScreen());
    case 'birthdays':
      return open(const BirthdayScreen());
    case 'missing_info':
      return open(MissingInfoScreen(
          initialClassIds: ref == null ? const {} : {ref}));
    case 'absence_followup':
      return open(AbsenceFollowUpScreen(
          initialClassIds: ref == null ? const {} : {ref}));
    case 'absence_child' when n.childId != null:
      return open(ChildProfileScreen(childId: n.childId!));
    case 'child_added' when ref != null:
      return open(ChildProfileScreen(childId: ref));
    // About one child (edited, stopped, moved in, a visit): their profile.
    // Older entries carry only the class.
    case 'class_activity' when n.childId != null:
      return open(ChildProfileScreen(childId: n.childId!));
    case 'class_assigned' || 'class_activity' when ref != null:
      return open(ClassDetailScreen(classId: ref));
    // That class's sheet for the Saturday the entry names.
    case 'attendance_taken' when ref != null:
      return open(AttendanceScreen(
        showAppBar: true,
        initialClassId: ref,
        initialDate: n.mentionedDate,
      ));
    // The reminder is about the day it was sent.
    case 'attendance_missing' when ref != null:
      return open(AttendanceScreen(
        showAppBar: true,
        initialClassId: ref,
        initialDate: n.createdAt,
      ));
    // Sent on Friday about tomorrow's lesson of that class.
    case 'lesson_prep_reminder':
      final saturday = DateTime(sent.year, sent.month, sent.day + 1);
      final session =
          ref == null ? null : await lookups.session(ref, saturday);
      return open(session == null
          ? const MyActivitiesScreen(showAppBar: true)
          : LessonPrepScreen(
              sessionId: session.id,
              sessionDate: session.sessionDate,
            ));
    case 'lesson_changed':
      final year = viewer.year;
      var day = ref == null || year == null
          ? null
          : await lookups.lessonDay(ref, year);
      day ??= n.mentionedDate;
      // The Friday notice names no date: it is about the next day.
      if (day == null && n.title.contains('بكرة')) {
        day = DateTime(sent.year, sent.month, sent.day + 1);
      }
      return open(LessonScheduleScreen(focusDate: day));
    // A prep sent for review opens its review sheet. Entries made before the
    // id was kept carry a servant's id, or none.
    case 'prep_submitted':
      final prep = ref == null ? null : await lookups.prep(ref);
      if (prep != null) return ReviewPrep(prep);
      final name = ref == null ? null : await lookups.servantName(ref);
      return open(name == null
          ? const AdminServantActivitiesScreen()
          : ServantActivityDetailScreen(servantId: ref!, servantName: name));
    case 'prep_reviewed':
      final prep = ref == null ? null : await lookups.prep(ref);
      return open(prep == null
          ? const MyActivitiesScreen(showAppBar: true)
          : LessonPrepScreen(
              sessionId: prep.sessionId,
              sessionDate: prep.sessionDate,
            ));
    case 'event_added' || 'event_today':
      final event = ref == null ? null : await lookups.event(ref);
      return open(event == null
          ? const EventsScreen()
          : EventDetailScreen(event: event));
    // Old entries a plain servant may still hold have nothing to open.
    case 'competition_added' when seesCompetitions:
      final competition = ref == null ? null : await lookups.competition(ref);
      return open(competition == null
          ? const CompetitionsScreen()
          : CompetitionDetailScreen(competition: competition));
    case 'app_update' || 'app_update_reminder':
      return const CheckForUpdate();
    // Announcements, being removed from a class, and anything unknown.
    default:
      return const ShowText();
  }
}

/// Opens what [n] is about. Returns once the page or dialog is closed.
Future<void> openNotification(
  BuildContext context,
  AppNotification n, {
  NotificationLookups lookups = const NotificationLookups(),
}) async {
  final session = context.read<SessionController>();
  final target = await notificationTarget(
    n,
    viewer: NotificationViewer(
      isAdmin: session.isAdmin,
      isGeneralServant: session.isGeneralServant,
      year: session.currentYear,
    ),
    lookups: lookups,
  );
  if (!context.mounted) return;
  switch (target) {
    case OpenScreen(:final screen):
      await Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => screen));
    case ReviewPrep(:final prep):
      await showPrepReviewSheet(
        context,
        prep: prep,
        onReview: (status, comment) => const ServantActivityRepository()
            .reviewPrep(prepId: prep.id, status: status, comment: comment),
      );
    case CheckForUpdate():
      await checkForUpdatesNow(
        context,
        // The home shell shows the banner (or the forced screen), so go back
        // to it.
        onFound: (update) {
          UpdateService.found.value = update;
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      );
    case ShowText():
      final announcement = n.kind == 'announcement';
      await showAnnouncementDialog(
        context,
        title: n.title,
        body: n.body,
        sentAt: n.createdAt,
        icon: announcement ? Icons.campaign_rounded : Icons.notifications_rounded,
        iconColor: announcement ? AppColors.maroon : AppColors.navy,
        showLabel: announcement,
      );
  }
}
