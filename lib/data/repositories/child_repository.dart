import '../../core/utils/app_failure.dart';
import '../models/child.dart';
import '../supabase/db.dart';

class ChildRepository {
  const ChildRepository();

  Future<List<Child>> byClass(
    String classId, {
    bool includeInactive = false,
  }) async {
    try {
      var query = Db.client.from(Db.tChildren).select().eq('class_id', classId);
      if (!includeInactive) query = query.eq('is_active', true);
      final data = await query.order('full_name');
      return rows(data).map(Child.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Every child the caller may see. A servant receives only the children of
  /// their assigned classes because of the `children_select` policy.
  Future<List<Child>> all({
    bool includeInactive = false,
    String? classId,
  }) async {
    try {
      var query = Db.client.from(Db.tChildren).select();
      if (classId != null) query = query.eq('class_id', classId);
      if (!includeInactive) query = query.eq('is_active', true);
      final data = await query.order('full_name');
      return rows(data).map(Child.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Child?> byId(String childId) async {
    try {
      final data = await Db.client
          .from(Db.tChildren)
          .select()
          .eq('id', childId)
          .maybeSingle();
      return data == null ? null : Child.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Child> create(Child child) async {
    try {
      final data = await Db.client
          .from(Db.tChildren)
          .insert(child.toWriteMap())
          .select()
          .single();
      return Child.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Child> update(Child child) async {
    try {
      final data = await Db.client
          .from(Db.tChildren)
          .update(child.toWriteMap())
          .eq('id', child.id)
          .select()
          .single();
      return Child.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Deactivation is preferred over deletion: the child leaves active lists and
  /// future attendance sheets while every past record is kept.
  Future<void> setActive(String childId, bool isActive) async {
    try {
      await Db.client
          .from(Db.tChildren)
          .update(<String, dynamic>{'is_active': isActive})
          .eq('id', childId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Historical attendance stays attached to the child, so a move only changes
  /// which class they appear under from now on.
  Future<void> moveToClass({
    required String childId,
    required String newClassId,
  }) async {
    try {
      await Db.client
          .from(Db.tChildren)
          .update(<String, dynamic>{'class_id': newClassId})
          .eq('id', childId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Points the child at a photo in storage, or clears it with null.
  ///
  /// Kept out of [Child.toWriteMap] so an ordinary edit or an Excel import
  /// cannot drop a photo it never knew about.
  Future<void> setPhoto({required String childId, required String? path}) async {
    try {
      await Db.client
          .from(Db.tChildren)
          .update(<String, dynamic>{'photo_path': path})
          .eq('id', childId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Existing children carrying any of [codes], used to decide insert vs update
  /// during an Excel import. Codes are unique across the whole system.
  Future<List<Child>> byCodes(List<String> codes) async {
    if (codes.isEmpty) return <Child>[];
    try {
      final data =
          await Db.client.from(Db.tChildren).select().inFilter('code', codes);
      return rows(data).map(Child.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> insertMany(List<Child> children) async {
    if (children.isEmpty) return;
    try {
      await Db.client
          .from(Db.tChildren)
          .insert(children.map((child) => child.toWriteMap()).toList());
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> updateMany(List<Child> children) async {
    // Each row carries its own id, so they are applied one by one rather than
    // through a single upsert that could silently insert a duplicate.
    for (final child in children) {
      await update(child);
    }
  }

  Future<List<ChildVisitLog>> visitLogs(String childId) async {
    try {
      final data = await Db.client
          .from(Db.tChildVisitLogs)
          .select()
          .eq('child_id', childId)
          .order('visit_date', ascending: false)
          .order('created_at', ascending: false);
      return rows(data).map(ChildVisitLog.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> insertVisitLog({
    required String childId,
    required String visitType,
    required DateTime visitDate,
    String? notes,
  }) async {
    try {
      final d = visitDate;
      await Db.client.from(Db.tChildVisitLogs).insert(<String, dynamic>{
        'child_id': childId,
        'visit_type': visitType,
        'visit_date':
            '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
        'notes': notes,
        'recorded_by': Db.userId,
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
