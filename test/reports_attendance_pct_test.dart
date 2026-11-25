import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/features/reports/reports_screen.dart';

void main() {
  test('attendance % is attended over held', () {
    expect(overallAttendancePct(39, 50), closeTo(78, 0.001));
    expect(overallAttendancePct(50, 50), 100);
  });

  test('nothing held is 0, not a division by zero', () {
    expect(overallAttendancePct(0, 0), 0);
  });
}
