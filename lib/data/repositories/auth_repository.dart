import '../../core/services/offline_store.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/app_failure.dart';
import '../models/child.dart';
import '../models/profile.dart';
import '../supabase/db.dart';

class AuthRepository {
  const AuthRepository();

  Stream<AuthState> get authChanges => Db.client.auth.onAuthStateChange;

  Session? get currentSession => Db.client.auth.currentSession;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await Db.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Creates an account for a servant or general_servant.
  ///
  /// The name, mobile, and requested_role travel as user metadata.
  /// `handle_new_user()` copies them into the profile. Only 'servant' and
  /// 'general_servant' are accepted from metadata; 'admin' is ignored.
  /// An account with no matching invite stays inactive until an admin activates it.
  ///
  /// Returns true when the session is live straight away, and false when the
  /// project requires the email to be confirmed first.
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
  }) async {
    try {
      // One account per person: refuse a name that is already registered
      // (compared the way the app sorts names, so ى/ي, ة/ه, أ/ا and extra
      // spaces do not make it "different").
      if (await _nameTaken(fullName)) {
        throw AppFailure(AppStrings.nameAlreadyUsed);
      }
      // No throwaway inboxes, misspelled or made-up domains.
      await _checkEmail(email);

      final response = await Db.client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: kIsWeb
            ? 'https://sabtawya.vercel.app'
            : 'sabtawya://login-callback',
        data: <String, dynamic>{
          'full_name': fullName.trim(),
          'requested_role': role.wire,
          if (gender != null) 'gender': gender.wire,
          if (mobile != null && mobile.trim().isNotEmpty)
            'mobile': mobile.trim(),
          if (address != null && address.trim().isNotEmpty)
            'address': address.trim(),
          if (confessor != null && confessor.trim().isNotEmpty)
            'confessor': confessor.trim(),
          if (occupation != null && occupation.trim().isNotEmpty)
            'occupation': occupation.trim(),
          if (birthDate != null)
            'birth_date': '${birthDate.year.toString().padLeft(4, '0')}-'
                '${birthDate.month.toString().padLeft(2, '0')}-'
                '${birthDate.day.toString().padLeft(2, '0')}',
        },
      );
      // With email confirmation on, Supabase does not say an email is taken
      // (so outsiders cannot probe for accounts): it answers with a stand-in
      // user that has no sign-in identities. Report it as the taken email it
      // is, instead of "check your email" for a mail that never comes.
      if (isExistingAccountReply(response.user)) {
        throw AppFailure(AppStrings.emailAlreadyUsed);
      }
      return response.session != null;
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// True for Supabase's stand-in reply to a sign-up with a registered email.
  @visibleForTesting
  static bool isExistingAccountReply(User? user) =>
      user != null && user.identities != null && user.identities!.isEmpty;

  /// Refuses an email the database's rules or the mail-server lookup reject,
  /// with a message saying why (and the likely intended address for a typo).
  /// The database also enforces its rules itself at sign-up; this only makes
  /// the reason visible. Either check missing (dev project) lets it pass.
  Future<void> _checkEmail(String email) async {
    final trimmed = email.trim();
    try {
      final result = await Db.client.rpc<dynamic>(
        'check_signup_email',
        params: <String, dynamic>{'p_email': trimmed},
      );
      final verdict = emailVerdict(result);
      if (verdict != null) throw AppFailure(verdict);
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow; // function not there yet
    }

    try {
      final resp = await Db.client.functions.invoke(
        'send-email',
        body: <String, dynamic>{'type': 'check_domain', 'email': trimmed},
      );
      final data = resp.data;
      if (data is Map && data['receivesMail'] == false) {
        throw AppFailure(
            AppStrings.emailDomainNoMail(data['domain'] as String));
      }
    } on AppFailure {
      rethrow;
    } catch (_) {
      // The lookup is a courtesy: never block a sign-up because it failed.
    }
  }

  /// The message for a refused email, from check_signup_email's answer, or
  /// null when it is accepted.
  @visibleForTesting
  static String? emailVerdict(Object? result) {
    if (result is! Map || result['ok'] == true) return null;
    return switch (result['reason']) {
      'disposable' => AppStrings.emailDisposable,
      'typo' => AppStrings.emailTypo(result['suggestion'] as String?),
      _ => AppStrings.invalidEmail,
    };
  }

  /// Asks the database whether an account already has this name. A database
  /// without the check (the dev project before its migration) lets it pass.
  Future<bool> _nameTaken(String fullName) async {
    try {
      final taken = await Db.client.rpc<dynamic>(
        'servant_name_taken',
        params: <String, dynamic>{'p_name': fullName.trim()},
      );
      return taken == true;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') return false; // function not there yet
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Db.client.auth.signOut();
      // The next person on this device must not see this one's data.
      await OfflineStore.clearCache();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await Db.client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    try {
      final resp = await Db.client.functions.invoke(
        'send-email',
        body: <String, dynamic>{'type': 'check_email', 'email': trimmed},
      );
      final exists = (resp.data as Map<String, dynamic>?)?['exists'] == true;
      if (!exists) {
        throw AppFailure('لم يتم العثور على حساب بهذا البريد الإلكتروني');
      }
      await Db.client.auth.resetPasswordForEmail(
        trimmed,
        redirectTo: kIsWeb
            ? 'https://sabtawya.vercel.app'
            : 'sabtawya://login-callback',
      );
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The signed-in user's profile, or null when the row has not been created.
  Future<Profile?> currentProfile() async {
    final userId = Db.userId;
    if (userId == null) return null;

    try {
      final data = await Db.client
          .from(Db.tProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data == null ? null : Profile.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> updateMyProfile({
    required String fullName,
    String? mobile,
    DateTime? birthDate,
  }) async {
    final userId = Db.userId;
    if (userId == null) return;

    final d = birthDate;
    try {
      await Db.client.from(Db.tProfiles).update(<String, dynamic>{
        'full_name': fullName.trim(),
        'mobile': mobile?.trim().isEmpty ?? true ? null : mobile!.trim(),
        'birth_date': d == null
            ? null
            : '${d.year.toString().padLeft(4, '0')}-'
                '${d.month.toString().padLeft(2, '0')}-'
                '${d.day.toString().padLeft(2, '0')}',
      }).eq('id', userId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
