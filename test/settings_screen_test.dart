import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/profile.dart';
import 'package:sabtawya/data/repositories/auth_repository.dart';
import 'package:sabtawya/features/settings/settings_screen.dart';
import 'package:sabtawya/state/session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _NoAuth extends AuthRepository {
  const _NoAuth();
  @override
  Stream<AuthState> get authChanges => const Stream.empty();
}

class _FakeSession extends SessionController {
  _FakeSession({required this.admin}) : super(auth: const _NoAuth());

  final bool admin;

  @override
  bool get isAdmin => admin;

  @override
  Profile? get profile => Profile(
        id: 'p',
        fullName: 'مينا فادي',
        role: admin ? AppRole.admin : AppRole.servant,
        isActive: true,
        email: 'mina@example.com',
      );

  @override
  AttendanceYear? get currentYear => AttendanceYear(
        id: 'y',
        name: '2026 / 2027',
        startDate: DateTime(2026, 9, 26),
        endDate: DateTime(2027, 9, 25),
        sessionWeekday: 6,
        pointsSundaySchool: 5,
        pointsVespers: 5,
        pointsMass: 5,
        pointsConfession: 5,
        maxPointsPerSession: 20,
        isCurrent: true,
      );
}

Widget _app(SessionController session) => ChangeNotifierProvider.value(
      value: session,
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SettingsScreen(),
        ),
      ),
    );

void main() {
  testWidgets('settings are grouped: profile, account, app', (tester) async {
    await tester.pumpWidget(_app(_FakeSession(admin: false)));
    await tester.pumpAndSettle();

    expect(find.text('مينا فادي'), findsOneWidget);
    expect(find.textContaining('mina@example.com'), findsOneWidget);
    expect(find.text(AppStrings.account), findsOneWidget);
    expect(find.text(AppStrings.changePassword), findsOneWidget);
    expect(find.text(AppStrings.logout), findsOneWidget);
    expect(find.text(AppStrings.moreApp), findsOneWidget);
    // Always listed; on the website (the test) it is off, with the reason.
    expect(find.text(AppStrings.callerIdSwitch), findsOneWidget);
    expect(find.text(AppStrings.tourMenu), findsOneWidget);
    // The update check lives in المزيد only.
    expect(find.text(AppStrings.checkForUpdates), findsNothing);
    // The admin's groups are not shown to a servant.
    expect(find.text(AppStrings.absenceAlertSettings), findsNothing);
    expect(find.text(AppStrings.maxPoints), findsNothing);
  });

  testWidgets('the admin also sees the alert and year groups', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_FakeSession(admin: true)));
    await tester.pump();

    expect(find.text(AppStrings.absenceAlertSettings), findsOneWidget);
    expect(find.text(AppStrings.maxPoints), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    // 26 Sep 2026 -> 25 Sep 2027 holds 53 Saturdays (both ends are Saturdays).
    expect(find.text('53 سبت'), findsOneWidget);
  });
}
