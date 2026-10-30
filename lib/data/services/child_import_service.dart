import '../../core/l10n/app_strings.dart';
import '../models/child.dart';
import '../repositories/child_repository.dart';
import 'excel_service.dart';

/// The reviewed outcome of a parsed sheet: every row tagged insert, update, or
/// skip, ready to show in the preview before anything is written.
class ImportPlan {
  const ImportPlan({required this.rows, required this.classId, required this.mode});

  final List<ImportRow> rows;
  final String classId;
  final ImportMode mode;

  Iterable<ImportRow> get _usable => rows.where((row) => !row.hasErrors);

  List<ImportRow> get inserts =>
      _usable.where((row) => row.action == ImportAction.insert).toList();

  List<ImportRow> get updates =>
      _usable.where((row) => row.action == ImportAction.update).toList();

  int get insertCount => inserts.length;
  int get updateCount => updates.length;
  int get errorCount => rows.where((row) => row.hasErrors).length;
  int get skipCount =>
      rows.where((row) => !row.hasErrors && row.action == ImportAction.skip).length;
  int get movesCount => _usable.where((row) => row.movesClass).length;

  bool get hasWork => insertCount > 0 || updateCount > 0;
}

class ImportResult {
  const ImportResult({required this.inserted, required this.updated});

  final int inserted;
  final int updated;
}

/// Decides what an Excel import should do, then applies it.
///
/// Matching is by child code first, because that is the only globally unique
/// business key. Rows without a code fall back to an exact name match inside
/// the target class, which is how the old spreadsheets identified a child.
class ChildImportService {
  const ChildImportService({ChildRepository children = const ChildRepository()})
      : _children = children;

  final ChildRepository _children;

  Future<ImportPlan> resolve({
    required List<ImportRow> rows,
    required String classId,
    required ImportMode mode,
  }) async {
    final codes = rows
        .map((row) => row.code)
        .whereType<String>()
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList();

    final byCode = <String, Child>{
      for (final child in await _children.byCodes(codes))
        if (child.code != null) child.code!.toLowerCase(): child,
    };

    final roster = await _children.byClass(classId, includeInactive: true);
    final byName = <String, Child>{
      for (final child in roster) _normaliseName(child.fullName): child,
    };

    final seenCodes = <String>{};
    final seenNames = <String>{};

    for (final row in rows) {
      // Lets the preview switch modes without re-reading the file.
      row.resetResolution();
      if (row.parseErrors.isNotEmpty) continue;

      final code = row.code?.trim().toLowerCase();
      final name = _normaliseName(row.name);

      // Duplicates inside the uploaded file would otherwise insert twice.
      final duplicate = (code != null && code.isNotEmpty)
          ? !seenCodes.add(code)
          : !seenNames.add(name);
      if (duplicate) {
        row.importErrors.add(AppStrings.importErrorDuplicateInFile);
        continue;
      }

      final existing = (code != null && code.isNotEmpty)
          ? byCode[code]
          : byName[name];
      row.existing = existing;
      row.movesClass = existing != null && existing.classId != classId;

      switch (mode) {
        case ImportMode.addNew:
          if (existing != null) {
            row.action = ImportAction.skip;
            row.note = AppStrings.importErrorExists;
          } else {
            row.action = ImportAction.insert;
          }
        case ImportMode.updateExisting:
          if (existing == null) {
            row.action = ImportAction.skip;
            row.note = AppStrings.importErrorNotFound;
          } else {
            row.action = ImportAction.update;
          }
        case ImportMode.addAndUpdate:
          row.action =
              existing == null ? ImportAction.insert : ImportAction.update;
      }

      // A new child must have a gender; an update can inherit the stored one.
      if (row.action == ImportAction.insert && row.gender == null) {
        row.importErrors.add(AppStrings.importErrorGenderMissing);
        row.action = ImportAction.skip;
      }
    }

    return ImportPlan(rows: rows, classId: classId, mode: mode);
  }

  Future<ImportResult> apply(ImportPlan plan) async {
    final inserts = plan.inserts
        .map((row) => row.toNewChild(plan.classId))
        .toList();

    final updates = plan.updates
        .map((row) => row.applyTo(row.existing!, plan.classId))
        .toList();

    await _children.insertMany(inserts);
    await _children.updateMany(updates);

    return ImportResult(inserted: inserts.length, updated: updates.length);
  }

  static String _normaliseName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
