import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/connectivity_service.dart';
import '../core/services/push_service.dart';
import '../core/utils/app_failure.dart';
import '../data/models/attendance.dart';
import '../data/models/child.dart';
import '../data/models/profile.dart';
import '../data/models/school_class.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/class_repository.dart';
import '../data/services/device_cleanup.dart';

enum SessionStatus {
  /// Resolving the stored session and loading the profile.
  loading,
  signedOut,

  /// Signed in via a password-recovery link — show the new-password form.
  passwordRecovery,

  /// Signed in, but the email has no row in the profiles table.
  notFound,

  /// Signed in, but the admin rejected the sign-up request.
  rejected,

  /// Signed in, but waiting for an admin to activate the account.
  inactive,
  ready,
  error,
}

/// Holds who is signed in, what role they have, and which classes they can
/// reach. Every screen reads from here instead of re-querying the profile.
class SessionController extends ChangeNotifier {
  SessionController({
    AuthRepository auth = const AuthRepository(),
    ClassRepository classes = const ClassRepository(),
    AttendanceRepository attendance = const AttendanceRepository(),
    DeviceCleanup cleanup = const DeviceCleanup(),
  })  : _auth = auth,
        _classes = classes,
        _attendance = attendance,
        _cleanup = cleanup {
    _subscription = _auth.authChanges.listen(
      _onAuthChanged,
      onError: (Object error) {
        // A token refresh that could not reach the server: the library tries
        // again by itself and the session stays. Showing the error screen would
        // close whatever is open, offline included.
        if (error is AuthRetryableFetchException) return;
        _fail(error);
      },
    );
    PushService.instance.received.addListener(_onPush);
  }

  /// A push while the app is open: a servant waiting for approval re-checks.
  void _onPush() {
    if (_status == SessionStatus.inactive ||
        _status == SessionStatus.rejected) {
      load();
    }
  }

  final AuthRepository _auth;
  final ClassRepository _classes;
  final AttendanceRepository _attendance;
  final DeviceCleanup _cleanup;

  StreamSubscription<AuthState>? _subscription;

  SessionStatus _status = SessionStatus.loading;
  Profile? _profile;
  List<ClassOverview> _myClasses = const <ClassOverview>[];
  AttendanceYear? _currentYear;
  String? _errorMessage;

  SessionStatus get status => _status;
  Profile? get profile => _profile;
  List<ClassOverview> get myClasses => _myClasses;
  AttendanceYear? get currentYear => _currentYear;
  String? get errorMessage => _errorMessage;

  bool get isAdmin => _profile?.isAdmin ?? false;
  bool get isGeneralServant => _profile?.isGeneralServant ?? false;
  String get displayName => _profile?.fullName ?? '';

  int _dataVersion = 0;

  /// Bumped whenever a write succeeds anywhere in the app, so open screens
  /// can reload their data.
  int get dataVersion => _dataVersion;

  void markChanged() {
    _dataVersion++;
    notifyListeners();
  }

  void _onAuthChanged(AuthState state) {
    if (state.session == null) {
      // Also when the session ends by itself (expired or revoked), where
      // signOut() below never ran.
      if (state.event == AuthChangeEvent.signedOut) {
        unawaited(_quietly(() => _cleanup.forgetPush(server: false)));
        unawaited(_quietly(_cleanup.wipe));
      }
      _loadToken++;
      _profile = null;
      _myClasses = const <ClassOverview>[];
      _currentYear = null;
      _errorMessage = null;
      _status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    // Password-recovery links sign the user in with a special event. Show the
    // new-password form instead of the normal home shell.
    if (state.event == AuthChangeEvent.passwordRecovery) {
      _loadToken++;
      _status = SessionStatus.passwordRecovery;
      notifyListeners();
      return;
    }
    // While the new-password form is open, saving the password fires
    // userUpdated and a resume fires tokenRefreshed. Treating them as a fresh
    // sign-in would tear the form down before it could confirm and sign the
    // user out. Only a sign-out (handled above) leaves this state.
    if (_status == SessionStatus.passwordRecovery) return;
    // Token refreshes, resume-from-background and user-metadata events arrive
    // for the user who is already signed in. Flipping to the loading state for
    // those would tear down whatever screen (and unsaved attendance) is open.
    final sameUser = _profile?.id == state.session!.user.id;
    if (sameUser && _status == SessionStatus.ready) {
      refreshAll();
      return;
    }
    load();
  }

  int _loadToken = 0;

  /// Loads the profile, then the classes and current year it unlocks.
  Future<void> load() => _load();

  Future<void> _load({bool retried = false}) async {
    final token = ++_loadToken;
    _status = SessionStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _auth.currentProfile();
      if (token != _loadToken) return;
      _profile = profile;

      if (profile == null) {
        _status = SessionStatus.notFound;
        unawaited(_quietly(_cleanup.wipe));
        notifyListeners();
        return;
      }
      // Servants waiting for approval are registered too, so the decision
      // reaches them as a push.
      unawaited(_quietly(_cleanup.registerPush));
      if (profile.isRejected) {
        _status = SessionStatus.rejected;
        unawaited(_quietly(_cleanup.wipe));
        notifyListeners();
        return;
      }
      if (!profile.isActive) {
        _status = SessionStatus.inactive;
        unawaited(_quietly(_cleanup.wipe));
        notifyListeners();
        return;
      }

      final classes = await _classes.overview();
      final year = await _attendance.currentYear();
      // A sign-out (or a newer load) while we were waiting wins.
      if (token != _loadToken) return;
      _myClasses = classes;
      _currentYear = year;
      _status = SessionStatus.ready;
    } catch (e) {
      if (token != _loadToken) return;
      // The first request just found out there is no connection: now the kept
      // answers can be read.
      if (!retried && !ConnectivityService.instance.isOnline) {
        return _load(retried: true);
      }
      _fail(e);
      return;
    }
    notifyListeners();
  }

  /// Re-reads profile, classes and current year without leaving the `ready`
  /// state. Use this after an admin changes the year or a class; [load] is
  /// only for sign-in and retry.
  Future<void> refreshAll() async {
    if (_status != SessionStatus.ready) return;
    final token = _loadToken;
    try {
      // Independent reads: side by side, not one after another.
      final (profile, classes, year) = await (
        _auth.currentProfile(),
        _classes.overview(),
        _attendance.currentYear(),
      ).wait;
      if (token != _loadToken || _status != SessionStatus.ready) return;
      if (profile == null) {
        _profile = profile;
        _status = SessionStatus.notFound;
      } else if (profile.isRejected) {
        _profile = profile;
        _status = SessionStatus.rejected;
      } else if (!profile.isActive) {
        _profile = profile;
        _status = SessionStatus.inactive;
      } else {
        _profile = profile;
        _myClasses = classes;
        _currentYear = year;
      }
      if (_status != SessionStatus.ready) {
        _myClasses = const <ClassOverview>[];
        _currentYear = null;
        unawaited(_quietly(_cleanup.wipe));
      }
      notifyListeners();
    } catch (_) {
      // Keep the current data; a transient failure must not sign anyone out.
    }
  }

  /// Re-reads the class list after an admin adds a class or an assignment
  /// changes, without flipping the whole app back to a loading state.
  Future<void> refreshClasses() async {
    if (_status != SessionStatus.ready) return;
    try {
      _myClasses = await _classes.overview();
      notifyListeners();
    } catch (_) {
      // A refresh failure is not worth tearing down the session for.
    }
  }

  Future<void> signIn({required String email, required String password}) =>
      _auth.signIn(email: email, password: password);

  /// True when the new account is already signed in; false when the email has
  /// to be confirmed first.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required AppRole role,
    Gender? gender,
    String? mobile,
    DateTime? birthDate,
    String? address,
    String? confessor,
    String? occupation,
  }) =>
      _auth.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        gender: gender,
        mobile: mobile,
        birthDate: birthDate,
        address: address,
        confessor: confessor,
        occupation: occupation,
      );

  Future<void> signOut() async {
    // While the session can still delete it: this device stops getting this
    // person's pushes.
    await _quietly(() => _cleanup.forgetPush(server: true));
    // The next person to sign in must not see this count, nor be told who the
    // previous servant's families are.
    await _quietly(_cleanup.hideNames);
    try {
      await _auth.signOut();
    } finally {
      // The sign-out failed and they are still in: keep their pushes coming.
      if (_auth.currentSession != null) {
        unawaited(_quietly(_cleanup.registerPush));
      }
    }
  }

  /// Cleaning up is never a reason to fail what the person is doing.
  static Future<void> _quietly(Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      debugPrint('session cleanup skipped: $e');
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  Future<void> updatePassword(String newPassword) =>
      _auth.updatePassword(newPassword);

  void _fail(Object error) {
    _errorMessage = AppFailure.from(error).message;
    _status = SessionStatus.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    PushService.instance.received.removeListener(_onPush);
    super.dispose();
  }
}
