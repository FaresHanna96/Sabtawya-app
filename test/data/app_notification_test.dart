import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/data/models/app_notification.dart';

void main() {
  test('parses an unread notification', () {
    final n = AppNotification.fromMap({
      'id': 'n1',
      'kind': 'signup',
      'title': 'طلب انضمام جديد',
      'body': 'مينا يطلب الانضمام للخدمة',
      'created_at': '2026-11-04T10:00:00Z',
      'read_at': null,
    });
    expect(n.kind, 'signup');
    expect(n.isRead, isFalse);
    expect(n.title, 'طلب انضمام جديد');
  });

  test('a notification with read_at is read', () {
    final n = AppNotification.fromMap({
      'id': 'n2',
      'kind': 'prep_reviewed',
      'title': 'تم قبول تحضيرك',
      'body': '',
      'created_at': '2026-11-04T10:00:00Z',
      'read_at': '2026-11-04T11:00:00Z',
    });
    expect(n.isRead, isTrue);
  });

  group('the day a notification is about', () {
    AppNotification withBody(String body) => AppNotification.fromMap({
          'id': 'n',
          'kind': 'attendance_taken',
          'title': 'تم تسجيل الحضور',
          'body': body,
          'created_at': '2026-11-15T10:00:00Z',
        });

    test('day first, as the bell shows it', () {
      final n =
          withBody('ايلاريا عادل لبيب سجّل حضور فصل 3 بنات ليوم 31-10-2026');
      expect(n.mentionedDate, DateTime(2026, 10, 31));
    });

    test('year first, as older entries were written', () {
      final n = withBody('مينا سجّل حضور فصل 5 ولاد ليوم 2026-10-24');
      expect(n.mentionedDate, DateTime(2026, 10, 24));
    });

    test('the class number is not taken for part of the date', () {
      final n = withBody('مينا سجّل حضور فصل 3 بنات ليوم 7-11-2026');
      expect(n.mentionedDate, DateTime(2026, 11, 7));
    });

    test('no date, or an impossible one, gives none', () {
      expect(withBody('أصبحت من خدام فصل 4 ولاد').mentionedDate, isNull);
      expect(withBody('ليوم 31-02-2026').mentionedDate, isNull);
    });
  });
}
