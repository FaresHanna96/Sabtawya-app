import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/services/location_service.dart';
import 'package:sabtawya/core/utils/map_location.dart';
import 'package:sabtawya/data/models/child.dart';
import 'package:sabtawya/features/children/child_location_card.dart';
import 'package:sabtawya/features/children/location_editor.dart';

const _home = MapLocation(30.05611, 31.34167);

Child _child({double? lat, double? lng}) => Child(
      id: 'k',
      classId: 'c',
      fullName: 'مينا',
      gender: Gender.boy,
      isActive: true,
      latitude: lat,
      longitude: lng,
    );

void main() {
  group('the location on the child record', () {
    test('is read from the row', () {
      final c = Child.fromMap({
        'id': 'k',
        'class_id': 'c',
        'full_name': 'مينا',
        'gender': 'boy',
        'latitude': 30.05611,
        'longitude': 31.34167,
      });
      expect(c.location, _home);
    });

    test('integers from the database are fine', () {
      final c = Child.fromMap({
        'id': 'k',
        'class_id': 'c',
        'full_name': 'م',
        'gender': 'boy',
        'latitude': 30,
        'longitude': 31,
      });
      expect(c.location, const MapLocation(30, 31));
    });

    test('is absent when the row has none', () {
      final c = Child.fromMap(
          {'id': 'k', 'class_id': 'c', 'full_name': 'م', 'gender': 'boy'});
      expect(c.location, isNull);
    });

    test('is written as latitude and longitude, or both null', () {
      expect(_child(lat: 30.05611, lng: 31.34167).toWriteMap()['latitude'],
          30.05611);
      expect(_child(lat: 30.05611, lng: 31.34167).toWriteMap()['longitude'],
          31.34167);

      final none = _child().toWriteMap();
      expect(none['latitude'], isNull);
      expect(none['longitude'], isNull);
      expect(none.containsKey('latitude'), isTrue); // sent as null: cleared
    });

    test('half a place is no place', () {
      final half = _child(lat: 30.0);
      expect(half.location, isNull);
      expect(half.toWriteMap()['latitude'], isNull);
      expect(half.toWriteMap()['longitude'], isNull);
    });

    test('survives the copies made for visits and edits', () {
      final c = _child(lat: 30.05611, lng: 31.34167);
      expect(c.copyWith(fullName: 'بولا').location, _home);
      expect(
        c
            .withVisits(
              phoneVisitDate: DateTime(2026, 11, 1),
              phoneVisitNotes: null,
              homeVisitDate: null,
              homeVisitNotes: null,
            )
            .location,
        _home,
      );
    });

    test('can be replaced or cleared', () {
      final c = _child(lat: 30.05611, lng: 31.34167);
      expect(c.copyWith(location: const MapLocation(1, 2)).location,
          const MapLocation(1, 2));
      expect(c.copyWith(clearLocation: true).location, isNull);
    });
  });

  group('the card on the child page', () {
    Widget app(ChildLocationCard card) =>
        MaterialApp(home: Scaffold(body: Center(child: card)));

    testWidgets('with a place: the address, and the two buttons',
        (tester) async {
      await tester.pumpWidget(app(const ChildLocationCard(
        location: _home,
        address: 'مدينة نصر، شارع عباس العقاد',
      )));

      expect(find.text('الموقع على الخريطة'), findsOneWidget);
      expect(find.text('مدينة نصر، شارع عباس العقاد'), findsOneWidget);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.byIcon(Icons.directions_rounded), findsOneWidget);
    });

    testWidgets('with no written address it shows the coordinates',
        (tester) async {
      await tester.pumpWidget(app(const ChildLocationCard(location: _home)));
      expect(find.text('30.05611, 31.34167'), findsOneWidget);
    });

    testWidgets('no place, may edit: a prompt that opens the editor',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(app(ChildLocationCard(
        location: null,
        onSet: () => opened++,
      )));

      expect(find.text('أضف موقع بيت المخدوم على الخريطة'), findsOneWidget);
      await tester.tap(find.text('أضف موقع بيت المخدوم على الخريطة'));
      expect(opened, 1);
    });

    testWidgets('no place, may not edit: nothing', (tester) async {
      await tester.pumpWidget(app(const ChildLocationCard(location: null)));
      expect(find.byType(Text), findsNothing);
    });
  });

  group('setting it in the form', () {
    MapLocation? latest;
    var calls = 0;

    Widget editor({
      MapLocation? value,
      Future<MapLocation> Function()? fetch,
    }) {
      latest = value;
      calls = 0;
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => LocationEditor(
                value: latest,
                fetchCurrent: fetch,
                onChanged: (v) {
                  calls++;
                  setState(() => latest = v);
                },
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a pasted Google Maps link is read as it is typed',
        (tester) async {
      await tester.pumpWidget(editor());
      await tester.enterText(find.byType(TextField),
          'https://www.google.com/maps/@30.05611,31.34167,17z');
      await tester.pump();

      expect(latest, _home);
      expect(find.text('30.05611, 31.34167'), findsOneWidget);
    });

    testWidgets('plain coordinates work too', (tester) async {
      await tester.pumpWidget(editor());
      await tester.enterText(find.byType(TextField), '30.05611, 31.34167');
      await tester.pump();

      expect(latest, _home);
    });

    testWidgets('something else says what to paste, and changes nothing',
        (tester) async {
      await tester.pumpWidget(editor());
      await tester.enterText(find.byType(TextField), 'بيت مينا');
      await tester.pump();

      expect(latest, isNull);
      expect(calls, 0);
      expect(find.textContaining('مش قادرين نقرا الموقع'), findsOneWidget);
    });

    testWidgets('a shortened link explains why it cannot be read',
        (tester) async {
      await tester.pumpWidget(editor());
      await tester.enterText(
          find.byType(TextField), 'https://maps.app.goo.gl/abc123');
      await tester.pump();

      expect(latest, isNull);
      expect(find.textContaining('الرابط المختصر'), findsOneWidget);
    });

    testWidgets('clearing the text clears the message', (tester) async {
      await tester.pumpWidget(editor());
      await tester.enterText(find.byType(TextField), 'xx');
      await tester.pump();
      expect(find.textContaining('مش قادرين'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.textContaining('مش قادرين'), findsNothing);
    });

    testWidgets('the current location button fills it in', (tester) async {
      await tester.pumpWidget(editor(fetch: () async => _home));
      await tester.tap(find.text('استخدم موقعي الحالي'));
      await tester.pumpAndSettle();

      expect(latest, _home);
      expect(find.text('30.05611, 31.34167'), findsOneWidget);
    });

    testWidgets('a refused or failed location says why', (tester) async {
      await tester.pumpWidget(editor(
        fetch: () async =>
            throw const LocationFailure(LocationProblem.deniedForever),
      ));
      await tester.tap(find.text('استخدم موقعي الحالي'));
      await tester.pumpAndSettle();

      expect(latest, isNull);
      expect(find.textContaining('إذن الموقع مرفوض'), findsOneWidget);

      await tester.pumpWidget(editor(fetch: () async => throw Exception('x')));
      await tester.tap(find.text('استخدم موقعي الحالي'));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر تحديد الموقع.'), findsOneWidget);
    });

    testWidgets('a saved place is shown and can be cleared', (tester) async {
      await tester.pumpWidget(editor(value: _home));

      expect(find.text('30.05611, 31.34167'), findsOneWidget);
      await tester.tap(find.text('مسح الموقع'));
      await tester.pump();

      expect(latest, isNull);
      expect(find.text('30.05611, 31.34167'), findsNothing);
    });

    testWidgets('paste from the clipboard reads what is there', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': '30.05611, 31.34167'}
            : null,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(editor());
      await tester.tap(find.byIcon(Icons.content_paste_rounded));
      await tester.pumpAndSettle();

      expect(latest, _home);
    });
  });

  group('what is told when the phone cannot say where it is', () {
    test('each reason has its own words', () {
      final messages = {
        for (final p in LocationProblem.values) p: LocationFailure(p).message,
      };
      expect(messages.values.toSet(), hasLength(LocationProblem.values.length));
      expect(messages[LocationProblem.deniedForever], contains('إعدادات'));
      expect(messages[LocationProblem.serviceOff], contains('مقفولة'));
    });
  });
}
