import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/children/profile/profile_status.dart';

Child _child({
  bool active = true,
  DateTime? birth,
  DateTime? phone,
  DateTime? home,
}) =>
    Child(
      id: 'k',
      classId: 'c',
      fullName: 'إيريني رأفت',
      gender: Gender.girl,
      isActive: active,
      birthDate: birth,
      lastPhoneVisitDate: phone,
      lastHomeVisitDate: home,
    );

ChildSessionScore _day(DateTime d, {required bool present}) =>
    ChildSessionScore(
      sessionId: 's${d.day}',
      sessionDate: d,
      className: '6 بنات',
      childId: 'k',
      childName: 'إيريني رأفت',
      gender: Gender.girl,
      sundaySchool: present,
      vespers: false,
      mass: false,
      confession: false,
      score: present ? 5 : 0,
      maxScore: 20,
    );

final _sats = [
  DateTime(2026, 10, 31),
  DateTime(2026, 11, 7),
  DateTime(2026, 11, 14),
  DateTime(2026, 11, 21),
];

void main() {
  final today = DateTime(2026, 11, 23);

  group('absentRun', () {
    test('counts the latest Saturdays missed in a row', () {
      final history = [
        _day(_sats[0], present: true),
        _day(_sats[1], present: true),
        _day(_sats[2], present: false),
        _day(_sats[3], present: false),
      ];
      expect(absentRun(history, _sats), 2);
    });

    test('present last Saturday: no run', () {
      final history = [
        _day(_sats[2], present: false),
        _day(_sats[3], present: true),
      ];
      expect(absentRun(history, _sats), 0);
    });

    test('a Saturday the class did not take is skipped, not counted', () {
      final history = [
        _day(_sats[1], present: false),
        // 14 Nov not taken: no record.
        _day(_sats[3], present: false),
      ];
      expect(absentRun(history, _sats), 2);
    });
  });

  group('daysToBirthday', () {
    test('today, soon and far', () {
      expect(daysToBirthday(DateTime(2015, 11, 23), today), 0);
      expect(daysToBirthday(DateTime(2015, 11, 27), today), 4);
      expect(daysToBirthday(DateTime(2015, 11, 20), today), 362);
      expect(daysToBirthday(null, today), isNull);
    });
  });

  group('profileAlerts', () {
    test('all well: nothing', () {
      expect(profileAlerts(child: _child(), absentSaturdays: 0, today: today),
          isEmpty);
    });

    test('absent twice with no follow-up yet: both, absent first', () {
      final a =
          profileAlerts(child: _child(), absentSaturdays: 2, today: today);
      expect(a.map((x) => x.kind),
          [ProfileAlertKind.absent, ProfileAlertKind.noFollowUp]);
      expect(a.first.text, AppStrings.profileAbsentRun(2));
      expect(a.first.callToAction, isTrue);
      expect(a.last.text, AppStrings.profileNeverFollowedUp);
    });

    test('absent but called last week: only the absence', () {
      final a = profileAlerts(
        child: _child(phone: DateTime(2026, 11, 18)),
        absentSaturdays: 3,
        today: today,
      );
      expect(a.map((x) => x.kind), [ProfileAlertKind.absent]);
    });

    test('absent, last visit long ago: says how long', () {
      final a = profileAlerts(
        child: _child(home: DateTime(2026, 9, 1)),
        absentSaturdays: 2,
        today: today,
      );
      expect(a.last.text, AppStrings.profileLastFollowUp(83));
    });

    test('one absence is not an alert', () {
      expect(profileAlerts(child: _child(), absentSaturdays: 1, today: today),
          isEmpty);
    });

    test('birthday within a week', () {
      final a = profileAlerts(
        child: _child(birth: DateTime(2015, 11, 24)),
        absentSaturdays: 0,
        today: today,
      );
      expect(a.single.text, AppStrings.profileBirthdayIn(1));
    });

    test('a stopped child: only that', () {
      final a = profileAlerts(
        child: _child(active: false, birth: DateTime(2015, 11, 23)),
        absentSaturdays: 4,
        today: today,
      );
      expect(a.map((x) => x.kind), [ProfileAlertKind.inactive]);
    });
  });

  group('ProfileStatusStrip', () {
    Future<void> pump(WidgetTester tester, List<ProfileAlert> alerts,
            {VoidCallback? onCall}) =>
        tester.pumpWidget(MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                width: 340,
                child: ProfileStatusStrip(alerts: alerts, onCall: onCall),
              ),
            ),
          ),
        ));

    testWidgets('nothing to say: nothing drawn', (tester) async {
      await pump(tester, const []);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('shows two lines and «اتصل» calls', (tester) async {
      var calls = 0;
      await pump(
        tester,
        profileAlerts(child: _child(), absentSaturdays: 3, today: today),
        onCall: () => calls++,
      );
      expect(find.text(AppStrings.profileAbsentRun(3)), findsOneWidget);
      expect(find.text(AppStrings.profileNeverFollowedUp), findsOneWidget);
      await tester.tap(find.text(AppStrings.call));
      expect(calls, 1);
    });

    testWidgets('a birthday has no call button', (tester) async {
      await pump(
        tester,
        profileAlerts(
          child: _child(birth: DateTime(2015, 11, 23)),
          absentSaturdays: 0,
          today: today,
        ),
        onCall: () {},
      );
      expect(find.text(AppStrings.profileBirthdayToday), findsOneWidget);
      expect(find.text(AppStrings.call), findsNothing);
    });
  });
}
