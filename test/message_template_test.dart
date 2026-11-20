import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/message_template.dart';
import 'package:sabtawya/data/models/child.dart';

Child kid(String id, String name,
        {String cls = 'c1', String? mother, String? father, String? own}) =>
    Child(
      id: id,
      classId: cls,
      fullName: name,
      gender: Gender.boy,
      isActive: true,
      motherMobile: mother,
      fatherMobile: father,
      mobile: own,
    );

void main() {
  group('first names', () {
    test('one, two and three children', () {
      expect(ParentMessages.firstNames([kid('a', 'مينا عادل')]), 'مينا');
      expect(
        ParentMessages.firstNames([kid('a', 'مينا عادل'), kid('b', 'مريم عادل')]),
        'مينا ومريم',
      );
      expect(
        ParentMessages.firstNames([
          kid('a', 'مينا عادل'),
          kid('b', 'جورج عادل'),
          kid('c', 'مريم عادل'),
        ]),
        'مينا وجورج ومريم',
      );
    });
  });

  group('fill', () {
    test('every placeholder is replaced', () {
      final text = ParentMessages.fill(
        '$kServantTag/$kChildTag/$kClassTag/$kEventTag/$kRemainingTag',
        children: [kid('a', 'مينا عادل')],
        servantName: 'بيتر',
        className: '5 ولاد',
        eventTitle: 'رحلة الدير',
        remaining: 150,
      );
      expect(text, 'بيتر/مينا/5 ولاد/رحلة الدير/150 جنيه');
    });

    test('no raw tag is left for a value not known here', () {
      final text = ParentMessages.fill(
        'خدمة السبت ($kClassTag). باقي $kRemainingTag لـ $kEventTag',
        children: [kid('a', 'مينا')],
        servantName: '',
      );
      expect(text, isNot(contains('{')));
      expect(text, isNot(contains('()')));
    });

    test('an empty servant name becomes خادم الفصل', () {
      expect(
        ParentMessages.fill(kServantTag, children: const [], servantName: ' '),
        'خادم الفصل',
      );
    });

    test('money keeps decimals only when needed', () {
      expect(ParentMessages.money(150), '150 جنيه');
      expect(ParentMessages.money(72.5), '72.50 جنيه');
    });
  });

  group('build', () {
    test('siblings on one number get one message naming both', () {
      final built = ParentMessages.build(
        [
          kid('a', 'مينا عادل', mother: '01011111111'),
          kid('b', 'مريم عادل', mother: '+201011111111'),
          kid('c', 'جورج سمير', father: '01122222222'),
        ],
        body: 'افتقدنا $kChildTag',
        servantName: 'بيتر',
      );
      expect(built.families, hasLength(2));
      expect(built.families.first.text, 'افتقدنا مينا ومريم');
      expect(built.families.first.number, '201011111111');
      expect(built.families.last.text, 'افتقدنا جورج');
      expect(built.noNumber, isEmpty);
    });

    test('children with no usable number are listed apart', () {
      final built = ParentMessages.build(
        [kid('a', 'مينا', mother: '123'), kid('b', 'مريم')],
        body: 'x',
        servantName: '',
      );
      expect(built.families, isEmpty);
      expect(built.noNumber.map((c) => c.id), ['a', 'b']);
    });

    test('what siblings owe is added up', () {
      final built = ParentMessages.build(
        [
          kid('a', 'مينا', mother: '01011111111'),
          kid('b', 'مريم', mother: '01011111111'),
        ],
        body: kRemainingTag,
        servantName: '',
        remainingByChild: const {'a': 100, 'b': 50},
      );
      expect(built.families.single.text, '150 جنيه');
    });

    test('the class name comes from the first child of the family', () {
      final built = ParentMessages.build(
        [kid('a', 'مينا', cls: 'c9', mother: '01011111111')],
        body: kClassTag,
        servantName: '',
        classNames: const {'c9': '6 بنات'},
      );
      expect(built.families.single.text, '6 بنات');
    });

    test('the WhatsApp link carries the message', () {
      final f = ParentMessages.build(
        [kid('a', 'مينا', mother: '01011111111')],
        body: 'سلام',
        servantName: '',
      ).families.single;
      expect(f.link.host, 'wa.me');
      expect(f.link.path, '/201011111111');
      expect(f.link.queryParameters['text'], 'سلام');
    });
  });

  test('event templates are marked event-only; the others are not', () {
    final eventOnly = {
      for (final t in kBuiltInTemplates)
        if (t.eventOnly) t.title,
    };
    expect(eventOnly, {kEventReminderTitle, kPaymentReminderTitle});
    for (final t in kBuiltInTemplates.where((t) => !t.eventOnly)) {
      expect(t.body, isNot(contains(kEventTag)));
      expect(t.body, isNot(contains(kRemainingTag)));
    }
  });
}
