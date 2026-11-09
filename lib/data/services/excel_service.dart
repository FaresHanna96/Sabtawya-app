import 'package:excel/excel.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../models/attendance.dart';
import '../models/child.dart';
import '../models/competition.dart';
import '../models/reports.dart';
import '../models/servant_activity.dart';

/// What the importer decided to do with one spreadsheet row.
enum ImportAction { insert, update, skip }

enum ImportMode {
  addNew(AppStrings.importModeAdd),
  updateExisting(AppStrings.importModeUpdate),
  addAndUpdate(AppStrings.importModeAddUpdate);

  const ImportMode(this.label);

  final String label;
}

/// One parsed spreadsheet row, plus the validation verdict attached later by
/// [ChildImportService].
class ImportRow {
  ImportRow({
    required this.rowNumber,
    required this.name,
    this.gender,
    this.birthDate,
    this.code,
    this.mobile,
    this.motherName,
    this.motherMobile,
    this.fatherName,
    this.fatherMobile,
    this.confessionFather,
    this.school,
    this.address,
    this.notes,
  });

  final int rowNumber;
  final String name;
  final Gender? gender;
  final DateTime? birthDate;
  final String? code;
  final String? mobile;
  final String? motherName;
  final String? motherMobile;
  final String? fatherName;
  final String? fatherMobile;
  final String? confessionFather;
  final String? school;
  final String? address;
  final String? notes;

  /// Problems found while reading the cell, e.g. a missing name.
  final List<String> parseErrors = <String>[];

  /// Problems found while matching the row against the database. Kept apart
  /// from [parseErrors] so changing the import mode can re-decide the row
  /// without losing or duplicating the parse verdict.
  final List<String> importErrors = <String>[];

  /// Why a valid row is being skipped, e.g. the child already exists and the
  /// chosen mode only adds new ones. Not an error.
  String? note;

  ImportAction action = ImportAction.skip;

  /// The matched existing child, when the row is an update.
  Child? existing;

  /// True when the matched child currently sits in a different class and the
  /// import will move them into the selected one.
  bool movesClass = false;

  /// Everything to show against the row in the preview.
  List<String> get errors => <String>[...parseErrors, ...importErrors];

  bool get hasErrors => parseErrors.isNotEmpty || importErrors.isNotEmpty;

  /// Drops the matching verdict so the row can be resolved again under a
  /// different [ImportMode].
  void resetResolution() {
    importErrors.clear();
    note = null;
    existing = null;
    movesClass = false;
    action = ImportAction.skip;
  }

  /// Builds the row to insert. Only called once the row has a gender.
  Child toNewChild(String classId) => Child(
        id: '',
        classId: classId,
        fullName: name,
        gender: gender ?? Gender.boy,
        isActive: true,
        birthDate: birthDate,
        code: code,
        mobile: mobile,
        motherName: motherName,
        motherMobile: motherMobile,
        fatherName: fatherName,
        fatherMobile: fatherMobile,
        confessionFather: confessionFather,
        school: school,
        address: address,
        notes: notes,
      );

  /// Merges this row onto an existing child.
  ///
  /// A blank cell leaves the stored value alone, so a partial sheet can be used
  /// to top up a few columns without wiping the rest.
  Child applyTo(Child current, String classId) => Child(
        id: current.id,
        classId: classId,
        fullName: name.isEmpty ? current.fullName : name,
        gender: gender ?? current.gender,
        isActive: current.isActive,
        birthDate: birthDate ?? current.birthDate,
        code: code ?? current.code,
        mobile: mobile ?? current.mobile,
        motherName: motherName ?? current.motherName,
        motherMobile: motherMobile ?? current.motherMobile,
        fatherName: fatherName ?? current.fatherName,
        fatherMobile: fatherMobile ?? current.fatherMobile,
        confessionFather: confessionFather ?? current.confessionFather,
        isDeacon: current.isDeacon,
        school: school ?? current.school,
        address: address ?? current.address,
        notes: notes ?? current.notes,
      );
}

class ExcelParseResult {
  const ExcelParseResult({this.rows = const <ImportRow>[], this.error});

  final List<ImportRow> rows;
  final String? error;

  bool get isFailure => error != null;
}

/// Reads and writes the `.xlsx` files used for import and export.
///
/// Excel is only a transport format here. The database stays the source of
/// truth, so nothing in this file writes a score or a derived total.
/// One child's line on the reports screen (already narrowed to the period
/// and class the user picked).
class ChildScoreRow {
  const ChildScoreRow({
    required this.className,
    required this.childName,
    required this.attended,
    required this.total,
    required this.points,
  });

  final String className;
  final String childName;
  final int attended;
  final int total;
  final int points;
}

/// One class's line on the reports screen.
class ClassScoreRow {
  const ClassScoreRow({
    required this.className,
    required this.children,
    required this.points,
    required this.maxPoints,
  });

  final String className;
  final int children;
  final int points;
  final int maxPoints;
}

class ExcelService {
  const ExcelService._();

  /// Column order of the import template and the children export.
  static const List<String> childColumns = <String>[
    AppStrings.childName,
    AppStrings.gender,
    AppStrings.birthDate,
    AppStrings.childMobile,
    AppStrings.motherName,
    AppStrings.motherMobile,
    AppStrings.fatherName,
    AppStrings.fatherMobile,
    AppStrings.confessionFather,
    AppStrings.school,
    AppStrings.address,
    AppStrings.childCode,
    AppStrings.notes,
  ];

  /// Header synonyms, normalised. Arabic and English headings both resolve, so
  /// a sheet exported from the old spreadsheets still imports.
  static const Map<String, List<String>> _headerAliases =
      <String, List<String>>{
    'name': <String>[
      'اسم المخدوم',
      'اسم الطالب',
      'الاسم',
      'اسم',
      'المخدوم',
      'child name',
      'student name',
      'name',
      'full name',
    ],
    'gender': <String>[
      'النوع',
      'الجنس',
      'ولد او بنت',
      'ولد/بنت',
      'gender',
      'sex',
      'boy/girl',
    ],
    'birth_date': <String>[
      'تاريخ الميلاد',
      'الميلاد',
      'تاريخ الميلاد الميلادي',
      'السن',
      'birth date',
      'birthdate',
      'date of birth',
      'dob',
    ],
    'mobile': <String>[
      'موبايل المخدوم',
      'موبايل الطالب',
      'الموبايل',
      'موبايل',
      'تليفون',
      'رقم الموبايل',
      'child mobile',
      'student mobile',
      'mobile',
      'phone',
    ],
    'mother_name': <String>[
      'اسم الام',
      'الام',
      'mother name',
      'mother',
    ],
    'mother_mobile': <String>[
      'موبايل الام',
      'تليفون الام',
      'mother mobile',
      'mother phone',
    ],
    'father_name': <String>[
      'اسم الاب',
      'الاب',
      'father name',
      'father',
    ],
    'father_mobile': <String>[
      'موبايل الاب',
      'تليفون الاب',
      'father mobile',
      'father phone',
    ],
    'confession_father': <String>[
      'اب الاعتراف',
      'ابو الاعتراف',
      'الاب الروحي',
      'اب اعتراف',
      'confession father',
      'father of confession',
    ],
    'school': <String>['المدرسه', 'مدرسه', 'school'],
    'address': <String>[
      'العنوان',
      'عنوان',
      'السكن',
      'المنطقه',
      'address',
      'location',
    ],
    'code': <String>[
      'كود المخدوم',
      'كود الطالب',
      'الكود',
      'كود',
      'رقم المخدوم',
      'child code',
      'student id',
      'code',
      'id',
    ],
    'notes': <String>['ملاحظات', 'ملحوظات', 'notes', 'note', 'remarks'],
  };

  // ---------------------------------------------------------------- importing

  static ExcelParseResult parseChildren(List<int> bytes) {
    final Excel book;
    try {
      book = Excel.decodeBytes(bytes);
    } catch (_) {
      return const ExcelParseResult(error: AppStrings.importMissingHeader);
    }

    final sheet =
        book.tables.values.where((table) => table.rows.isNotEmpty).firstOrNull;
    if (sheet == null) {
      return const ExcelParseResult(error: AppStrings.importEmptyFile);
    }

    final allRows = sheet.rows;
    final headerIndex = _findHeaderRow(allRows);
    if (headerIndex == null) {
      return const ExcelParseResult(error: AppStrings.importMissingHeader);
    }

    final columns = _mapColumns(allRows[headerIndex]);
    if (!columns.containsKey('name')) {
      return const ExcelParseResult(error: AppStrings.importMissingHeader);
    }

    final parsed = <ImportRow>[];
    for (var i = headerIndex + 1; i < allRows.length; i++) {
      final cells = allRows[i];
      if (_isBlankRow(cells)) continue;

      final name = _textAt(cells, columns['name']);
      final row = ImportRow(
        // Spreadsheet rows are 1-based for the user.
        rowNumber: i + 1,
        name: name,
        gender: Gender.tryParse(_textAt(cells, columns['gender'])),
        birthDate: _dateAt(cells, columns['birth_date']),
        code: _nullableAt(cells, columns['code']),
        mobile: _nullableAt(cells, columns['mobile']),
        motherName: _nullableAt(cells, columns['mother_name']),
        motherMobile: _nullableAt(cells, columns['mother_mobile']),
        fatherName: _nullableAt(cells, columns['father_name']),
        fatherMobile: _nullableAt(cells, columns['father_mobile']),
        confessionFather: _nullableAt(cells, columns['confession_father']),
        school: _nullableAt(cells, columns['school']),
        address: _nullableAt(cells, columns['address']),
        notes: _nullableAt(cells, columns['notes']),
      );

      if (name.isEmpty) row.parseErrors.add(AppStrings.importErrorNameMissing);
      if (row.gender == null && columns.containsKey('gender')) {
        row.parseErrors.add(AppStrings.importErrorGenderMissing);
      }
      if (!_isValidMobile(row.mobile) ||
          !_isValidMobile(row.motherMobile) ||
          !_isValidMobile(row.fatherMobile)) {
        row.parseErrors.add(AppStrings.importErrorMobile);
      }
      if (row.birthDate != null && row.birthDate!.isAfter(DateTime.now())) {
        row.parseErrors.add(AppStrings.importErrorBirthDate);
      }

      parsed.add(row);
    }

    if (parsed.isEmpty) {
      return const ExcelParseResult(error: AppStrings.importEmptyFile);
    }
    return ExcelParseResult(rows: parsed);
  }

  /// Scans the first few rows for the one that looks like a header.
  static int? _findHeaderRow(List<List<Data?>> rows) {
    final limit = rows.length < 10 ? rows.length : 10;
    for (var i = 0; i < limit; i++) {
      if (_mapColumns(rows[i]).containsKey('name')) return i;
    }
    return null;
  }

  /// Maps a logical field name to its column index in this sheet.
  static Map<String, int> _mapColumns(List<Data?> headerCells) {
    final result = <String, int>{};
    for (var index = 0; index < headerCells.length; index++) {
      final heading = _normalise(_cellText(headerCells[index]));
      if (heading.isEmpty) continue;

      for (final entry in _headerAliases.entries) {
        if (result.containsKey(entry.key)) continue;
        if (entry.value.any((alias) => _normalise(alias) == heading)) {
          result[entry.key] = index;
          break;
        }
      }
    }
    return result;
  }

  /// Lowercases, collapses whitespace, and folds the Arabic letter variants
  /// that differ only by hamza or final form, so "الأم" matches "الام".
  static String _normalise(String value) {
    var text = value.trim().toLowerCase();
    text = text.replaceAll(RegExp(r'[\u0617-\u061A\u064B-\u0652\u0640]'), '');
    text = text
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ة', 'ه');
    text = text.replaceAll(RegExp(r'[_\-./\\]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  static bool _isBlankRow(List<Data?> cells) =>
      cells.every((cell) => _cellText(cell).isEmpty);

  static String _textAt(List<Data?> cells, int? index) {
    if (index == null || index >= cells.length) return '';
    return _cellText(cells[index]);
  }

  static String? _nullableAt(List<Data?> cells, int? index) {
    final text = _textAt(cells, index);
    return text.isEmpty ? null : text;
  }

  static DateTime? _dateAt(List<Data?> cells, int? index) {
    if (index == null || index >= cells.length) return null;
    final value = cells[index]?.value;

    if (value is DateCellValue) return value.asDateTimeLocal();
    if (value is DateTimeCellValue) return value.asDateTimeLocal();

    final text = _textAt(cells, index);
    if (text.isEmpty) return null;

    final iso = DateTime.tryParse(text);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    // Accept d/M/yyyy and d-M-yyyy, the usual hand-typed forms.
    final parts = text.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null && year > 1900) {
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      }
    }
    return null;
  }

  static String _cellText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';

    if (value is DoubleCellValue) {
      final number = value.value;
      // Excel stores whole numbers as doubles; avoid a trailing ".0".
      return number == number.roundToDouble()
          ? number.toInt().toString()
          : number.toString();
    }
    return value.toString().trim();
  }

  static bool _isValidMobile(String? value) {
    if (value == null) return true;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return true;
    return digits.length >= 7 && digits.length <= 15;
  }

  // ---------------------------------------------------------------- exporting

  static List<int> childrenTemplate() {
    final (book, sheet) = _book(AppStrings.childrenTitle);
    sheet.appendRow(childColumns.map(_text).toList());
    // One illustrative row so the expected gender wording is obvious.
    sheet.appendRow(<CellValue?>[
      _text('مينا جورج'),
      _text(AppStrings.boy),
      _text('2015-03-14'),
      _text('01000000000'),
      _text('مريم'),
      _text('01100000000'),
      _text('جورج'),
      _text('01200000000'),
      _text('أبونا يوسف'),
      _text('مدرسة النيل'),
      _text('شبرا'),
      _text('C-001'),
      _text(''),
    ]);
    return _encode(book);
  }

  static List<int> childrenWorkbook({
    required List<Child> children,
    required String Function(String classId) classNameOf,
  }) {
    final (book, sheet) = _book(AppStrings.childrenTitle);
    sheet.appendRow(<CellValue?>[
      _text(AppStrings.classLabel),
      ...childColumns.map(_text),
      _text(AppStrings.age),
      _text(AppStrings.active),
    ]);

    // Group by class, sorted by class name.
    final grouped = <String, List<Child>>{};
    for (final child in children) {
      (grouped[child.classId] ??= []).add(child);
    }
    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) => classNameOf(a.key).compareTo(classNameOf(b.key)));

    for (final entry in sortedGroups) {
      final className = classNameOf(entry.key);
      // Section header row.
      sheet.appendRow(<CellValue?>[_text('── $className ──')]);
      for (final child in entry.value) {
        sheet.appendRow(<CellValue?>[
          _text(className),
          _text(child.fullName),
          _text(child.gender.label),
          _text(child.birthDate == null
              ? ''
              : AppDateUtils.toIsoDate(child.birthDate!)),
          _text(child.mobile),
          _text(child.motherName),
          _text(child.motherMobile),
          _text(child.fatherName),
          _text(child.fatherMobile),
          _text(child.confessionFather),
          _text(child.school),
          _text(child.address),
          _text(child.code),
          _text(child.notes),
          child.ageYears == null ? null : IntCellValue(child.ageYears!),
          _text(child.isActive ? AppStrings.yes : AppStrings.no),
        ]);
      }
    }
    return _encode(book);
  }

  /// One Saturday's sheet for a class, matching the on-screen grid.
  static List<int> attendanceSheetWorkbook({
    required String className,
    required DateTime sessionDate,
    required List<AttendanceEntry> entries,
  }) {
    final (book, sheet) = _book(AppStrings.attendanceTitle);
    sheet.appendRow(<CellValue?>[_text(className)]);
    sheet.appendRow(
        <CellValue?>[_text(AppDateUtils.formatDayDate(sessionDate))]);
    sheet.appendRow(<CellValue?>[]);
    sheet.appendRow(<CellValue?>[
      _text(AppStrings.childName),
      _text(AppStrings.gender),
      _text(AppStrings.sundaySchoolShort),
      _text(AppStrings.vespersShort),
      _text(AppStrings.massShort),
      _text(AppStrings.confessionShort),
      _text(AppStrings.total),
      _text(AppStrings.maxPoints),
    ]);

    for (final entry in entries) {
      sheet.appendRow(<CellValue?>[
        _text(entry.child.fullName),
        _text(entry.child.gender.label),
        IntCellValue(entry.sundaySchool ? entry.pointsSundaySchool : 0),
        IntCellValue(entry.vespers ? entry.pointsVespers : 0),
        IntCellValue(entry.mass ? entry.pointsMass : 0),
        IntCellValue(entry.confession ? entry.pointsConfession : 0),
        IntCellValue(entry.score),
        IntCellValue(entry.maxScore),
      ]);
    }
    return _encode(book);
  }

  static List<int> monthlyWorkbook(List<ChildMonthlyReport> report) {
    final (book, sheet) = _book(AppStrings.monthlyReport);
    sheet.appendRow(<CellValue?>[
      _text(AppStrings.classLabel),
      _text(AppStrings.childName),
      _text(AppStrings.gender),
      _text(AppStrings.month),
      _text(AppStrings.attendedSessions),
      _text(AppStrings.totalSessions),
      _text(AppStrings.totalPoints),
      _text('${AppStrings.averageAttendance} %'),
    ]);

    // Group by class, sorted by class name then child name.
    final grouped = <String, List<ChildMonthlyReport>>{};
    for (final row in report) {
      (grouped[row.classId] ??= []).add(row);
    }
    final sortedGroups = grouped.entries.toList()
      ..sort(
          (a, b) => a.value.first.className.compareTo(b.value.first.className));

    for (final entry in sortedGroups) {
      final className = entry.value.first.className;
      sheet.appendRow(<CellValue?>[_text('── $className ──')]);
      for (final row in entry.value) {
        sheet.appendRow(<CellValue?>[
          _text(row.className),
          _text(row.childName),
          _text(row.gender.label),
          _text(AppDateUtils.formatMonth(row.monthStart)),
          IntCellValue(row.sessionsAttended),
          IntCellValue(row.sessionsTotal),
          IntCellValue(row.points),
          DoubleCellValue(row.percentage),
        ]);
      }
    }
    return _encode(book);
  }

  static List<int> yearlyWorkbook(
    List<ChildYearReport> report, {
    Map<String, int>? sessionsHeldByChild,
  }) {
    final (book, sheet) = _book(AppStrings.overallReport);
    sheet.appendRow(<CellValue?>[
      _text(AppStrings.rank),
      _text(AppStrings.classLabel),
      _text(AppStrings.childName),
      _text(AppStrings.gender),
      _text(AppStrings.birthDate),
      _text(AppStrings.school),
      _text(AppStrings.attendedSessions),
      _text(AppStrings.totalSessions),
      _text(AppStrings.totalPoints),
      _text('${AppStrings.averageAttendance} %'),
    ]);

    // Group by class, sorted by class name; rank within each class.
    final grouped = <String, List<ChildYearReport>>{};
    for (final row in report) {
      (grouped[row.classId] ??= []).add(row);
    }
    final sortedGroups = grouped.entries.toList()
      ..sort(
          (a, b) => a.value.first.className.compareTo(b.value.first.className));

    for (final entry in sortedGroups) {
      final className = entry.value.first.className;
      // Children in this class are already sorted by points desc from the repo.
      sheet.appendRow(<CellValue?>[_text('── $className ──')]);
      for (var i = 0; i < entry.value.length; i++) {
        final row = entry.value[i];
        final held = sessionsHeldByChild?[row.childId] ?? row.sessionsTotal;
        final pct =
            held > 0 ? row.sessionsAttended / held * 100 : row.percentage;
        sheet.appendRow(<CellValue?>[
          IntCellValue(i + 1),
          _text(row.className),
          _text(row.childName),
          _text(row.gender.label),
          _text(row.birthDate == null
              ? ''
              : AppDateUtils.toIsoDate(row.birthDate!)),
          _text(row.school),
          IntCellValue(row.sessionsAttended),
          IntCellValue(held),
          IntCellValue(row.points),
          DoubleCellValue(pct),
        ]);
      }
    }
    return _encode(book);
  }

  static List<int> classReportWorkbook(
    List<ClassYearScore> report, {
    Map<String, int>? classMaxHeld,
  }) {
    final (book, sheet) = _book(AppStrings.classReport);
    sheet.appendRow(<CellValue?>[
      _text(AppStrings.classLabel),
      _text(AppStrings.childrenCount),
      _text(AppStrings.totalPoints),
      _text('${AppStrings.averageAttendance} %'),
    ]);

    for (final row in report) {
      final maxHeld = classMaxHeld?[row.classId] ?? row.maxPoints;
      final pct = maxHeld > 0 ? row.points / maxHeld * 100 : row.percentage;
      sheet.appendRow(<CellValue?>[
        _text(row.className),
        IntCellValue(row.children),
        IntCellValue(row.points),
        DoubleCellValue(pct),
      ]);
    }
    return _encode(book);
  }

  /// The reports screen's children tab, exactly as listed: [rows] keep the
  /// order the screen shows (highest points first), so rank is the position.
  static List<int> childScoresWorkbook(List<ChildScoreRow> rows) {
    final (book, sheet) = _book(AppStrings.overallReport);
    sheet.appendRow(<CellValue?>[
      _text(AppStrings.rank),
      _text(AppStrings.classLabel),
      _text(AppStrings.childName),
      _text(AppStrings.attendedSessions),
      _text(AppStrings.totalSessions),
      _text(AppStrings.totalPoints),
      _text('${AppStrings.averageAttendance} %'),
    ]);
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      sheet.appendRow(<CellValue?>[
        IntCellValue(i + 1),
        _text(row.className),
        _text(row.childName),
        IntCellValue(row.attended),
        IntCellValue(row.total),
        IntCellValue(row.points),
        DoubleCellValue(
          row.total > 0 ? row.attended / row.total * 100 : 0,
        ),
      ]);
    }
    return _encode(book);
  }

  /// The reports screen's class tab, in the order the screen shows.
  static List<int> classScoresWorkbook(List<ClassScoreRow> rows) {
    final (book, sheet) = _book(AppStrings.classReport);
    sheet.appendRow(<CellValue?>[
      _text(AppStrings.rank),
      _text(AppStrings.classLabel),
      _text(AppStrings.childrenCount),
      _text(AppStrings.totalPoints),
      _text('${AppStrings.averageAttendance} %'),
    ]);
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      sheet.appendRow(<CellValue?>[
        IntCellValue(i + 1),
        _text(row.className),
        IntCellValue(row.children),
        IntCellValue(row.points),
        DoubleCellValue(
          row.maxPoints > 0 ? row.points / row.maxPoints * 100 : 0,
        ),
      ]);
    }
    return _encode(book);
  }

  // ------------------------------------------------------ competition exports

  /// One sheet per competition plus a cumulative sheet over the same set,
  /// ordered by total mark, highest first.
  static List<int> competitionsWorkbook({
    required List<Competition> competitions,
    required List<Child> children,
    required List<CompetitionMark> marks,
    required String Function(String classId) classNameOf,
  }) {
    final byCompetition = <String, Map<String, int>>{};
    for (final m in marks) {
      (byCompetition[m.competitionId] ??= <String, int>{})[m.childId] = m.mark;
    }
    final ordered = [...competitions]
      ..sort((a, b) => a.weekDate.compareTo(b.weekDate));

    final book = Excel.createExcel();
    final usedNames = <String>{};
    String sheetName(Competition c) {
      var base = c.title.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
      if (base.isEmpty) base = AppStrings.weeklyCompetition;
      if (base.length > 28) base = base.substring(0, 28);
      var name = base;
      for (var i = 2; !usedNames.add(name); i++) {
        name = '$base $i';
      }
      return name;
    }

    // Cumulative sheet first.
    final totals = <String, int>{};
    for (final c in ordered) {
      byCompetition[c.id]?.forEach((childId, mark) {
        totals[childId] = (totals[childId] ?? 0) + mark;
      });
    }
    final totalMax = ordered.fold<int>(0, (sum, c) => sum + c.maxMark);
    final ranked = children.where((c) => totals.containsKey(c.id)).toList()
      ..sort((a, b) {
        final byTotal = totals[b.id]!.compareTo(totals[a.id]!);
        return byTotal != 0 ? byTotal : a.fullName.compareTo(b.fullName);
      });

    usedNames.add(AppStrings.cumulativeScores);
    final summary = book[AppStrings.cumulativeScores];
    book.setDefaultSheet(AppStrings.cumulativeScores);
    summary.appendRow(<CellValue?>[
      _text(AppStrings.rank),
      _text(AppStrings.childName),
      _text(AppStrings.classLabel),
      for (final c in ordered)
        _text('${c.title} (${AppDateUtils.toIsoDate(c.weekDate)}) / ${c.maxMark}'),
      _text('${AppStrings.totalMarks} / $totalMax'),
    ]);
    var rank = 0;
    int? previous;
    for (var i = 0; i < ranked.length; i++) {
      final child = ranked[i];
      final total = totals[child.id]!;
      if (total != previous) rank = i + 1; // ties share a rank
      previous = total;
      summary.appendRow(<CellValue?>[
        IntCellValue(rank),
        _text(child.fullName),
        _text(classNameOf(child.classId)),
        for (final c in ordered)
          byCompetition[c.id]?[child.id] == null
              ? null
              : IntCellValue(byCompetition[c.id]![child.id]!),
        IntCellValue(total),
      ]);
    }

    for (final c in ordered) {
      final sheet = book[sheetName(c)];
      sheet.appendRow(<CellValue?>[
        _text('${c.title} - ${AppDateUtils.toIsoDate(c.weekDate)}'),
      ]);
      sheet.appendRow(<CellValue?>[]);
      sheet.appendRow(<CellValue?>[
        _text(AppStrings.rank),
        _text(AppStrings.childName),
        _text(AppStrings.classLabel),
        _text('${AppStrings.mark} / ${c.maxMark}'),
      ]);
      final marksOf = byCompetition[c.id] ?? const <String, int>{};
      final rows = children.where((ch) => marksOf.containsKey(ch.id)).toList()
        ..sort((a, b) {
          final byMark = marksOf[b.id]!.compareTo(marksOf[a.id]!);
          return byMark != 0 ? byMark : a.fullName.compareTo(b.fullName);
        });
      var r = 0;
      int? last;
      for (var i = 0; i < rows.length; i++) {
        final mark = marksOf[rows[i].id]!;
        if (mark != last) r = i + 1;
        last = mark;
        sheet.appendRow(<CellValue?>[
          IntCellValue(r),
          _text(rows[i].fullName),
          _text(classNameOf(rows[i].classId)),
          IntCellValue(mark),
        ]);
      }
    }

    if (book.tables.containsKey('Sheet1')) book.delete('Sheet1');
    return _encode(book);
  }

  // ------------------------------------------------- servant activity exports

  static List<int> servantYearlyWorkbook({
    required List<ServantActivitySummary> summaries,
    required int totalSessions,
  }) {
    final (book, sheet) = _book(AppStrings.exportServantYearly);
    sheet.appendRow(<CellValue?>[
      _text('الترتيب'),
      _text('اسم الخادم'),
      _text('تحضير الدرس'),
      _text('قيد المراجعة'),
      _text('حضور مدارس الأحد'),
      _text('% مدارس الأحد'),
      _text('حضور اجتماع الخدمة'),
      _text('% اجتماع الخدمة'),
      _text('حضور القداس'),
      _text('% القداس'),
      _text('الاعتراف'),
      _text('% الاعتراف'),
    ]);

    String pct(int count) =>
        totalSessions > 0 ? '${(count / totalSessions * 100).round()}%' : '-';

    for (var i = 0; i < summaries.length; i++) {
      final s = summaries[i];
      sheet.appendRow(<CellValue?>[
        IntCellValue(i + 1),
        _text(s.servantName),
        IntCellValue(s.totalPreps),
        IntCellValue(s.pendingPreps),
        IntCellValue(s.sundaySchoolCount),
        _text(pct(s.sundaySchoolCount)),
        IntCellValue(s.servantMeetingCount),
        _text(pct(s.servantMeetingCount)),
        IntCellValue(s.massCount),
        _text(pct(s.massCount)),
        IntCellValue(s.confessionCount),
        _text(pct(s.confessionCount)),
      ]);
    }
    return _encode(book);
  }

  static List<int> servantMonthlyWorkbook({
    required List<ServantMonthlyReport> data,
    required String monthLabel,
  }) {
    final (book, sheet) = _book(AppStrings.exportServantMonthly);
    sheet.appendRow(<CellValue?>[_text(monthLabel)]);
    sheet.appendRow(<CellValue?>[]);
    sheet.appendRow(<CellValue?>[
      _text('اسم الخادم'),
      _text('حضور مدارس الأحد'),
      _text('حضور اجتماع الخدمة'),
      _text('حضور القداس'),
      _text('الاعتراف'),
      _text('تحضير الدرس'),
    ]);

    for (final r in data) {
      sheet.appendRow(<CellValue?>[
        _text(r.servantName),
        IntCellValue(r.sundaySchool),
        IntCellValue(r.servantMeeting),
        IntCellValue(r.mass),
        IntCellValue(r.confession),
        IntCellValue(r.prepsCount),
      ]);
    }
    return _encode(book);
  }

  // ------------------------------------------------------------------ helpers

  static (Excel, Sheet) _book(String sheetName) {
    final book = Excel.createExcel();
    final sheet = book[sheetName];
    book.setDefaultSheet(sheetName);
    // createExcel seeds a "Sheet1" that would otherwise ship empty.
    if (sheetName != 'Sheet1' && book.tables.containsKey('Sheet1')) {
      book.delete('Sheet1');
    }
    return (book, sheet);
  }

  static CellValue? _text(String? value) =>
      (value == null || value.isEmpty) ? null : TextCellValue(value);

  /// Gives every sheet the look of an Excel table: a coloured bold header,
  /// bordered cells, banded rows and sized columns. Every export goes through
  /// [_encode], so none is left plain.
  static void _formatAsTable(Excel book) {
    final border = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('#B8C2CC'),
    );
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1F3A5F'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );
    CellStyle body(bool banded) => CellStyle(
          backgroundColorHex: banded
              ? ExcelColor.fromHexString('#EEF3F8')
              : ExcelColor.none,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: border,
          rightBorder: border,
          topBorder: border,
          bottomBorder: border,
        );

    for (final sheet in book.tables.values) {
      final rows = sheet.rows;
      if (rows.isEmpty) continue;

      bool filled(Data? c) => c?.value != null && '${c!.value}'.isNotEmpty;
      // The header is the first row that has more than one filled cell; rows
      // before it are titles and stay as they are.
      final headerRow = rows.indexWhere((r) => r.where(filled).length > 1);
      if (headerRow < 0) continue;

      final columns = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
      final widths = List<double>.filled(columns, 10);

      for (var r = headerRow; r < rows.length; r++) {
        final cells = rows[r];
        final isGroupRow = r > headerRow && cells.where(filled).length == 1;
        final isBlank = cells.where(filled).isEmpty;
        if (isBlank) continue;
        for (var c = 0; c < columns; c++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
          );
          if (r == headerRow) {
            cell.cellStyle = headerStyle;
          } else if (isGroupRow) {
            cell.cellStyle = headerStyle;
          } else {
            cell.cellStyle = body((r - headerRow).isEven);
          }
          final length = c < cells.length && filled(cells[c])
              ? '${cells[c]!.value}'.length
              : 0;
          if (!isGroupRow && length + 4 > widths[c]) {
            widths[c] = (length + 4).toDouble();
          }
        }
      }
      for (var c = 0; c < columns; c++) {
        sheet.setColumnWidth(c, widths[c].clamp(10, 45).toDouble());
      }
      sheet.setRowHeight(headerRow, 32);
    }
  }

  static List<int> _encode(Excel book) {
    _formatAsTable(book);
    final bytes = book.encode();
    if (bytes == null) {
      throw Exception(AppStrings.somethingWentWrong);
    }
    return bytes;
  }
}
