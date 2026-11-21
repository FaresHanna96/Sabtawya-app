import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/app_date_utils.dart';

void main() {
  group('isBirthdayOn', () {
    test('same month and day, any year', () {
      expect(
          AppDateUtils.isBirthdayOn(
              DateTime(2012, 11, 20), DateTime(2026, 11, 20)),
          isTrue);
      expect(
          AppDateUtils.isBirthdayOn(
              DateTime(2012, 11, 21), DateTime(2026, 11, 20)),
          isFalse);
      expect(
          AppDateUtils.isBirthdayOn(
              DateTime(2012, 10, 20), DateTime(2026, 11, 20)),
          isFalse);
    });

    test('29 February shows on the 28th in a year without one', () {
      final born = DateTime(2016, 2, 29);
      expect(AppDateUtils.isBirthdayOn(born, DateTime(2027, 2, 28)), isTrue);
      expect(AppDateUtils.isBirthdayOn(born, DateTime(2027, 3, 1)), isFalse);
    });

    test('29 February stays on the 29th in a leap year', () {
      final born = DateTime(2016, 2, 29);
      expect(AppDateUtils.isBirthdayOn(born, DateTime(2028, 2, 29)), isTrue);
      expect(AppDateUtils.isBirthdayOn(born, DateTime(2028, 2, 28)), isFalse);
    });
  });

  group('agoLabel', () {
    final now = DateTime(2026, 11, 20, 18);
    String ago(Duration d) => AppDateUtils.agoLabel(now.subtract(d), now: now);

    test('within a minute', () {
      expect(ago(const Duration(seconds: 20)), 'الآن');
    });

    test('minutes count the Arabic way', () {
      expect(ago(const Duration(minutes: 1)), 'منذ دقيقة');
      expect(ago(const Duration(minutes: 2)), 'منذ دقيقتين');
      expect(ago(const Duration(minutes: 5)), 'منذ 5 دقائق');
      expect(ago(const Duration(minutes: 15)), 'منذ 15 دقيقة');
    });

    test('hours count the Arabic way', () {
      expect(ago(const Duration(hours: 1)), 'منذ ساعة');
      expect(ago(const Duration(hours: 2)), 'منذ ساعتين');
      expect(ago(const Duration(hours: 4)), 'منذ 4 ساعات');
      expect(ago(const Duration(hours: 13)), 'منذ 13 ساعة');
    });

    test('a day or more uses the day wording', () {
      expect(ago(const Duration(days: 2)), startsWith('منذ يومين'));
    });
  });
}
