import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/map_location.dart';
import 'package:sabtawya/features/children/child_location_card.dart';

void main() {
  for (final w in [360.0, 320.0, 280.0]) {
    testWidgets('the location card fits a $w px wide phone, buttons in view',
        (tester) async {
      tester.view.physicalSize = Size(w, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ChildLocationCard(
                location: const MapLocation(30.05, 31.34),
                address: 'عنوان تجريبي 4 شارع طويل جدا جدا جدا',
                onSet: () {},
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.byIcon(Icons.directions_rounded), findsOneWidget);
    });
  }
}
