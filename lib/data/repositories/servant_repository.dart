import '../../core/utils/app_failure.dart';
import '../models/profile.dart';
import '../services/email_service.dart';
import '../supabase/db.dart';

const _email = EmailService();

/// Servant accounts and invites.
///
/// A mobile client cannot create auth users, so "add servant" records an invite
/// that the database applies when that email signs up. Everything here is
/// admin-only at the policy level.
class ServantRepository {
  const ServantRepository();

  Future<List<Profile>> servants({bool includeInactive = true}) async {
    try {
      final query = Db.client.from(Db.tProfiles).select();
      final data = includeInactive
          ? await query.order('full_name')
          : await query.eq('is_active', true).order('full_name');
      return rows(data).map(Profile.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ServantInvite>> pendingInvites() async {
    try {
      final data = await Db.client
          .from(Db.tServantInvites)
          .select()
          .isFilter('accepted_at', null)
          .order('created_at', ascending: false);
      return rows(data).map(ServantInvite.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> createInvite({
    required String email,
    required String fullName,
    required AppRole role,
    String? mobile,
    DateTime? birthDate,
    String? address,
    String? confessor,
    String? occupation,
    List<String> classIds = const <String>[],
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedName = fullName.trim();
    try {
      await Db.client.from(Db.tServantInvites).insert(<String, dynamic>{
        'email': trimmedEmail,
        'full_name': trimmedName,
        'role': role.wire,
        'mobile': _blankToNull(mobile),
        if (birthDate != null)
          'birth_date': birthDate.toIso8601String().substring(0, 10),
        'address': _blankToNull(address),
        'confessor': _blankToNull(confessor),
        'occupation': _blankToNull(occupation),
        'class_ids': classIds,
        'created_by': Db.userId,
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
    // Fire-and-forget: invite recorded; now notify the servant.
    _email
        .sendServantInvite(email: trimmedEmail, name: trimmedName)
        .ignore();
  }

  Future<void> deleteInvite(String inviteId) async {
    try {
      await Db.client.from(Db.tServantInvites).delete().eq('id', inviteId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> updateServant({
    required String servantId,
    required String fullName,
    String? mobile,
    AppRole? role,
  }) async {
    try {
      await Db.client.from(Db.tProfiles).update(<String, dynamic>{
        'full_name': fullName.trim(),
        'mobile': _blankToNull(mobile),
        if (role != null) 'role': role.wire,
      }).eq('id', servantId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The admin-only data of every servant, keyed by profile id.
  Future<Map<String, ServantDetails>> details() async {
    try {
      final data = await Db.client.from(Db.tServantDetails).select();
      return <String, ServantDetails>{
        for (final d in rows(data).map(ServantDetails.fromMap)) d.profileId: d,
      };
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Saves what the secretary typed for one servant: the contact fields on the
  /// profile and the private fields in `servant_details`.
  Future<void> saveDetails({
    required String servantId,
    required String fullName,
    String? mobile,
    DateTime? birthDate,
    String? address,
    String? confessor,
    String? occupation,
    AppRole? role,
  }) async {
    try {
      await Db.client.from(Db.tProfiles).update(<String, dynamic>{
        'full_name': fullName.trim(),
        if (role != null) 'role': role.wire,
        'mobile': _blankToNull(mobile),
        'birth_date': birthDate?.toIso8601String().substring(0, 10),
      }).eq('id', servantId);
      await Db.client.from(Db.tServantDetails).upsert(<String, dynamic>{
        'profile_id': servantId,
        'address': _blankToNull(address),
        'confessor': _blankToNull(confessor),
        'occupation': _blankToNull(occupation),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<PendingServant>> pendingSignups() async {
    try {
      final data = await Db.client
          .from(Db.vPendingServants)
          .select()
          .order('created_at', ascending: false);
      return rows(data).map(PendingServant.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<int> pendingSignupCount() async {
    try {
      final data = await Db.client.from(Db.vPendingServants).select('id');
      return rows(data).length;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> reviewSignup({
    required String profileId,
    required bool accept,
    String? servantEmail,
    String? servantName,
  }) async {
    try {
      await Db.client.rpc<void>(
        'review_servant_request',
        params: <String, dynamic>{
          'p_profile_id': profileId,
          'p_accept': accept,
        },
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
    // Notify the servant of the outcome when their email is known.
    if (servantEmail != null && servantName != null) {
      _email
          .sendRequestReview(
            email: servantEmail,
            name: servantName,
            accepted: accept,
          )
          .ignore();
    }
  }

  Future<void> setActive(String servantId, bool isActive) async {
    try {
      await Db.client
          .from(Db.tProfiles)
          .update(<String, dynamic>{'is_active': isActive})
          .eq('id', servantId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Active servants whose birth-date month+day matches today. Errors are
  /// silently swallowed: RLS may restrict access for non-admin roles.
  Future<List<Profile>> servantsWithBirthdayToday() async {
    try {
      final today = DateTime.now();
      final data = await Db.client
          .from(Db.tProfiles)
          .select('id, full_name, mobile, birth_date, gender')
          .not('birth_date', 'is', null)
          .eq('is_active', true);
      return rows(data)
          .map(Profile.fromMap)
          .where((p) =>
              p.birthDate != null &&
              p.birthDate!.month == today.month &&
              p.birthDate!.day == today.day)
          .toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
    } catch (_) {
      return [];
    }
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
