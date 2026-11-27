import '../../core/utils/app_failure.dart';
import '../../core/utils/message_template.dart';
import '../supabase/db.dart';

/// The service's own message templates. Everyone reads them; only the admin
/// writes (the table's policies enforce it).
class MessageTemplateRepository {
  const MessageTemplateRepository();

  Future<List<MessageTemplate>> list() async {
    try {
      final data = await Db.from(Db.tMessageTemplates)
          .select()
          .order('sort_order')
          .order('created_at');
      return rows(data).map(MessageTemplate.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Adds a template, or changes it when [id] is given.
  Future<void> save({String? id, required String title, required String body}) async {
    final values = <String, dynamic>{'title': title.trim(), 'body': body.trim()};
    try {
      if (id == null) {
        await Db.from(Db.tMessageTemplates).insert(values);
      } else {
        await Db.from(Db.tMessageTemplates).update(values).eq('id', id);
      }
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await Db.from(Db.tMessageTemplates).delete().eq('id', id);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
