import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/utils/app_failure.dart';
import '../../core/utils/shared_requests.dart';
import '../../core/utils/visit_merge.dart';
import '../models/child.dart';
import '../models/import_batch.dart';
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
  }) {
    // The home's birthdays and missing-info cards (and the Children tab) ask
    // for the same list at the same moment: one download serves them all.
    return _shared
        .run(
          '$includeInactive|${classId ?? ''}',
          () => _fetchAll(includeInactive: includeInactive, classId: classId),
        )
        // Each caller gets its own list, so sorting one does not reorder
        // another.
        .then(List<Child>.of);
  }

  static final _shared = SharedRequests<List<Child>>();

  Future<List<Child>> _fetchAll({
    required bool includeInactive,
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

  /// Registered children (in any class) that look like the ones in
  /// [queries]: the same name, or the same first name with the same father's
  /// name or a shared phone. Keyed by [SimilarQuery.key]; children with no
  /// look-alike are absent from the map.
  Future<Map<String, List<SimilarChild>>> similar(
    List<SimilarQuery> queries,
  ) async {
    if (queries.isEmpty) return const <String, List<SimilarChild>>{};
    try {
      final data = await Db.client.rpc(
        'similar_children',
        params: {
          'p_candidates': [for (final q in queries) q.toJson()],
        },
      );
      final out = <String, List<SimilarChild>>{};
      for (final row in rows(data).map(SimilarChild.fromMap)) {
        (out[row.key] ??= <SimilarChild>[]).add(row);
      }
      return out;
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
          .update(<String, dynamic>{'is_active': isActive}).eq('id', childId);
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
          .update(<String, dynamic>{'class_id': newClassId}).eq('id', childId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Saves (or clears, with null) where the child lives, nothing else.
  Future<void> setLocation({
    required String childId,
    required double? latitude,
    required double? longitude,
  }) async {
    try {
      await Db.client.from(Db.tChildren).update(<String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      }).eq('id', childId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Points the child at a photo in storage, or clears it with null.
  ///
  /// Kept out of [Child.toWriteMap] so an ordinary edit or an Excel import
  /// cannot drop a photo it never knew about.
  Future<void> setPhoto(
      {required String childId, required String? path}) async {
    try {
      await Db.client
          .from(Db.tChildren)
          .update(<String, dynamic>{'photo_path': path}).eq('id', childId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Existing children carrying any of [codes], used to decide insert vs update
  /// during an Excel import. Codes are unique across the whole system.
  /// The children with these ids that the caller may see, in no set order.
  Future<List<Child>> byIds(List<String> ids) async {
    if (ids.isEmpty) return <Child>[];
    try {
      final data =
          await Db.client.from(Db.tChildren).select().inFilter('id', ids);
      return rows(data).map(Child.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

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

  /// The columns an Excel sheet carries, for the `import_children` function.
  /// Left out on purpose: the code (issued by the database), is_active, the
  /// deacon flag, the visit dates and the photo, so an import never blanks them.
  @visibleForTesting
  static Map<String, dynamic> importRow(Child child, {bool withId = false}) {
    final map = child.toWriteMap();
    return <String, dynamic>{
      if (withId) 'id': child.id,
      for (final key in _importColumns) key: map[key],
    };
  }

  static const _importColumns = <String>[
    'class_id',
    'full_name',
    'gender',
    'birth_date',
    'mobile',
    'mother_name',
    'mother_mobile',
    'father_name',
    'father_mobile',
    'confession_father',
    'school',
    'address',
    'notes',
  ];

  /// Adds [inserts] and changes [updates] in one transaction: all of it is
  /// saved, or (when anything fails) none of it. Needs a connection; it is
  /// never queued for later.
  Future<({int inserted, int updated})> importMany({
    required List<Child> inserts,
    required List<Child> updates,
  }) async {
    if (inserts.isEmpty && updates.isEmpty) return (inserted: 0, updated: 0);
    try {
      final result = await Db.client.rpc<dynamic>(
        'import_children',
        params: <String, dynamic>{
          'p_inserts': [for (final c in inserts) importRow(c)],
          'p_updates': [for (final c in updates) importRow(c, withId: true)],
        },
      );
      final map = result is Map ? result : const <String, dynamic>{};
      return (
        inserted: (map['inserted'] as num?)?.toInt() ?? 0,
        updated: (map['updated'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Puts back what one edit changed (needs the network). The database
  /// refuses when the same fields were changed again afterwards.
  Future<void> revertChange(int logId) async {
    try {
      await Db.client.rpc('revert_child_change', params: {'p_log_id': logId});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The Excel imports the caller can still undo (their own; all for admins).
  Future<List<ImportBatch>> recentImports() async {
    try {
      final data = await Db.client.rpc('recent_import_batches');
      return rows(data).map(ImportBatch.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Removes the children an import added and restores the ones it changed.
  Future<({int deleted, int restored})> undoImport(String batchId) async {
    try {
      final result =
          await Db.client.rpc('undo_import', params: {'p_batch': batchId});
      final map = result is Map ? result : const <String, dynamic>{};
      return (
        deleted: (map['deleted'] as num?)?.toInt() ?? 0,
        restored: (map['restored'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// The private health note of a child, or null when there is none (or the
  /// caller may not see it: the database returns no row then).
  Future<String?> healthNote(String childId) async {
    try {
      final data = await Db.client
          .from(Db.tChildPrivateNotes)
          .select('health_notes')
          .eq('child_id', childId)
          .maybeSingle();
      final text = data?['health_notes']?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Saves the private health note; an empty text removes it.
  Future<void> saveHealthNote(String childId, String? text) async {
    final value = text?.trim() ?? '';
    try {
      if (value.isEmpty) {
        await Db.client
            .from(Db.tChildPrivateNotes)
            .delete()
            .eq('child_id', childId);
        return;
      }
      await Db.client.from(Db.tChildPrivateNotes).upsert(
        <String, dynamic>{'child_id': childId, 'health_notes': value},
        onConflict: 'child_id',
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ChildVisitLog>> visitLogs(String childId) async {
    try {
      final data = await Db.client
          .from(Db.tChildVisitLogs)
          .select(
              '*, recorder:profiles!child_visit_logs_recorded_by_fkey(full_name)')
          .eq('child_id', childId)
          .order('visit_date', ascending: false)
          .order('created_at', ascending: false);
      return rows(data).map(ChildVisitLog.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Who added, edited or recorded attendance for this child. Needs the
  /// network (a database function, so it is not kept for offline); callers
  /// treat a failure as "nothing to show".
  Future<List<ChildChange>> changeHistory(String childId) async {
    try {
      final data = await Db.client
          .rpc('child_change_history', params: {'p_child_id': childId});
      return rows(data).map(ChildChange.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Removes one history entry. A servant may only remove entries they wrote
  /// (admins any); the database silently skips the rest, so an empty result
  /// is reported instead of pretending it worked.
  Future<void> deleteVisitLog(String id) async {
    try {
      final deleted = await Db.client
          .from(Db.tChildVisitLogs)
          .delete()
          .eq('id', id)
          .select('id');
      if (rows(deleted).isEmpty) {
        throw AppFailure('ما ينفعش تحذف الافتقاد ده (سجّله خادم تاني)');
      }
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Writes one follow-up to the history: the caller's own entry for the same
  /// child, type and day is updated (a corrected note), otherwise a new entry
  /// is added. Keeps the history to one row per servant, child, type and day.
  Future<void> recordVisitLog({
    required String childId,
    required String visitType,
    required DateTime visitDate,
    String? notes,
  }) async {
    final d = visitDate;
    final iso = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    List<ChildVisitLog> mine = const [];
    try {
      final data = await Db.client
          .from(Db.tChildVisitLogs)
          .select()
          .eq('child_id', childId)
          .eq('visit_type', visitType)
          .eq('visit_date', iso)
          .eq('recorded_by', Db.userId ?? '');
      mine = rows(data).map(ChildVisitLog.fromMap).toList();
    } catch (_) {
      // Offline with nothing cached: fall back to adding an entry.
    }
    final existing = VisitMerge.existingEntry(
      logs: mine,
      childId: childId,
      visitType: visitType,
      date: visitDate,
      myId: Db.userId,
    );
    if (existing == null) {
      await insertVisitLog(
        childId: childId,
        visitType: visitType,
        visitDate: visitDate,
        notes: notes,
      );
      return;
    }
    try {
      await Db.client
          .from(Db.tChildVisitLogs)
          .update(<String, dynamic>{'notes': notes}).eq('id', existing);
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
        'visit_date': '${d.year.toString().padLeft(4, '0')}-'
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
