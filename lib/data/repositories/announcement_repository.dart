import '../../core/utils/app_failure.dart';
import '../models/announcement.dart';
import '../supabase/db.dart';

/// أمين الخدمة's announcements to the servants. Sending goes through
/// `send_announcement`, which writes one bell entry (and push) per recipient;
/// the read counts come from admin-only functions, since each person can read
/// only their own notifications.
class AnnouncementRepository {
  const AnnouncementRepository();

  Future<List<Announcement>> sent() async {
    try {
      final data = await Db.client.rpc('announcements_summary');
      return rows(data).map(Announcement.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Sends it and returns how many people it went to.
  Future<int> send({
    required String title,
    required String body,
    required AnnouncementAudience audience,
    List<String> classIds = const <String>[],
  }) async {
    try {
      final result = await Db.client.rpc('send_announcement', params: {
        'p_title': title.trim(),
        'p_body': body.trim(),
        'p_audience': audience.value,
        'p_class_ids':
            audience == AnnouncementAudience.classes ? classIds : <String>[],
      });
      final map = result is Map ? result : const <String, dynamic>{};
      return (map['recipients'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Everyone who got [announcementId], those who have not read it first.
  Future<List<AnnouncementRead>> reads(String announcementId) async {
    try {
      final data = await Db.client
          .rpc('announcement_reads', params: {'p_id': announcementId});
      return rows(data).map(AnnouncementRead.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Takes it back: also removed from every recipient's bell.
  Future<void> delete(String announcementId) async {
    try {
      await Db.client
          .from(Db.tAnnouncements)
          .delete()
          .eq('id', announcementId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
