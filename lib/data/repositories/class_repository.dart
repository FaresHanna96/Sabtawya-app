import '../../core/utils/app_failure.dart';
import '../models/profile.dart';
import '../models/school_class.dart';
import '../supabase/db.dart';

/// Classes and servant assignments.
///
/// Reads never filter by the signed-in servant: row level security already
/// restricts every query to the classes they are assigned to, so the same code
/// serves both roles.
class ClassRepository {
  const ClassRepository();

  Future<List<ClassOverview>> overview({bool includeInactive = false}) async {
    try {
      final query = Db.from(Db.vClassOverview).select();
      final data = includeInactive
          ? await query.order('sort_order')
          : await query.eq('is_active', true).order('sort_order');
      return rows(data).map(ClassOverview.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<ClassOverview?> overviewById(String classId) async {
    try {
      final data = await Db.from(Db.vClassOverview)
          .select()
          .eq('class_id', classId)
          .maybeSingle();
      return data == null ? null : ClassOverview.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<SchoolClass>> list({bool includeInactive = false}) async {
    try {
      final query = Db.from(Db.tClasses).select();
      final data = includeInactive
          ? await query.order('sort_order')
          : await query.eq('is_active', true).order('sort_order');
      return rows(data).map(SchoolClass.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Returns the id of the new class, so a patron picture can be attached to it.
  Future<String> create({
    required String name,
    String? description,
    String? patronName,
    int? sortOrder,
  }) async {
    try {
      final data = await Db.from(Db.tClasses)
          .insert(<String, dynamic>{
            'name': name.trim(),
            'description': _blankToNull(description),
            'patron_name': _blankToNull(patronName),
            if (sortOrder != null) 'sort_order': sortOrder,
          })
          .select('id')
          .single();
      return data['id'].toString();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// What the new-year promotion would do, without changing anything: a class
  /// moves up as a whole (children, servants, patron and picture go with it),
  /// the 6 classes are archived with their children, and fresh 3 classes are
  /// added. Fails when this year's promotion has already been done.
  Future<PromotionPlan> previewPromotion({required String archiveSuffix}) =>
      _promote(archiveSuffix, dryRun: true);

  /// Does the promotion in one transaction: all of it, or (on any failure) none.
  Future<PromotionPlan> promoteGrades({required String archiveSuffix}) =>
      _promote(archiveSuffix, dryRun: false);

  Future<PromotionPlan> _promote(String archiveSuffix,
      {required bool dryRun}) async {
    try {
      final result = await Db.client.rpc<dynamic>(
        'promote_grades',
        params: <String, dynamic>{
          'p_archive_suffix': archiveSuffix.trim(),
          'p_dry_run': dryRun,
        },
      );
      return PromotionPlan.fromMap((result as Map).cast<String, dynamic>());
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// `patron_photo_path` is left out on purpose: it is written only by
  /// [setPatronPhoto], so editing a class can never blank out its picture.
  Future<void> update({
    required String classId,
    required String name,
    String? description,
    String? patronName,
    int? sortOrder,
  }) async {
    try {
      await Db.from(Db.tClasses).update(<String, dynamic>{
        'name': name.trim(),
        'description': _blankToNull(description),
        'patron_name': _blankToNull(patronName),
        if (sortOrder != null) 'sort_order': sortOrder,
      }).eq('id', classId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> setPatronPhoto({
    required String classId,
    required String? path,
  }) async {
    try {
      await Db.from(Db.tClasses).update(
          <String, dynamic>{'patron_photo_path': path}).eq('id', classId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Permanently deletes a class.
  ///
  /// `children.class_id` is `on delete restrict`, so the database refuses this
  /// while any child still points at the class, archived ones included. Servant
  /// assignments and the Saturday calendar cascade away with it.
  Future<void> delete(String classId) async {
    try {
      await Db.from(Db.tClasses).delete().eq('id', classId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> setActive(String classId, bool isActive) async {
    try {
      await Db.from(Db.tClasses)
          .update(<String, dynamic>{'is_active': isActive}).eq('id', classId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // --------------------------------------------------------------- assignments

  Future<List<ClassServant>> servantsOfClass(String classId) async {
    try {
      final data = await Db.from(Db.vClassServants)
          .select()
          .eq('class_id', classId)
          .order('servant_name');
      return rows(data).map(ClassServant.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ClassServant>> allAssignments() async {
    try {
      final data = await Db.from(Db.vClassServants)
          .select()
          .order('class_name')
          .order('servant_name');
      return rows(data).map(ClassServant.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<ClassServant>> classesOfServant(String servantId) async {
    try {
      final data = await Db.from(Db.vClassServants)
          .select()
          .eq('servant_id', servantId)
          .order('class_name');
      return rows(data).map(ClassServant.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Assigns a servant to a class, removing any prior assignment first.
  /// A servant belongs to exactly one class; this enforces that constraint.
  Future<void> assignServant({
    required String classId,
    required String servantId,
  }) async {
    try {
      // Remove any existing assignment so the servant stays in only one class.
      await Db.from(Db.tClassServants)
          .delete()
          .eq('servant_id', servantId);
      await Db.from(Db.tClassServants).insert(<String, dynamic>{
        'class_id': classId,
        'servant_id': servantId,
        'assigned_by': Db.userId,
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> removeAssignment(String assignmentId) async {
    try {
      await Db.from(Db.tClassServants).delete().eq('id', assignmentId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
