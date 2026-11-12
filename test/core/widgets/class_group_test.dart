import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/widgets/class_group_header.dart';

typedef _Kid = (String name, String classId);

const _order = ['b5', 'g5', 'b6'];
const _names = {'b5': '5 ولاد', 'g5': '5 بنات', 'b6': '6 ولاد'};

Widget _host(List<_Kid> kids, {required bool grouped}) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ClassGroupedList<_Kid>(
            items: kids,
            grouped: grouped,
            animate: false,
            classOf: (k) => k.$2,
            classOrder: _order,
            classNameOf: (id) => _names[id]!,
            itemBuilder: (context, kid, i) => Text('${i + 1}. ${kid.$1}'),
          ),
        ),
      ),
    );

void main() {
  group('groupByClass', () {
    test('follows the class order, keeps order inside, skips empty', () {
      final groups = groupByClass<_Kid>(
        [('a', 'g5'), ('b', 'b5'), ('c', 'g5'), ('d', 'x')],
        (k) => k.$2,
        _order,
      );
      expect(groups.map((g) => g.$1).toList(), ['b5', 'g5', 'x']);
      expect(groups[1].$2.map((k) => k.$1).toList(), ['a', 'c']);
    });
  });

  testWidgets('grouped: a header per class, positions restart per class',
      (tester) async {
    await tester.pumpWidget(_host(
      [('مينا', 'g5'), ('بيشوي', 'b5'), ('مريم', 'g5')],
      grouped: true,
    ));
    expect(find.byType(ClassGroupHeader), findsNWidgets(2));
    expect(find.text('5 ولاد'), findsOneWidget);
    expect(find.text('5 بنات'), findsOneWidget);
    expect(find.text('1. بيشوي'), findsOneWidget);
    expect(find.text('1. مينا'), findsOneWidget);
    expect(find.text('2. مريم'), findsOneWidget);
    // 5 ولاد comes before 5 بنات, as in the class order.
    expect(
      tester.getTopLeft(find.text('5 ولاد')).dy,
      lessThan(tester.getTopLeft(find.text('5 بنات')).dy),
    );
  });

  testWidgets('not grouped: one plain list, no headers', (tester) async {
    await tester.pumpWidget(_host(
      [('مينا', 'g5'), ('بيشوي', 'b5')],
      grouped: false,
    ));
    expect(find.byType(ClassGroupHeader), findsNothing);
    expect(find.text('2. بيشوي'), findsOneWidget);
  });
}
