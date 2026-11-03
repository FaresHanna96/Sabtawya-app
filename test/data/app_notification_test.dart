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
}
