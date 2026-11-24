import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/widgets/date_picker.dart';

Future<void> _open(
  WidgetTester tester,
  void Function(DateTime?) onResult, {
  DatePickerMode mode = DatePickerMode.day,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => onResult(await pickDate(
          context: context,
          initialDate: DateTime(2026, 11, 24),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDatePickerMode: mode,
        )),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a day picks it at once, no OK button', (tester) async {
    DateTime? result;
    var done = false;
    await _open(tester, (d) {
      result = d;
      done = true;
    });
    expect(find.text('OK'), findsNothing);
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result, DateTime(2026, 11, 10));
  });

  testWidgets('the close button picks nothing', (tester) async {
    DateTime? result = DateTime(1999);
    var done = false;
    await _open(tester, (d) {
      result = d;
      done = true;
    });
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result, isNull);
  });

  testWidgets('starting on years: the year is a step, the day is the answer',
      (tester) async {
    DateTime? result;
    var done = false;
    await _open(tester, (d) {
      result = d;
      done = true;
    }, mode: DatePickerMode.year);
    await tester.tap(find.text('2024'));
    await tester.pumpAndSettle();
    expect(done, isFalse, reason: 'picking a year must not close the dialog');
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result, DateTime(2024, 11, 15));
  });
}
