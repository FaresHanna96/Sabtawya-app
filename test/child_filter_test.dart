import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/badges.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/children/child_filters.dart';

Child _child({
  required String name,
  Gender gender = Gender.boy,
  bool isActive = true,
  DateTime? birthDate,
  String? code,
  String? mobile,
}) =>
    Child(
      id: name,
      classId: 'class-1',
      fullName: name,
      gender: gender,
      isActive: isActive,
      birthDate: birthDate,
      code: code,
      mobile: mobile,
    );

void main() {
  final roster = <Child>[
    _child(
      name: 'مينا',
      birthDate: DateTime(2016, 1, 1),
      code: 'C-001',
      mobile: '01000000001',
    ),
    _child(
      name: 'مريم',
      gender: Gender.girl,
      birthDate: DateTime(2012, 1, 1),
    ),
    _child(name: 'كيرلس', isActive: false),
  ];

  group('ChildFilter', () {
    test('hides inactive children by default', () {
      final result = const ChildFilter().apply(roster);

      expect(result.map((child) => child.fullName), ['مريم', 'مينا']);
    });

    test('includes inactive children when asked', () {
      final result = const ChildFilter(includeInactive: true).apply(roster);

      expect(result.length, 3);
    });

    test('filters by gender', () {
      final result = const ChildFilter(gender: Gender.girl).apply(roster);

      expect(result.single.fullName, 'مريم');
    });

    test('searches name, code, and mobile', () {
      expect(const ChildFilter(query: 'C-001').apply(roster).single.fullName,
          'مينا');
      expect(const ChildFilter(query: '0000001').apply(roster).single.fullName,
          'مينا');
      expect(const ChildFilter(query: 'مريم').apply(roster).single.fullName,
          'مريم');
    });

    test('sorts by age, oldest last, and children with no birth date last', () {
      final result = const ChildFilter(
        sort: ChildSort.age,
        includeInactive: true,
      ).apply(roster);

      expect(result.map((child) => child.fullName), ['مينا', 'مريم', 'كيرلس']);
    });

    test('reversing the sort keeps undated children last', () {
      final result = const ChildFilter(
        sort: ChildSort.age,
        ascending: false,
        includeInactive: true,
      ).apply(roster);

      expect(result.first.fullName, 'كيرلس');
    });

    test('isNarrowing only reports an actual narrowing', () {
      expect(const ChildFilter().isNarrowing, isFalse);
      expect(const ChildFilter(sort: ChildSort.age).isNarrowing, isFalse);
      expect(const ChildFilter(query: 'م').isNarrowing, isTrue);
      expect(const ChildFilter(gender: Gender.boy).isNarrowing, isTrue);
    });

    test('copyWith can clear the gender', () {
      const filter = ChildFilter(gender: Gender.boy);

      expect(filter.copyWith(clearGender: true).gender, isNull);
    });
  });

  group('Gender.tryParse', () {
    test('accepts Arabic and English spellings', () {
      expect(Gender.tryParse('ولد'), Gender.boy);
      expect(Gender.tryParse('بنت'), Gender.girl);
      expect(Gender.tryParse('Male'), Gender.boy);
      expect(Gender.tryParse('f'), Gender.girl);
    });

    test('returns null for anything it cannot read', () {
      expect(Gender.tryParse(null), isNull);
      expect(Gender.tryParse(''), isNull);
      expect(Gender.tryParse('؟'), isNull);
    });
  });

  group('Child', () {
    test('ageYears only counts completed years', () {
      final today = DateTime.now();
      final almost = _child(
        name: 'x',
        birthDate: DateTime(today.year - 8, today.month, today.day)
            .add(const Duration(days: 1)),
      );

      expect(almost.ageYears, 7);
    });

    test('photo_path is not part of the writable columns', () {
      // Keeping it out is what stops an edit or an import from dropping a photo.
      final child = _child(name: 'x').copyWith(photoPath: 'id/1.jpg');

      expect(child.photoPath, 'id/1.jpg');
      expect(child.toWriteMap().containsKey('photo_path'), isFalse);
    });

    test('code is issued by the database, never written by the client', () {
      final child = _child(name: 'x', code: 'C001');

      expect(child.code, 'C001');
      expect(child.toWriteMap().containsKey('code'), isFalse);
    });
  });

  group('badge filter', () {
    final kids = [_child(name: 'مينا'), _child(name: 'مارك'), _child(name: 'بيتر')];

    test('keeps only the holders of the picked badge', () {
      const filter = ChildFilter(badge: KidBadge.vespersMonth);
      expect(
        filter.apply(kids, holders: {'مارك'}).map((c) => c.id),
        ['مارك'],
      );
      // Another badge, another holder set: it narrows again.
      const other = ChildFilter(badge: KidBadge.starSchool);
      expect(
        other.apply(kids, holders: {'بيتر', 'مينا'}).map((c) => c.id).toSet(),
        {'بيتر', 'مينا'},
      );
    });

    test('shows everyone while the holders are still loading', () {
      const filter = ChildFilter(badge: KidBadge.starYear);
      expect(filter.apply(kids).length, 3);
    });

    test('clearBadge removes it and isNarrowing follows', () {
      const filter = ChildFilter(badge: KidBadge.starYear);
      expect(filter.isNarrowing, isTrue);
      final cleared = filter.copyWith(clearBadge: true);
      expect(cleared.badge, isNull);
      expect(cleared.isNarrowing, isFalse);
    });
  });

  group('quick chips', () {
    final now = DateTime(2026, 11, 25);
    final kids = [
      Child(
        id: 'أ',
        classId: 'class-1',
        fullName: 'أ',
        gender: Gender.boy,
        isActive: true,
        birthDate: DateTime(2016, 11, 3),
        mobile: '010',
        motherName: 'م',
        fatherName: 'ب',
        confessionFather: 'أبونا',
        school: 'مدرسة',
        address: 'عنوان',
      ),
      _child(name: 'ب', birthDate: DateTime(2016, 5, 3)),
      _child(name: 'ج'),
    ];

    test('birthday this month keeps only that month', () {
      const f = ChildFilter(quick: QuickFilter.birthdayMonth);
      expect(f.apply(kids, now: now).map((c) => c.id), ['أ']);
    });

    test('missing data keeps children with an empty field', () {
      const f = ChildFilter(quick: QuickFilter.missingInfo);
      expect(f.apply(kids).map((c) => c.id).toSet(), {'ب', 'ج'});
    });

    test('absent uses the ids, and waits while they load', () {
      const f = ChildFilter(quick: QuickFilter.absent);
      expect(f.apply(kids, absentIds: {'ج'}).map((c) => c.id), ['ج']);
      expect(f.apply(kids).length, 3);
    });

    test('a chip narrows, and clearQuick removes it', () {
      const f = ChildFilter(quick: QuickFilter.absent);
      expect(f.isNarrowing, isTrue);
      expect(f.copyWith(clearQuick: true).isNarrowing, isFalse);
    });
  });
}
