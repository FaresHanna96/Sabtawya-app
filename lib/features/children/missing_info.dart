import 'package:flutter/material.dart';

import '../../data/models/child.dart';

/// The pieces of a child's record the service wants filled in. The birthday
/// comes first: without it there is no birthday greeting and no age.
enum MissingField {
  birthDate('تاريخ الميلاد', Icons.cake_outlined),
  phone('رقم تليفون', Icons.phone_disabled_outlined),
  mother('اسم الأم', Icons.woman_outlined),
  father('اسم الأب', Icons.man_outlined),
  confessionFather('أب الاعتراف', Icons.church_outlined),
  school('المدرسة', Icons.school_outlined),
  address('العنوان', Icons.home_outlined);

  const MissingField(this.label, this.icon);

  final String label;
  final IconData icon;

  /// True when [child] has nothing in this field. A child needs at least one
  /// way to be reached, so [phone] is missing only when the child's own, the
  /// mother's and the father's numbers are all empty.
  bool isMissingIn(Child child) {
    bool blank(String? v) => v == null || v.trim().isEmpty;
    return switch (this) {
      MissingField.birthDate => child.birthDate == null,
      MissingField.phone => blank(child.mobile) &&
          blank(child.motherMobile) &&
          blank(child.fatherMobile),
      MissingField.mother => blank(child.motherName),
      MissingField.father => blank(child.fatherName),
      MissingField.confessionFather => blank(child.confessionFather),
      MissingField.school => blank(child.school),
      MissingField.address => blank(child.address),
    };
  }
}

/// What is missing from the children, counted and filtered.
class MissingInfo {
  const MissingInfo._();

  /// The fields [child] is missing, in the order of [MissingField].
  static List<MissingField> of(Child child) => [
        for (final f in MissingField.values)
          if (f.isMissingIn(child)) f,
      ];

  /// How many of [children] miss each field.
  static Map<MissingField, int> counts(Iterable<Child> children) {
    final out = {for (final f in MissingField.values) f: 0};
    for (final c in children) {
      for (final f in of(c)) {
        out[f] = out[f]! + 1;
      }
    }
    return out;
  }

  /// The children missing [field] (any field when null), in the order given.
  static List<Child> filter(Iterable<Child> children, MissingField? field) => [
        for (final c in children)
          if (field == null ? of(c).isNotEmpty : field.isMissingIn(c)) c,
      ];
}
