import '../../core/utils/app_failure.dart';
import '../models/app_notification.dart';
import '../supabase/db.dart';

/// The signed-in user's notifications. Rows are created by database triggers;
/// the app only reads them and marks them read (RLS limits it to the owner).
class NotificationRepository {
  const NotificationRepository();

  static const _table = 'notifications';

  Future<List<AppNotification>> latest({int limit = 100}) async {
    try {
      final data = await Db.client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return rows(data).map(AppNotification.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<int> unreadCount() async {
    try {
      final data = await Db.client.from(_table).select('id').isFilter('read_at', null);
      return rows(data).length;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await Db.client
          .from(_table)
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .isFilter('read_at', null);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await Db.client
          .from(_table)
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .isFilter('read_at', null);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
