import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/arabic_sort.dart';

void main() {
  List<String> sorted(List<String> names) =>
      [...names]..sort(ArabicSort.compare);

  test('sorts in Arabic alphabet order', () {
    expect(
      sorted(['يوسف', 'نوفير', 'مينا', 'بيشوي', 'كيرلس', 'ايرينى']),
      ['ايرينى', 'بيشوي', 'كيرلس', 'مينا', 'نوفير', 'يوسف'],
    );
  });

  test('alef variants sort together with plain alef', () {
    expect(
      sorted(['بيلا', 'أندرو', 'ابانوب', 'إيمان']),
      ['ابانوب', 'أندرو', 'إيمان', 'بيلا'],
    );
  });

  test('ignores diacritics and ya/ta marbuta variants', () {
    expect(ArabicSort.key('مَرْيَم'), ArabicSort.key('مريم'));
    expect(ArabicSort.key('فاطمة'), ArabicSort.key('فاطمه'));
    expect(ArabicSort.key('موسى'), ArabicSort.key('موسي'));
  });

  test('compares names word by word as written', () {
    expect(
      sorted(['مريم سامح', 'مريم جرجس', 'مريم']),
      ['مريم', 'مريم جرجس', 'مريم سامح'],
    );
  });
}
