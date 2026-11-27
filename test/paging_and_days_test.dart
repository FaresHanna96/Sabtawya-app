import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/app_date_utils.dart';
import 'package:sabtawya/data/models/event.dart';
import 'package:sabtawya/data/supabase/db.dart';

void main() {
  test('every page is read, past the 1000 the server returns at once',
      () async {
    final server = [for (var i = 0; i < 2300; i++) <String, dynamic>{'i': i}];
    final asked = <(int, int)>[];
    final got = await allRows((from, to) async {
      asked.add((from, to));
      return server.skip(from).take(to - from + 1).toList();
    });
    expect(got, hasLength(2300));
    expect(got.last['i'], 2299);
    expect(asked, [(0, 999), (1000, 1999), (2000, 2999)]);
  });

  test('an exact page is followed by one empty read', () async {
    var reads = 0;
    final got = await allRows(
        (from, _) async =>
            reads++ == 0 ? [<String, dynamic>{}, <String, dynamic>{}] : [],
        size: 2);
    expect(got, hasLength(2));
    expect(reads, 2);
  });

  test('days are counted on the calendar, not in 24-hour blocks', () {
    // Egypt moves the clocks on the last Friday of April and of October.
    expect(
        AppDateUtils.daysBetween(
            DateTime(2027, 4, 29, 23), DateTime(2027, 5, 1)),
        2);
    expect(
        AppDateUtils.daysBetween(
            DateTime(2026, 10, 31), DateTime(2026, 10, 29, 23)),
        -2);
    expect(AppDateUtils.lastSaturday(DateTime(2027, 5, 6)),
        DateTime(2027, 5, 1));
  });

  test('a payment time from the server is shown in local time', () {
    final p = EventPayment.fromMap(const {'paid_at': '2026-11-27T22:30:00Z'});
    expect(p.paidAt.isUtc, isFalse);
    expect(p.paidAt.toUtc(), DateTime.utc(2026, 11, 27, 22, 30));
  });
}
