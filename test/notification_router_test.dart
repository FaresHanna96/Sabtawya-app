import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/services/push_tap.dart';
import 'package:sabtawya/data/models/app_notification.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/competition.dart';
import 'package:sabtawya/data/models/event.dart';
import 'package:sabtawya/data/models/lesson.dart';
import 'package:sabtawya/data/models/servant_activity.dart';
import 'package:sabtawya/features/attendance/attendance_screen.dart';
import 'package:sabtawya/features/children/absence_followup_screen.dart';
import 'package:sabtawya/features/children/birthday_screen.dart';
import 'package:sabtawya/features/children/child_profile_screen.dart';
import 'package:sabtawya/features/children/missing_info_screen.dart';
import 'package:sabtawya/features/classes/class_detail_screen.dart';
import 'package:sabtawya/features/competitions/competition_detail_screen.dart';
import 'package:sabtawya/features/competitions/competitions_screen.dart';
import 'package:sabtawya/features/events/event_detail_screen.dart';
import 'package:sabtawya/features/events/events_screen.dart';
import 'package:sabtawya/features/lessons/lesson_schedule_screen.dart';
import 'package:sabtawya/features/notifications/notification_router.dart';
import 'package:sabtawya/features/profile/my_profile_screen.dart';
import 'package:sabtawya/features/servant_activities/admin_servant_activities_screen.dart';
import 'package:sabtawya/features/servant_activities/lesson_prep_screen.dart';
import 'package:sabtawya/features/servant_activities/my_activities_screen.dart';
import 'package:sabtawya/features/servant_activities/servant_activity_detail_screen.dart';
import 'package:sabtawya/features/servants/pending_requests_screen.dart';

final _year = AttendanceYear(
  id: 'y',
  name: '2026 - 2027',
  startDate: DateTime(2026, 9, 12),
  endDate: DateTime(2027, 9, 10),
  sessionWeekday: DateTime.saturday,
  pointsSundaySchool: 5,
  pointsVespers: 5,
  pointsMass: 5,
  pointsConfession: 5,
  maxPointsPerSession: 20,
  isCurrent: true,
);

final _event = Event(
  id: 'e',
  title: 'رحلة',
  eventDate: DateTime(2026, 12, 5),
  cost: 10,
  createdBy: 'a',
  createdAt: DateTime(2026, 11, 1),
);

final _competition = Competition(
  id: 'k',
  title: 'مسابقة',
  weekDate: DateTime(2026, 12, 5),
  maxMark: 10,
  createdBy: 'a',
  createdAt: DateTime(2026, 11, 1),
);

final _prep = LessonPrep(
  id: 'p',
  servantId: 's',
  servantName: 'مينا',
  sessionId: 'ses',
  sessionDate: DateTime(2026, 11, 28),
  status: 'pending',
  photos: const [],
);

/// Answers only for the ids it knows, as the database does.
class _Lookups extends NotificationLookups {
  const _Lookups();

  @override
  Future<LessonPrep?> prep(String id) async => id == 'p' ? _prep : null;

  @override
  Future<Event?> event(String id) async => id == 'e' ? _event : null;

  @override
  Future<Competition?> competition(String id) async =>
      id == 'k' ? _competition : null;

  @override
  Future<String?> servantName(String id) async => id == 's' ? 'مينا' : null;

  @override
  Future<AttendanceSession?> session(String classId, DateTime day) async =>
      classId == 'c' && day == DateTime(2026, 11, 28)
          ? AttendanceSession(
              id: 'ses',
              yearId: 'y',
              classId: 'c',
              sessionDate: day,
              isLocked: false,
            )
          : null;

  @override
  Future<DateTime?> lessonDay(String lessonId, AttendanceYear year) async =>
      lessonId == 'l' ? DateTime(2027, 1, 2) : null;
}

AppNotification _n(
  String kind, {
  String? ref,
  String? child,
  String title = 't',
  String body = 'b',
}) =>
    AppNotification(
      id: '1',
      kind: kind,
      title: title,
      body: body,
      // A Friday.
      createdAt: DateTime(2026, 11, 27, 17),
      refId: ref,
      childId: child,
    );

const _admin = true;

Future<NotificationTarget> _route(
  AppNotification n, {
  bool admin = false,
  bool general = false,
}) =>
    notificationTarget(
      n,
      viewer: NotificationViewer(
        isAdmin: admin,
        isGeneralServant: general,
        year: _year,
      ),
      lookups: const _Lookups(),
    );

Future<T> _screen<T>(AppNotification n,
    {bool admin = false, bool general = false}) async {
  final target = await _route(n, admin: admin, general: general);
  expect(target, isA<OpenScreen>(), reason: n.kind);
  final screen = (target as OpenScreen).screen;
  expect(screen, isA<T>(), reason: n.kind);
  return screen as T;
}

void main() {
  test('a sign-up opens the requests with that person marked', () async {
    final s = await _screen<PendingRequestsScreen>(_n('signup', ref: 's'),
        admin: _admin);
    expect(s.highlightId, 's');
    expect(await _route(_n('signup', ref: 's')), isA<ShowText>());
  });

  test('account notices open my profile', () async {
    await _screen<MyProfileScreen>(_n('decision'));
    await _screen<MyProfileScreen>(_n('profile_incomplete'));
  });

  test('class notices open the class or the child', () async {
    expect(
        (await _screen<ClassDetailScreen>(_n('class_assigned', ref: 'c')))
            .classId,
        'c');
    await _screen<ClassDetailScreen>(_n('class_activity', ref: 'c'));
    expect(
        (await _screen<ChildProfileScreen>(
                _n('class_activity', ref: 'c', child: 'ch')))
            .childId,
        'ch');
    await _screen<ChildProfileScreen>(_n('child_added', ref: 'ch'));
    await _screen<ChildProfileScreen>(_n('absence_child', ref: 'c', child: 'ch'));
  });

  test('follow-up and missing-data lists are filtered to the class', () async {
    expect(
        (await _screen<AbsenceFollowUpScreen>(
                _n('absence_followup', ref: 'c')))
            .initialClassIds,
        {'c'});
    expect(
        (await _screen<MissingInfoScreen>(_n('missing_info', ref: 'c')))
            .initialClassIds,
        {'c'});
    expect(
        (await _screen<AbsenceFollowUpScreen>(_n('absence_followup')))
            .initialClassIds,
        isEmpty);
  });

  test('attendance notices open that class on that day', () async {
    final taken = await _screen<AttendanceScreen>(
        _n('attendance_taken', ref: 'c', body: 'يوم 2026-11-21'));
    expect(taken.initialClassId, 'c');
    expect(taken.initialDate, DateTime(2026, 11, 21));
    final missing = await _screen<AttendanceScreen>(
        _n('attendance_missing', ref: 'c'));
    expect(missing.initialDate, DateTime(2026, 11, 27, 17));
  });

  test('the Friday prep reminder opens tomorrow\'s prep page', () async {
    final s = await _screen<LessonPrepScreen>(
        _n('lesson_prep_reminder', ref: 'c'));
    expect(s.sessionId, 'ses');
    await _screen<MyActivitiesScreen>(
        _n('lesson_prep_reminder', ref: 'other'));
  });

  test('lesson notices: the date in the text, tomorrow, or the lesson',
      () async {
    Future<DateTime?> focus(AppNotification n) async =>
        (await _screen<LessonScheduleScreen>(n)).focusDate;
    expect(await focus(_n('lesson_changed', body: 'درس يوم 2026-12-05 رجع')),
        DateTime(2026, 12, 5));
    // A no-lesson Saturday's notice names the day in its title.
    expect(
        await focus(_n('lesson_changed',
            title: 'نشاط ترفيهي 🎉 يوم 2026-12-12', body: '• مفيش حضور.')),
        DateTime(2026, 12, 12));
    expect(await focus(_n('lesson_changed', title: 'مفيش درس بكرة')),
        DateTime(2026, 11, 28));
    expect(await focus(_n('lesson_changed', ref: 'l')), DateTime(2027, 1, 2));
    expect(await focus(_n('lesson_changed')), isNull);
  });

  test('preparations open the review sheet or the prep page', () async {
    expect(await _route(_n('prep_submitted', ref: 'p'), admin: _admin),
        isA<ReviewPrep>());
    await _screen<ServantActivityDetailScreen>(_n('prep_submitted', ref: 's'));
    await _screen<AdminServantActivitiesScreen>(
        _n('prep_submitted', ref: 'gone'));
    await _screen<LessonPrepScreen>(_n('prep_reviewed', ref: 'p'));
    await _screen<MyActivitiesScreen>(_n('prep_reviewed', ref: 'gone'));
  });

  test('an activity or competition opens itself, else its list', () async {
    for (final kind in ['event_added', 'event_today']) {
      expect((await _screen<EventDetailScreen>(_n(kind, ref: 'e'))).event.id,
          'e');
      await _screen<EventsScreen>(_n(kind, ref: 'gone'));
      await _screen<EventsScreen>(_n(kind));
    }
    await _screen<CompetitionDetailScreen>(_n('competition_added', ref: 'k'),
        general: true);
    await _screen<CompetitionsScreen>(_n('competition_added'), general: true);
    expect(await _route(_n('competition_added', ref: 'k')), isA<ShowText>());
  });

  test('birthdays open the birthdays page', () async {
    await _screen<BirthdayScreen>(_n('birthdays'));
  });

  test('update notices check for the update', () async {
    expect(await _route(_n('app_update')), isA<CheckForUpdate>());
    expect(await _route(_n('app_update_reminder')), isA<CheckForUpdate>());
  });

  test('what has no page shows its text, so no tap does nothing', () async {
    for (final n in [
      _n('announcement'),
      _n('class_removed'),
      _n('something_new'),
      _n('class_assigned'),
      _n('absence_child'),
    ]) {
      expect(await _route(n), isA<ShowText>(), reason: n.kind);
    }
  });

  test('the lesson\'s Saturday follows the programme and its breaks', () {
    const programme = LessonProgramme(<Lesson>[], <LessonSlot, LessonExtras>{});
    final first = LessonProgramme.programmeStart(
        _year.startDate, _year.sessionWeekday);
    expect(dayOfSlot(programme, _year, const LessonSlot(1, 1)), first);
    expect(dayOfSlot(programme, _year, const LessonSlot(1, 2)),
        DateTime(first.year, first.month, first.day + 7));
    final postponed = LessonProgramme(
      const <Lesson>[],
      const <LessonSlot, LessonExtras>{},
      {LessonProgramme.keyOf(first): true},
    );
    expect(dayOfSlot(postponed, _year, const LessonSlot(1, 1)),
        DateTime(first.year, first.month, first.day + 7));
  });

  test('a push is read by its entry, or by its own kind', () {
    expect(PushTap.fromData({'notification_id': 'n', 'badge': '2'})!
        .notificationId, 'n');
    final signup = PushTap.fromData({'kind': 'signup', 'ref_id': 's'},
        title: 'طلب')!;
    expect((signup.kind, signup.refId, signup.title), ('signup', 's', 'طلب'));
    expect(PushTap.fromData({'badge': '2'}), isNull);
  });
}
