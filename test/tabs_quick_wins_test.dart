import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/data/models/attendance.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/data/models/servant_activity.dart';
import 'package:sabtawya/features/children/child_filters.dart';
import 'package:sabtawya/features/servant_activities/admin_servant_activities_screen.dart';
import 'package:sabtawya/features/servant_activities/my_activities_screen.dart';

Child _child(String name, {String? mobile, String? mother}) => Child(
      id: name,
      classId: 'class-1',
      fullName: name,
      gender: Gender.boy,
      isActive: true,
      mobile: mobile,
      motherName: mother,
    );

LessonPrep _prep(String status) => LessonPrep(
      id: 'p1',
      servantId: 's1',
      servantName: 'مينا',
      sessionId: 'x',
      sessionDate: DateTime(2026, 11, 14),
      status: status,
      photos: const [],
    );

AttendanceSession _session(String id, DateTime date) => AttendanceSession(
      id: id,
      yearId: 'y',
      classId: 'c',
      sessionDate: date,
      isLocked: false,
    );

void main() {
  group('child search ignores spelling variants', () {
    test('أ / إ / آ and ا match each other', () {
      expect(_child('أحمد سمير').matches('احمد'), isTrue);
      expect(_child('احمد سمير').matches('أحمد'), isTrue);
      expect(_child('إيليا').matches('ايليا'), isTrue);
      expect(_child('آدم').matches('ادم'), isTrue);
    });

    test('ة / ه and ى / ي match, and tashkeel is ignored', () {
      expect(_child('ماريه').matches('مارية'), isTrue);
      expect(_child('مُنى').matches('مني'), isTrue);
    });

    test('a mother\'s name is searched the same way', () {
      expect(_child('بيشوي', mother: 'أمل').matches('امل'), isTrue);
    });

    test('a mobile matches with spaces or dashes in the query', () {
      final c = _child('مينا', mobile: '01234567890');
      expect(c.matches('0123 456'), isTrue);
      expect(c.matches('456-789'), isTrue);
      expect(c.matches('999'), isFalse);
    });

    test('an empty query matches everyone', () {
      expect(_child('مينا').matches('  '), isTrue);
    });
  });

  test('names sort in Arabic order with letter variants together', () {
    final sorted = const ChildFilter().apply([
      _child('بولا'),
      _child('إبرام'),
      _child('أندرو'),
      _child('ابانوب'),
    ]).map((c) => c.fullName);
    // ابانوب, إبرام, أندرو (all ا) before بولا.
    expect(sorted.last, 'بولا');
    expect(sorted.take(3).toSet(), {'ابانوب', 'إبرام', 'أندرو'});
    expect(sorted.first, 'ابانوب');
  });

  group('the تحضير chip shows the review status', () {
    test('pending is orange and waiting', () {
      final l = prepChipLook(_prep('pending'), manualPresent: false);
      expect(l.color, AppColors.warning);
      expect(l.status, 'قيد المراجعة');
    });

    test('accepted is green', () {
      expect(prepChipLook(_prep('accepted'), manualPresent: false).color,
          AppColors.success);
    });

    test('commented is sky', () {
      expect(prepChipLook(_prep('commented'), manualPresent: false).color,
          AppColors.sky);
    });

    test('marked by hand without a prep is green; nothing is muted', () {
      expect(prepChipLook(null, manualPresent: true).color, AppColors.success);
      expect(prepChipLook(null, manualPresent: false).color, AppColors.muted);
    });
  });

  group('نشاطي orders the Saturdays', () {
    final today = DateTime(2026, 11, 21);
    final sessions = [
      _session('oct3', DateTime(2026, 10, 3)),
      _session('oct10', DateTime(2026, 10, 10)),
      _session('oct17', DateTime(2026, 10, 17)),
      _session('nov7', DateTime(2026, 11, 7)),
      _session('nov14', DateTime(2026, 11, 14)),
      _session('nov21', DateTime(2026, 11, 21)),
      _session('nov28', DateTime(2026, 11, 28)),
    ];
    final sent = {'oct3', 'oct17', 'nov14'};
    final g = PrepGroups.of(sessions,
        hasPrep: sent.contains, today: today);

    test('today is the Saturday to prepare', () {
      expect(g.current?.id, 'nov21');
    });

    test('past ones with no prep come first, newest first', () {
      expect(g.missed.map((s) => s.id), ['nov7', 'oct10']);
    });

    test('the other past ones are newest first', () {
      expect(g.past.map((s) => s.id), ['nov14', 'oct17', 'oct3']);
    });

    test('the rest of the year follows', () {
      expect(g.later.map((s) => s.id), ['nov28']);
    });
  });
}
