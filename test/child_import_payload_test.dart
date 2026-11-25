import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/repositories/child_repository.dart';

Child _child({String id = ''}) => Child(
      id: id,
      classId: 'class-1',
      fullName: '  مينا عادل ',
      gender: Gender.boy,
      isActive: true,
      isDeacon: true,
      birthDate: DateTime(2016, 3, 9),
      code: 'C007',
      mobile: '01000000000',
      lastPhoneVisitDate: DateTime(2026, 11, 1),
      lastHomeVisitNotes: 'زيارة',
    );

void main() {
  test('an import row carries only the columns a sheet has', () {
    final row = ChildRepository.importRow(_child());

    expect(row.keys, [
      'class_id',
      'full_name',
      'gender',
      'birth_date',
      'mobile',
      'mother_mobile',
      'father_mobile',
      'confession_father',
      'school',
      'address',
      'notes',
    ]);
    expect(row['full_name'], 'مينا عادل');
    expect(row['gender'], 'boy');
    expect(row['birth_date'], '2016-03-09');
    // The parents' names are not part of an import any more.
    expect(row.containsKey('mother_name'), isFalse);
    expect(row.containsKey('father_name'), isFalse);
  });

  test('visit dates, active flag, deacon flag and code are never written', () {
    final row = ChildRepository.importRow(_child(id: 'abc'), withId: true);

    for (final key in [
      'last_phone_visit_date',
      'last_phone_visit_notes',
      'last_home_visit_date',
      'last_home_visit_notes',
      'is_active',
      'is_deacon',
      'code',
      'photo_path',
    ]) {
      expect(row.containsKey(key), isFalse, reason: key);
    }
  });

  test('an update row carries the child id, an insert row does not', () {
    expect(ChildRepository.importRow(_child(id: 'abc'), withId: true)['id'],
        'abc');
    expect(ChildRepository.importRow(_child()).containsKey('id'), isFalse);
  });
}
