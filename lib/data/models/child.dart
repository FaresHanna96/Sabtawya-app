import '../../core/l10n/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import 'parsers.dart';

enum Gender {
  boy('boy', AppStrings.boy),
  girl('girl', AppStrings.girl);

  const Gender(this.wire, this.label);

  final String wire;
  final String label;

  static Gender fromWire(dynamic value) => Gender.values.firstWhere(
        (gender) => gender.wire == value?.toString(),
        orElse: () => Gender.boy,
      );

  /// Lenient parsing for Excel import, which may carry Arabic or English.
  static Gender? tryParse(String? raw) {
    final text = raw?.trim().toLowerCase();
    if (text == null || text.isEmpty) return null;

    const boyWords = <String>{
      'boy',
      'b',
      'm',
      'male',
      'ولد',
      'ذكر',
      'اولاد',
      'أولاد'
    };
    const girlWords = <String>{
      'girl',
      'g',
      'f',
      'female',
      'بنت',
      'أنثى',
      'انثى',
      'بنات'
    };

    if (boyWords.contains(text)) return Gender.boy;
    if (girlWords.contains(text)) return Gender.girl;
    return null;
  }
}

/// The single source of truth for a child (مخدوم).
///
/// Attendance records reference `id` only, so editing a name here updates every
/// attendance screen and report at once.
class Child {
  const Child({
    required this.id,
    required this.classId,
    required this.fullName,
    required this.gender,
    required this.isActive,
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
    this.photoPath,
    this.lastPhoneVisitDate,
    this.lastPhoneVisitNotes,
    this.lastHomeVisitDate,
    this.lastHomeVisitNotes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String classId;
  final String fullName;
  final Gender gender;
  final bool isActive;
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

  /// Path of the photo inside the `child-photos` bucket, not a URL: the bucket
  /// is private, so a signed URL is minted when the image is displayed.
  final String? photoPath;
  final DateTime? lastPhoneVisitDate;
  final String? lastPhoneVisitNotes;
  final DateTime? lastHomeVisitDate;
  final String? lastHomeVisitNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  /// Completed years, or null when no birth date was recorded.
  int? get ageYears {
    final birth = birthDate;
    if (birth == null) return null;
    final today = DateTime.now();
    var age = today.year - birth.year;
    final hadBirthdayThisYear = today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hadBirthdayThisYear) age -= 1;
    return age < 0 ? 0 : age;
  }

  String? get ageLabel {
    final age = ageYears;
    return age == null ? null : '$age ${AppStrings.years}';
  }

  factory Child.fromMap(Map<String, dynamic> map) => Child(
        id: asText(map['id']),
        classId: asText(map['class_id']),
        fullName: asText(map['full_name']),
        gender: Gender.fromWire(map['gender']),
        isActive: asBool(map['is_active'], true),
        birthDate: asDateOrNull(map['birth_date']),
        code: asTextOrNull(map['code']),
        mobile: asTextOrNull(map['mobile']),
        motherName: asTextOrNull(map['mother_name']),
        motherMobile: asTextOrNull(map['mother_mobile']),
        fatherName: asTextOrNull(map['father_name']),
        fatherMobile: asTextOrNull(map['father_mobile']),
        confessionFather: asTextOrNull(map['confession_father']),
        school: asTextOrNull(map['school']),
        address: asTextOrNull(map['address']),
        notes: asTextOrNull(map['notes']),
        photoPath: asTextOrNull(map['photo_path']),
        lastPhoneVisitDate: asDateOrNull(map['last_phone_visit_date']),
        lastPhoneVisitNotes: asTextOrNull(map['last_phone_visit_notes']),
        lastHomeVisitDate: asDateOrNull(map['last_home_visit_date']),
        lastHomeVisitNotes: asTextOrNull(map['last_home_visit_notes']),
        createdAt: asDateOrNull(map['created_at']),
        updatedAt: asDateOrNull(map['updated_at']),
      );

  /// Columns the client is allowed to write. Audit columns are left to the
  /// database triggers, and `photo_path` to [ChildRepository.setPhoto], so an
  /// edit or an Excel import can never blank out a photo by omission.
  Map<String, dynamic> toWriteMap() => <String, dynamic>{
        'class_id': classId,
        'full_name': fullName.trim(),
        'gender': gender.wire,
        'is_active': isActive,
        'birth_date':
            birthDate == null ? null : AppDateUtils.toIsoDate(birthDate!),
        'mobile': _nullIfBlank(mobile),
        'mother_name': _nullIfBlank(motherName),
        'mother_mobile': _nullIfBlank(motherMobile),
        'father_name': _nullIfBlank(fatherName),
        'father_mobile': _nullIfBlank(fatherMobile),
        'confession_father': _nullIfBlank(confessionFather),
        'school': _nullIfBlank(school),
        'address': _nullIfBlank(address),
        'notes': _nullIfBlank(notes),
        'last_phone_visit_date': lastPhoneVisitDate == null
            ? null
            : AppDateUtils.toIsoDate(lastPhoneVisitDate!),
        'last_phone_visit_notes': _nullIfBlank(lastPhoneVisitNotes),
        'last_home_visit_date': lastHomeVisitDate == null
            ? null
            : AppDateUtils.toIsoDate(lastHomeVisitDate!),
        'last_home_visit_notes': _nullIfBlank(lastHomeVisitNotes),
      };

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Child copyWith({
    String? id,
    String? classId,
    String? fullName,
    Gender? gender,
    bool? isActive,
    DateTime? birthDate,
    String? code,
    String? mobile,
    String? motherName,
    String? motherMobile,
    String? fatherName,
    String? fatherMobile,
    String? confessionFather,
    String? school,
    String? address,
    String? notes,
    String? photoPath,
    bool clearPhoto = false,
  }) =>
      Child(
        id: id ?? this.id,
        classId: classId ?? this.classId,
        fullName: fullName ?? this.fullName,
        gender: gender ?? this.gender,
        isActive: isActive ?? this.isActive,
        birthDate: birthDate ?? this.birthDate,
        code: code ?? this.code,
        mobile: mobile ?? this.mobile,
        motherName: motherName ?? this.motherName,
        motherMobile: motherMobile ?? this.motherMobile,
        fatherName: fatherName ?? this.fatherName,
        fatherMobile: fatherMobile ?? this.fatherMobile,
        confessionFather: confessionFather ?? this.confessionFather,
        school: school ?? this.school,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        lastPhoneVisitDate: lastPhoneVisitDate,
        lastPhoneVisitNotes: lastPhoneVisitNotes,
        lastHomeVisitDate: lastHomeVisitDate,
        lastHomeVisitNotes: lastHomeVisitNotes,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Returns a copy with the visit fields replaced. All four are required so
  /// callers can never accidentally keep a stale date when clearing notes.
  Child withVisits({
    required DateTime? phoneVisitDate,
    required String? phoneVisitNotes,
    required DateTime? homeVisitDate,
    required String? homeVisitNotes,
  }) =>
      Child(
        id: id,
        classId: classId,
        fullName: fullName,
        gender: gender,
        isActive: isActive,
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
        photoPath: photoPath,
        lastPhoneVisitDate: phoneVisitDate,
        lastPhoneVisitNotes: phoneVisitNotes,
        lastHomeVisitDate: homeVisitDate,
        lastHomeVisitNotes: homeVisitNotes,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static Child empty(String classId) => Child(
        id: '',
        classId: classId,
        fullName: '',
        gender: Gender.boy,
        isActive: true,
      );

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return fullName.toLowerCase().contains(q) ||
        (code?.toLowerCase().contains(q) ?? false) ||
        (mobile?.contains(q) ?? false) ||
        (motherName?.toLowerCase().contains(q) ?? false) ||
        (fatherName?.toLowerCase().contains(q) ?? false) ||
        (confessionFather?.toLowerCase().contains(q) ?? false) ||
        (school?.toLowerCase().contains(q) ?? false);
  }
}

/// One entry in the pastoral visit log for a child.
class ChildVisitLog {
  const ChildVisitLog({
    required this.id,
    required this.childId,
    required this.visitType,
    required this.visitDate,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String childId;

  /// Either 'phone' or 'home'.
  final String visitType;
  final DateTime visitDate;
  final String? notes;
  final DateTime createdAt;

  bool get isPhone => visitType == 'phone';

  factory ChildVisitLog.fromMap(Map<String, dynamic> map) => ChildVisitLog(
        id: asText(map['id']),
        childId: asText(map['child_id']),
        visitType: asText(map['visit_type'], 'phone'),
        visitDate: asDate(map['visit_date']),
        notes: asTextOrNull(map['notes']),
        createdAt: asDate(map['created_at']),
      );
}
