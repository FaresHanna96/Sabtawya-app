import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/features/notifications/notifications_screen.dart';

void main() {
  const kinds = [
    'signup', 'announcement', 'decision', 'prep_submitted', 'prep_reviewed',
    'lesson_changed', 'birthdays', 'child_added', 'attendance_taken',
    'event_added', 'competition_added', 'class_assigned', 'class_activity',
    'missing_info', 'absence_followup', 'absence_child', 'class_removed',
    'event_today', 'attendance_missing',
  ];

  test('every kind has its own icon (none shared)', () {
    final icons = [for (final k in kinds) notificationLook(k).$1.codePoint];
    expect(icons.toSet().length, kinds.length);
  });

  test('being added to a class is no longer the lesson-prep book', () {
    expect(notificationLook('class_assigned').$1,
        isNot(notificationLook('prep_submitted').$1));
  });

  test('an unknown kind gets the plain bell', () {
    expect(notificationLook('whatever').$1, notificationLook('also-unknown').$1);
  });
}
