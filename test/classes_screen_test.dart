import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/school_class.dart';
import 'package:sabtawya/features/classes/classes_screen.dart';

ClassOverview _class(String id) => ClassOverview(
      classId: id,
      className: 'فصل $id',
      sortOrder: 0,
      isActive: true,
      activeChildren: 10,
      boysCount: 10,
      girlsCount: 0,
      servantsCount: 2,
    );

void main() {
  group('the Classes tab opens the class itself', () {
    test('for a servant with one class', () {
      final only = ClassesScreen.onlyClass(
        everyClass: false,
        mine: [_class('a')],
      );
      expect(only?.classId, 'a');
    });

    test('not for a servant with two classes: they pick one', () {
      expect(
        ClassesScreen.onlyClass(
            everyClass: false, mine: [_class('a'), _class('b')]),
        isNull,
      );
    });

    test('not for a servant with no class (the empty state explains)', () {
      expect(ClassesScreen.onlyClass(everyClass: false, mine: []), isNull);
    });

    test('never for an admin or general servant, even with one class', () {
      expect(
        ClassesScreen.onlyClass(everyClass: true, mine: [_class('a')]),
        isNull,
      );
    });
  });
}
