import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/repositories/servant_activity_repository.dart';

void main() {
  const rule = ServantActivityRepository.classesWithPrep;

  test('a prep uploaded for the class counts', () {
    expect(rule({'a'}, const [], {}), {'a'});
  });

  test('a servant ticked by the admin counts for their class', () {
    expect(
      rule(
        {},
        const [
          (servantId: 's1', classId: 'a'),
          (servantId: 's2', classId: 'b'),
        ],
        {'s1'},
      ),
      {'a'},
    );
  });

  test('either one is enough, and both together are not counted twice', () {
    expect(
      rule(
        {'a'},
        const [
          (servantId: 's1', classId: 'a'),
          (servantId: 's3', classId: 'c'),
        ],
        {'s1', 's3'},
      ),
      {'a', 'c'},
    );
  });

  test('a ticked servant with no class (a general servant) adds nothing', () {
    expect(rule({}, const [], {'s9'}), isEmpty);
  });

  test('an unticked servant of a class does not make it done', () {
    expect(
      rule({}, const [(servantId: 's1', classId: 'a')], {}),
      isEmpty,
    );
  });
}
