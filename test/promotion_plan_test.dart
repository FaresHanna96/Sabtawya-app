import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/school_class.dart';

void main() {
  final answer = <String, dynamic>{
    'dryRun': true,
    'archived': [
      {'name': '6 ولاد', 'to': '6 ولاد 2026 - 2027', 'children': 11},
    ],
    'moves': [
      {'from': '5 ولاد', 'to': '6 ولاد', 'children': 14},
      {'from': '4 ولاد', 'to': '5 ولاد', 'children': 9},
    ],
    'created': ['3 ولاد', '3 بنات'],
  };

  test('reads what the database answers', () {
    final plan = PromotionPlan.fromMap(answer);

    expect(plan.moves.map((m) => '${m.from}>${m.to}:${m.children}'),
        ['5 ولاد>6 ولاد:14', '4 ولاد>5 ولاد:9']);
    expect(plan.archived.single.from, '6 ولاد');
    expect(plan.archived.single.children, 11);
    expect(plan.created, ['3 ولاد', '3 بنات']);
  });

  test('says in words what will happen, with the numbers of children', () {
    final text = PromotionPlan.fromMap(answer).describe();

    expect(text, contains('• 5 ولاد ← 6 ولاد (14 مخدوم)'));
    expect(text, contains('• 4 ولاد ← 5 ولاد (9 مخدوم)'));
    expect(text, contains('يُؤرشفون مع مخدوميهم:'));
    expect(text, contains('• 6 ولاد (11 مخدوم)'));
    expect(text, contains('تُضاف فصول جديدة: 3 ولاد، 3 بنات'));
    // The graduating class is listed after the ones that move.
    expect(text.indexOf('ينتقلون'), lessThan(text.indexOf('يُؤرشفون')));
  });

  test('a missing part reads as nothing, not as a crash', () {
    final plan = PromotionPlan.fromMap({
      'created': ['3 ولاد']
    });
    expect(plan.moves, isEmpty);
    expect(plan.archived, isEmpty);
    expect(plan.describe(), 'تُضاف فصول جديدة: 3 ولاد');
  });
}
