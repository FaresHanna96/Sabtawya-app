import '../supabase/db.dart';

/// Sends transactional emails via the `send-email` Supabase Edge Function,
/// which forwards to Resend. Errors are surfaced to callers but never block
/// the main operation — the DB write succeeds regardless.
class EmailService {
  const EmailService();

  /// Notifies an invited servant that they can register.
  Future<void> sendServantInvite({
    required String email,
    required String name,
  }) =>
      _send(type: 'invite', to: email, name: name);

  /// Notifies a servant of the admin's decision on their sign-up request.
  Future<void> sendRequestReview({
    required String email,
    required String name,
    required bool accepted,
  }) =>
      _send(
        type: accepted ? 'accepted' : 'rejected',
        to: email,
        name: name,
      );

  Future<void> _send({
    required String type,
    required String to,
    required String name,
  }) async {
    await Db.client.functions.invoke(
      'send-email',
      body: <String, String>{'type': type, 'to': to, 'name': name},
    );
  }
}
