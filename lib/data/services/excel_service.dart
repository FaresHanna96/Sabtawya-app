import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../models/attendance.dart';
import '../models/child.dart';
import '../models/competition.dart';
import '../models/event.dart';
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

/// One line of the birthdays screen, as listed (already narrowed to the
/// months and class the user picked).
class BirthdayRow {
  const BirthdayRow({
    required this.name,
    required this.birthDate,
    required this.turningAge,
    this.className,
    this.role,
    this.mobile,
  });

  final String name;
  final DateTime birthDate;
  final int turningAge;
  final String? className;

  /// Servants only: أمين الخدمة / خادم / خادم عام.
  final String? role;
  final String? mobile;
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
    _writeByClass<Child>(
      book,
      sheet,
      header: <CellValue?>[
        _text(AppStrings.classLabel),
        ...childColumns.map(_text),
        _text(AppStrings.age),
        _text(AppStrings.active),
      ],
      rows: children,
      classOf: (c) => classNameOf(c.classId),
      cells: (child, _) => <CellValue?>[
        _text(classNameOf(child.classId)),
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
      ],
    );
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
    _writeByClass<ChildMonthlyReport>(
      book,
      sheet,
      header: <CellValue?>[
        _text(AppStrings.classLabel),
        _text(AppStrings.childName),
        _text(AppStrings.gender),
        _text(AppStrings.month),
        _text(AppStrings.attendedSessions),
        _text(AppStrings.totalSessions),
        _text(AppStrings.totalPoints),
        _text('${AppStrings.averageAttendance} %'),
      ],
      rows: report,
      classOf: (r) => r.className,
      cells: (row, _) => <CellValue?>[
        _text(row.className),
        _text(row.childName),
        _text(row.gender.label),
        _text(AppDateUtils.formatMonth(row.monthStart)),
        IntCellValue(row.sessionsAttended),
        IntCellValue(row.sessionsTotal),
        IntCellValue(row.points),
        DoubleCellValue(row.percentage),
      ],
    );
    return _encode(book);
  }

  static List<int> yearlyWorkbook(
    List<ChildYearReport> report, {
    Map<String, int>? sessionsHeldByChild,
  }) {
    final (book, sheet) = _book(AppStrings.overallReport);
    // Children come sorted by points (best first): rank within each class.
    _writeByClass<ChildYearReport>(
      book,
      sheet,
      header: <CellValue?>[
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
      ],
      rows: report,
      classOf: (r) => r.className,
      cells: (row, i) {
        final held = sessionsHeldByChild?[row.childId] ?? row.sessionsTotal;
        final pct =
            held > 0 ? row.sessionsAttended / held * 100 : row.percentage;
        return <CellValue?>[
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
        ];
      },
    );
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
    // [rows] come best first: rank restarts at 1 in each class.
    _writeByClass<ChildScoreRow>(
      book,
      sheet,
      header: <CellValue?>[
        _text(AppStrings.rank),
        _text(AppStrings.classLabel),
        _text(AppStrings.childName),
        _text(AppStrings.attendedSessions),
        _text(AppStrings.totalSessions),
        _text(AppStrings.totalPoints),
        _text('${AppStrings.averageAttendance} %'),
      ],
      rows: rows,
      classOf: (r) => r.className,
      cells: (row, i) => <CellValue?>[
        IntCellValue(i + 1),
        _text(row.className),
        _text(row.childName),
        IntCellValue(row.attended),
        IntCellValue(row.total),
        IntCellValue(row.points),
        DoubleCellValue(row.total > 0 ? row.attended / row.total * 100 : 0),
      ],
    );
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

  /// The birthdays screen, in the order it lists them (by day of the month).
  /// [servants] adds the role column the servants tab shows.
  static List<int> birthdaysWorkbook(
    List<BirthdayRow> rows, {
    required bool servants,
  }) {
    final (book, sheet) = _book(AppStrings.birthdaysTitle);
    final header = <CellValue?>[
      _text(AppStrings.classLabel),
      _text(AppStrings.dayOfMonth),
      _text(AppStrings.month),
      _text(AppStrings.personName),
      if (servants) _text(AppStrings.role),
      _text(AppStrings.birthDate),
      _text(AppStrings.turningAgeColumn),
      _text(AppStrings.mobile),
    ];
    List<CellValue?> cells(BirthdayRow row, int _) => <CellValue?>[
          _text(row.className),
          IntCellValue(row.birthDate.day),
          _text(AppDateUtils.monthName(row.birthDate.month)),
          _text(row.name),
          if (servants) _text(row.role),
          _text(AppDateUtils.toIsoDate(row.birthDate)),
          IntCellValue(row.turningAge),
          _text(row.mobile),
        ];
    if (servants) {
      // A servant can serve several classes: one list, in the screen's order.
      sheet.appendRow(header);
      for (final row in rows) {
        sheet.appendRow(cells(row, 0));
      }
    } else {
      _writeByClass<BirthdayRow>(
        book,
        sheet,
        header: header,
        rows: rows,
        classOf: (r) => r.className ?? '',
        cells: cells,
      );
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
        _text(
            '${c.title} (${AppDateUtils.toIsoDate(c.weekDate)}) / ${c.maxMark}'),
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

  // ------------------------------------------------------------ event export

  /// The tabs of the event screen, in order.
  static const eventTabs = <String>[
    AppStrings.all,
    AppStrings.bookedTab,
    AppStrings.partialPay,
    AppStrings.paidInFull,
    AppStrings.notPaidTab,
  ];

  /// How many children fall under each of [eventTabs].
  static Map<String, int> eventTabCounts(List<ChildEventBalance> balances) => {
        for (final e in eventTabFilter.entries)
          e.key: balances.where(e.value).length,
      };

  /// Which children each tab of the event screen holds. Shared by the screen,
  /// its counts and the export, so they always agree. A child who reserved
  /// without paying is both حاجزين and لم يدفع (the full amount is owed).
  static final eventTabFilter = <String, bool Function(ChildEventBalance)>{
    AppStrings.all: (_) => true,
    AppStrings.bookedTab: (b) => b.totalPaid > 0 || b.reserved,
    AppStrings.partialPay: (b) => b.totalPaid > 0 && b.remaining > 0,
    AppStrings.paidInFull: (b) => b.totalPaid > 0 && b.remaining <= 0,
    AppStrings.notPaidTab: (b) => b.totalPaid == 0,
  };

  /// A trip's payments: one sheet for each chosen status ([tabs], from
  /// [eventTabs], kept in the screen's order). Each sheet holds only that
  /// status's children, grouped by class then name, and ends with totals.
  static List<int> eventWorkbook({
    required List<ChildEventBalance> balances,
    required Map<String, Map<String, double>> methodByChild,
    required Map<String, String> phones,
    required String Function(String classId) classNameOf,
    List<String> tabs = const [AppStrings.all],
  }) {
    String status(ChildEventBalance b) => b.totalPaid == 0
        ? (b.reserved ? AppStrings.reservedUnpaidStatus : AppStrings.notPaidTab)
        : b.remaining <= 0
            ? AppStrings.paidInFull
            : AppStrings.partialPay;

    final sorted = [...balances]..sort((a, b) {
        final byClass =
            classNameOf(a.classId).compareTo(classNameOf(b.classId));
        return byClass != 0 ? byClass : a.childName.compareTo(b.childName);
      });

    final chosen = eventTabs.where(tabs.contains).toList();
    if (chosen.isEmpty) chosen.add(AppStrings.all);

    final book = Excel.createExcel();
    book.setDefaultSheet(chosen.first);
    for (final tab
        in eventTabFilter.entries.where((e) => chosen.contains(e.key))) {
      final sheet = book[tab.key];
      sheet.isRTL = true;
      sheet.appendRow(<CellValue?>[
        _text(AppStrings.serialNo),
        _text(AppStrings.childName),
        _text(AppStrings.classLabel),
        _text(AppStrings.mobile),
        _text(AppStrings.eventCost),
        _text(AppStrings.totalPaid),
        _text(AppStrings.paymentMethodCash),
        _text(AppStrings.paymentMethodTayo),
        _text(AppStrings.remaining),
        _text(AppStrings.paymentStatus),
      ]);
      final rows = sorted.where(tab.value).toList();
      var cost = 0.0, paid = 0.0, cash = 0.0, tayo = 0.0, left = 0.0;
      for (var i = 0; i < rows.length; i++) {
        final b = rows[i];
        final m = methodByChild[b.childId] ?? const <String, double>{};
        final remaining = b.remaining < 0 ? 0.0 : b.remaining;
        cost += b.cost;
        paid += b.totalPaid;
        cash += m['cash'] ?? 0;
        tayo += m['tayo'] ?? 0;
        left += remaining;
        sheet.appendRow(<CellValue?>[
          IntCellValue(i + 1),
          _text(b.childName),
          _text(classNameOf(b.classId)),
          _text(phones[b.childId]),
          DoubleCellValue(b.cost),
          DoubleCellValue(b.totalPaid),
          DoubleCellValue(m['cash'] ?? 0),
          DoubleCellValue(m['tayo'] ?? 0),
          DoubleCellValue(remaining),
          _text(status(b)),
        ]);
      }
      sheet.appendRow(<CellValue?>[
        null,
        _text('${AppStrings.total} (${rows.length})'),
        null,
        null,
        DoubleCellValue(cost),
        DoubleCellValue(paid),
        DoubleCellValue(cash),
        DoubleCellValue(tayo),
        DoubleCellValue(left),
        null,
      ]);
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

  /// Writes [rows] grouped by class: the first sheet holds everyone, class
  /// after class (no separator rows, so its column filters work), and when
  /// there is more than one class each class also gets a sheet of its own.
  /// [cells] gets each row and its position inside its class (for a rank
  /// that restarts per class). Rows keep their order inside a class.
  static void _writeByClass<T>(
    Excel book,
    Sheet main, {
    required List<CellValue?> header,
    required List<T> rows,
    required String Function(T row) classOf,
    required List<CellValue?> Function(T row, int indexInClass) cells,
  }) {
    final groups = <String, List<T>>{};
    for (final row in rows) {
      (groups[classOf(row)] ??= <T>[]).add(row);
    }
    final names = groups.keys.toList()..sort(compareClassNames);

    main.appendRow(header);
    for (final name in names) {
      final group = groups[name]!;
      for (var i = 0; i < group.length; i++) {
        main.appendRow(cells(group[i], i));
      }
    }
    if (names.length < 2) return;

    final used = <String>{...book.tables.keys};
    for (final name in names) {
      final sheet = book[_sheetName(name, used)];
      sheet.appendRow(header);
      final group = groups[name]!;
      for (var i = 0; i < group.length; i++) {
        sheet.appendRow(cells(group[i], i));
      }
    }
  }

  static final _classPattern = RegExp(r'^\s*(\d+)\s*(ولاد|بنات)\s*$');

  /// Class names in the app's order: "3 ولاد", "3 بنات", "4 ولاد"...;
  /// names that do not follow that pattern come after, alphabetically.
  @visibleForTesting
  static int compareClassNames(String a, String b) {
    final ma = _classPattern.firstMatch(a);
    final mb = _classPattern.firstMatch(b);
    if (ma != null && mb != null) {
      final ya = int.parse(ma.group(1)!);
      final yb = int.parse(mb.group(1)!);
      if (ya != yb) return ya.compareTo(yb);
      final boysA = ma.group(2) == 'ولاد';
      final boysB = mb.group(2) == 'ولاد';
      if (boysA != boysB) return boysA ? -1 : 1;
      return 0;
    }
    if (ma != null) return -1;
    if (mb != null) return 1;
    return a.compareTo(b);
  }

  /// A valid, unused sheet name: at most 31 characters, none of : \ / ? * [ ].
  static String _sheetName(String name, Set<String> used) {
    var base = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
    if (base.isEmpty) base = '-';
    if (base.length > 31) base = base.substring(0, 31);
    var candidate = base;
    for (var n = 2; used.contains(candidate); n++) {
      final suffix = ' ($n)';
      candidate = base.length + suffix.length > 31
          ? base.substring(0, 31 - suffix.length) + suffix
          : base + suffix;
    }
    used.add(candidate);
    return candidate;
  }

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
  /// Styles each sheet as a table and returns its range per sheet name
  /// (header row to last row, every column), for the filter buttons.
  static Map<String, String> _formatAsTable(Excel book) {
    final ranges = <String, String>{};
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
          backgroundColorHex:
              banded ? ExcelColor.fromHexString('#EEF3F8') : ExcelColor.none,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: border,
          rightBorder: border,
          topBorder: border,
          bottomBorder: border,
        );

    for (final entry in book.tables.entries) {
      final sheet = entry.value;
      final rows = sheet.rows;
      if (rows.isEmpty) continue;

      bool filled(Data? c) => c?.value != null && '${c!.value}'.isNotEmpty;
      // The header is the first row that has more than one filled cell; rows
      // before it are titles and stay as they are.
      final headerRow = rows.indexWhere((r) => r.where(filled).length > 1);
      if (headerRow < 0) continue;

      final columns = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
      final widths = List<double>.filled(columns, 10);
      var lastRow = headerRow;
      for (var r = rows.length - 1; r > headerRow; r--) {
        if (rows[r].any(filled)) {
          lastRow = r;
          break;
        }
      }
      ranges[entry.key] = '${columnLetter(0)}${headerRow + 1}:'
          '${columnLetter(columns - 1)}${lastRow + 1}';

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
      // Room for the filter button next to each heading.
      for (var c = 0; c < columns; c++) {
        if (widths[c] < 14) sheet.setColumnWidth(c, 14);
      }
    }
    return ranges;
  }

  static List<int> _encode(Excel book) {
    final ranges = _formatAsTable(book);
    final bytes = book.encode();
    if (bytes == null) {
      throw Exception(AppStrings.somethingWentWrong);
    }
    return withFilterButtons(bytes, ranges);
  }

  /// "A", "B", ... "Z", "AA" for a 0-based column.
  @visibleForTesting
  static String columnLetter(int index) {
    var n = index + 1;
    var out = '';
    while (n > 0) {
      final r = (n - 1) % 26;
      out = String.fromCharCode(65 + r) + out;
      n = (n - 1) ~/ 26;
    }
    return out;
  }

  /// Adds Excel's filter buttons (AutoFilter) to the header row of each
  /// sheet in [ranges] (sheet name -> "A1:H40"). The excel package cannot
  /// write them, so the saved file's XML is patched: an `<autoFilter>` after
  /// the sheet data, and the hidden _FilterDatabase name Excel expects.
  /// If anything about the file is unexpected, it is returned unchanged.
  @visibleForTesting
  static List<int> withFilterButtons(
    List<int> xlsx,
    Map<String, String> ranges,
  ) {
    if (ranges.isEmpty) return xlsx;
    try {
      final zip = ZipDecoder().decodeBytes(xlsx);
      String? read(String name) {
        final f = zip.findFile(name);
        return f == null ? null : utf8.decode(f.content as List<int>);
      }

      final workbook = read('xl/workbook.xml');
      final rels = read('xl/_rels/workbook.xml.rels');
      if (workbook == null || rels == null) return xlsx;

      final targets = <String, String>{};
      for (final m in RegExp(r'<Relationship\b[^>]*>').allMatches(rels)) {
        final tag = m.group(0)!;
        final id = RegExp(r'Id="([^"]+)"').firstMatch(tag)?.group(1);
        final target = RegExp(r'Target="([^"]+)"').firstMatch(tag)?.group(1);
        if (id != null && target != null) {
          targets[id] =
              target.startsWith('/') ? target.substring(1) : 'xl/$target';
        }
      }

      final names = <String>[];
      final changed = <String, String>{};
      final sheetTags =
          RegExp(r'<sheet\b[^>]*/>').allMatches(workbook).toList();
      for (var i = 0; i < sheetTags.length; i++) {
        final tag = sheetTags[i].group(0)!;
        final name = _xmlUnescape(
            RegExp(r'name="([^"]*)"').firstMatch(tag)?.group(1) ?? '');
        final rid = RegExp(r'r:id="([^"]+)"').firstMatch(tag)?.group(1);
        final ref = ranges[name];
        final path = rid == null ? null : targets[rid];
        if (ref == null || path == null) continue;
        final xml = changed[path] ?? read(path);
        if (xml == null ||
            xml.contains('<autoFilter') ||
            !xml.contains('</sheetData>')) {
          continue;
        }
        changed[path] = xml.replaceFirst(
            '</sheetData>', '</sheetData><autoFilter ref="$ref"/>');
        final abs = ref.split(':').map((c) {
          final m = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(c)!;
          return '\$${m.group(1)}\$${m.group(2)}';
        }).join(':');
        final quoted = "'${name.replaceAll("'", "''")}'";
        names.add('<definedName name="_xlnm._FilterDatabase" '
            'localSheetId="$i" hidden="1">'
            '${_xmlEscape('$quoted!$abs')}</definedName>');
      }
      if (changed.isEmpty) return xlsx;

      var newWorkbook = workbook;
      if (names.isNotEmpty) {
        newWorkbook = workbook.contains('<definedNames>')
            ? workbook.replaceFirst(
                '<definedNames>', '<definedNames>${names.join()}')
            : workbook.replaceFirst('</sheets>',
                '</sheets><definedNames>${names.join()}</definedNames>');
      }
      changed['xl/workbook.xml'] = newWorkbook;

      final out = Archive();
      for (final file in zip.files) {
        final text = changed[file.name];
        if (text == null) {
          out.addFile(file);
        } else {
          final data = utf8.encode(text);
          out.addFile(ArchiveFile(file.name, data.length, data));
        }
      }
      return ZipEncoder().encode(out) ?? xlsx;
    } catch (_) {
      return xlsx;
    }
  }

  static String _xmlEscape(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _xmlUnescape(String v) => v
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}
