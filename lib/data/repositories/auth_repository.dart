import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Creates an account for a servant.
  ///
  /// The name and mobile travel as user metadata, which `handle_new_user()`
  /// copies into the profile. The role is never sent: the trigger decides it,
  /// and an account with no matching invite stays inactive until an admin
  /// activates it.
  ///
  /// Returns true when the session is live straight away, and false when the
  /// project requires the email to be confirmed first.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required Gender gender,
    String? mobile,
  }) async {
    try {
      final response = await Db.client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: 'sabtawya://login-callback',
        data: <String, dynamic>{
          'full_name': fullName.trim(),
          'gender': gender.wire,
          if (mobile != null && mobile.trim().isNotEmpty)
            'mobile': mobile.trim(),
        },
      );
      return response.session != null;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> signOut() async {
    try {
      await Db.client.auth.signOut();
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
  }) async {
    final userId = Db.userId;
    if (userId == null) return;

    try {
      await Db.client.from(Db.tProfiles).update(<String, dynamic>{
        'full_name': fullName.trim(),
        'mobile': mobile?.trim().isEmpty ?? true ? null : mobile!.trim(),
      }).eq('id', userId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
