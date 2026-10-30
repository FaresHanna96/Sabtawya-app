import '../../core/l10n/app_strings.dart';
import 'child.dart';
import 'parsers.dart';

/// What an account may do.
///
/// Only two, because خادم and خادمة are the same permissions with different
/// wording; the difference is [Profile.gender], not the role.
enum AppRole {
  admin('admin', AppStrings.roleAdmin),
  servant('servant', AppStrings.roleServant);

  const AppRole(this.wire, this.label);

  final String wire;
  final String label;

  /// أمين الخدمة, or خادم / خادمة according to [gender].
  String labelFor(Gender? gender) {
    if (this == AppRole.admin) return AppStrings.roleAdmin;
    return gender == Gender.girl
        ? AppStrings.roleServantFemale
        : AppStrings.roleServant;
  }

  static AppRole fromWire(dynamic value) => AppRole.values.firstWhere(
        (role) => role.wire == value?.toString(),
        orElse: () => AppRole.servant,
      );
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.email,
    this.mobile,
    this.gender,
    this.createdAt,
    this.rejectedAt,
  });

  final String id;
  final String fullName;
  final AppRole role;
  final bool isActive;
  final String? email;
  final String? mobile;

  /// Only wording: خادم or خادمة. Null for an account that never said.
  final Gender? gender;
  final DateTime? createdAt;

  /// Set when an admin refused the sign-up request.
  final DateTime? rejectedAt;

  bool get isAdmin => role == AppRole.admin;

  bool get isRejected => rejectedAt != null;

  String get roleLabel => role.labelFor(gender);

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: asText(map['id']),
        fullName: asText(map['full_name'], AppStrings.unknown),
        role: AppRole.fromWire(map['role']),
        isActive: asBool(map['is_active'], true),
        email: asTextOrNull(map['email']),
        mobile: asTextOrNull(map['mobile']),
        gender: Gender.tryParse(map['gender']),
        createdAt: asDateOrNull(map['created_at']),
        rejectedAt: asDateOrNull(map['rejected_at']),
      );
}

/// A row of `v_pending_servants`: a sign-up waiting for the admin's decision.
class PendingServant {
  const PendingServant({
    required this.id,
    required this.fullName,
    required this.requestedAt,
    this.email,
    this.mobile,
    this.gender,
  });

  final String id;
  final String fullName;
  final DateTime requestedAt;
  final String? email;
  final String? mobile;
  final Gender? gender;

  String get roleLabel => AppRole.servant.labelFor(gender);

  factory PendingServant.fromMap(Map<String, dynamic> map) => PendingServant(
        id: asText(map['id']),
        fullName: asText(map['full_name'], AppStrings.unknown),
        requestedAt: asDate(map['created_at']),
        email: asTextOrNull(map['email']),
        mobile: asTextOrNull(map['mobile']),
        gender: Gender.tryParse(map['gender']),
      );
}

/// An admin-created invite. The servant's account is activated and assigned to
/// its classes automatically when they sign up with this email.
class ServantInvite {
  const ServantInvite({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.classIds,
    this.mobile,
    this.createdAt,
    this.acceptedAt,
  });

  final String id;
  final String email;
  final String fullName;
  final AppRole role;
  final List<String> classIds;
  final String? mobile;
  final DateTime? createdAt;
  final DateTime? acceptedAt;

  bool get isPending => acceptedAt == null;

  factory ServantInvite.fromMap(Map<String, dynamic> map) => ServantInvite(
        id: asText(map['id']),
        email: asText(map['email']),
        fullName: asText(map['full_name']),
        role: AppRole.fromWire(map['role']),
        classIds: (map['class_ids'] as List<dynamic>? ?? const <dynamic>[])
            .map(asText)
            .where((id) => id.isNotEmpty)
            .toList(),
        mobile: asTextOrNull(map['mobile']),
        createdAt: asDateOrNull(map['created_at']),
        acceptedAt: asDateOrNull(map['accepted_at']),
      );
}

/// A row of `v_class_servants`: one servant attached to one class.
class ClassServant {
  const ClassServant({
    required this.assignmentId,
    required this.classId,
    required this.className,
    required this.servantId,
    required this.servantName,
    required this.servantIsActive,
    this.servantEmail,
    this.servantMobile,
  });

  final String assignmentId;
  final String classId;
  final String className;
  final String servantId;
  final String servantName;
  final bool servantIsActive;
  final String? servantEmail;
  final String? servantMobile;

  factory ClassServant.fromMap(Map<String, dynamic> map) => ClassServant(
        assignmentId: asText(map['assignment_id']),
        classId: asText(map['class_id']),
        className: asText(map['class_name']),
        servantId: asText(map['servant_id']),
        servantName: asText(map['servant_name'], AppStrings.unknown),
        servantIsActive: asBool(map['servant_is_active'], true),
        servantEmail: asTextOrNull(map['servant_email']),
        servantMobile: asTextOrNull(map['servant_mobile']),
      );
}
