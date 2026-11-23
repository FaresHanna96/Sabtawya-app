import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/app_date_utils.dart';
import 'package:sabtawya/data/models/school_class.dart';

ClassOverview _c(String id, String name) => ClassOverview(
      classId: id,
      className: name,
      sortOrder: 0,
      isActive: true,
      activeChildren: 0,
      boysCount: 0,
      girlsCount: 0,
      servantsCount: 0,
    );

void main() {
  test('nextSaturday: Saturday stays, other days move forward', () {
    expect(AppDateUtils.nextSaturday(DateTime(2026, 11, 28)),
        DateTime(2026, 11, 28));
    expect(AppDateUtils.nextSaturday(DateTime(2026, 11, 23, 15)),
        DateTime(2026, 11, 28));
    expect(AppDateUtils.nextSaturday(DateTime(2026, 11, 29)),
        DateTime(2026, 12, 5));
  });

  test('nameOf finds a class name or returns null', () {
    final list = [_c('a', 'أولى'), _c('b', 'ثانية')];
    expect(list.nameOf('b'), 'ثانية');
    expect(list.nameOf('x'), isNull);
  });
}
