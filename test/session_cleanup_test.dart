// What the device keeps must go when access ends, however it ends.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/profile.dart';
import 'package:sabtawya/data/models/school_class.dart';
import 'package:sabtawya/data/repositories/attendance_repository.dart';
import 'package:sabtawya/data/repositories/auth_repository.dart';
import 'package:sabtawya/data/repositories/class_repository.dart';
import 'package:sabtawya/data/services/device_cleanup.dart';
import 'package:sabtawya/state/session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = <String>[];

class _Auth extends AuthRepository {
  final events = StreamController<AuthState>.broadcast(sync: true);
  Map<String, dynamic>? row = _row();
  Session? session;
  bool signOutFails = false;

  @override
  Stream<AuthState> get authChanges => events.stream;

  @override
  Session? get currentSession => session;

  @override
  Future<Profile?> currentProfile() async =>
      row == null ? null : Profile.fromMap(row!);

  @override
  Future<void> signOut() async {
    _log.add('signOut');
    if (signOutFails) throw StateError('offline');
    session = null;
  }
}

Map<String, dynamic> _row({bool active = true, String? rejectedAt}) => {
      'id': 'u1',
      'full_name': 'S',
      'role': 'servant',
      'is_active': active,
      'rejected_at': rejectedAt,
    };

Session _session() => Session(
      accessToken: 'a.b.c',
      tokenType: 'bearer',
      user: const User(
        id: 'u1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      ),
    );

class _Classes extends ClassRepository {
  const _Classes();
  @override
  Future<List<ClassOverview>> overview({bool includeInactive = false}) async =>
      const [];
}

class _Years extends AttendanceRepository {
  const _Years();
  @override
  Future<AttendanceYear?> currentYear() async => null;
}

class _Cleanup extends DeviceCleanup {
  bool broken = false;

  Future<void> _note(String what) async {
    _log.add(what);
    if (broken) throw StateError(what);
  }

  @override
  Future<void> hideNames() => _note('hideNames');
  @override
  Future<void> wipe() => _note('wipe');
  @override
  Future<void> forgetPush({required bool server}) =>
      _note(server ? 'forgetPush' : 'forgetPush local');
  @override
  Future<void> registerPush() => _note('registerPush');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Auth auth;
  late _Cleanup cleanup;
  late SessionController session;

  setUp(() {
    _log.clear();
    auth = _Auth()..session = _session();
    cleanup = _Cleanup();
    session = SessionController(
      auth: auth,
      classes: const _Classes(),
      attendance: const _Years(),
      cleanup: cleanup,
    );
  });

  tearDown(() => session.dispose());

  test('an active account keeps its data and registers for pushes', () async {
    await session.load();
    await session.refreshAll();
    expect(session.status, SessionStatus.ready);
    expect(_log, ['registerPush']);
  });

  test('a token refresh that cannot get through keeps the app open', () async {
    await session.load();
    auth.events.addError(AuthRetryableFetchException(message: 'offline'));
    await Future<void>.delayed(Duration.zero);
    expect(session.status, SessionStatus.ready);

    auth.events.addError(StateError('something else'));
    await Future<void>.delayed(Duration.zero);
    expect(session.status, SessionStatus.error);
  });

  test('sign-out forgets the device while the session can still do it',
      () async {
    await session.signOut();
    expect(_log, ['forgetPush', 'hideNames', 'signOut']);
  });

  test('a sign-out that fails keeps this person registered for pushes',
      () async {
    auth.signOutFails = true;
    await expectLater(session.signOut(), throwsStateError);
    expect(_log, ['forgetPush', 'hideNames', 'signOut', 'registerPush']);
  });

  test('a cleanup that fails never blocks the sign-out', () async {
    cleanup.broken = true;
    await session.signOut();
    expect(_log, contains('signOut'));
  });

  test('a session that ends by itself clears the device', () async {
    auth.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await Future<void>.delayed(Duration.zero);
    expect(session.status, SessionStatus.signedOut);
    expect(_log, ['forgetPush local', 'wipe']);
  });

  test('opening the app with nobody signed in clears nothing', () async {
    auth.events.add(const AuthState(AuthChangeEvent.initialSession, null));
    await Future<void>.delayed(Duration.zero);
    expect(_log, isEmpty);
  });

  test('a deactivated account is cleared, and still hears the decision',
      () async {
    auth.row = _row(active: false);
    await session.load();
    expect(session.status, SessionStatus.inactive);
    expect(_log, ['registerPush', 'wipe']);
  });

  test('a refused account is cleared', () async {
    auth.row = _row(active: false, rejectedAt: '2026-11-01T10:00:00Z');
    await session.load();
    expect(session.status, SessionStatus.rejected);
    expect(_log, contains('wipe'));
  });

  test('a deleted account is cleared', () async {
    auth.row = null;
    await session.load();
    expect(session.status, SessionStatus.notFound);
    expect(_log, ['wipe']);
  });

  test('deactivated while the app is open: cleared on the next refresh',
      () async {
    await session.load();
    _log.clear();
    auth.row = _row(active: false);
    await session.refreshAll();
    expect(session.status, SessionStatus.inactive);
    expect(session.myClasses, isEmpty);
    expect(_log, ['wipe']);
  });
}
