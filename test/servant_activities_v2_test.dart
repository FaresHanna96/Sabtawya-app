import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sabtawya/core/l10n/app_strings.dart';
import 'package:sabtawya/core/theme/app_theme.dart';
import 'package:sabtawya/core/utils/file_kind.dart';
import 'package:sabtawya/core/widgets/file_fallback.dart';
import 'package:sabtawya/data/models/servant_activity.dart';
import 'package:sabtawya/features/servant_activities/admin_servant_activities_screen.dart';
import 'package:sabtawya/features/servant_activities/my_activities_screen.dart';
import 'package:sabtawya/features/servant_activities/prep_files.dart';
import 'package:sabtawya/features/servant_activities/prep_review_sheet.dart';
import 'package:sabtawya/features/servant_activities/servant_marks.dart';

final _pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37]);
final _jpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0]);
final _heic = Uint8List.fromList(
    [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]);

PickedPrepFile _file(String name, Uint8List bytes) =>
    // As in the app: on Android / iOS an XFile's name comes from its path.
    PickedPrepFile(XFile.fromData(bytes, name: name, path: name), bytes);

LessonPrep _prep(String status, {bool shared = false}) => LessonPrep(
      id: 'p1',
      servantId: 's1',
      servantName: 'مينا',
      sessionId: 'x',
      sessionDate: DateTime(2026, 11, 28),
      status: status,
      photos: const [],
      sharedAt: shared ? DateTime(2026, 11, 20) : null,
    );

ServantActivitySummary _summary(
  String name, {
  int ss = 0,
  int meeting = 0,
  int mass = 0,
  int conf = 0,
  int preps = 0,
  int pending = 0,
  int classes = 1,
}) =>
    ServantActivitySummary(
      servantId: name,
      servantName: name,
      totalPreps: preps,
      pendingPreps: pending,
      sundaySchoolCount: ss,
      servantMeetingCount: meeting,
      massCount: mass,
      confessionCount: conf,
      classesCount: classes,
    );

Widget _rtl(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('what a file really is (by its first bytes)', () {
    test('PDF, JPEG, PNG, HEIC and unknown', () {
      expect(FileKind.of(_pdf), FileKind.pdf);
      expect(FileKind.of(_jpg), FileKind.jpeg);
      expect(FileKind.of(_png), FileKind.png);
      expect(FileKind.of(_heic), FileKind.heic);
      expect(FileKind.of([1, 2, 3]), FileKind.unknown);
    });

    test('a PDF keeps its extension whatever it was called', () {
      expect(FileKind.of(_pdf).extension, 'pdf');
      expect(FileKind.of(_pdf).mimeType, 'application/pdf');
    });
  });

  group('picked prep files', () {
    test('a "photo" that is really a PDF counts as a PDF', () {
      expect(_file('IMG_0001.jpg', _pdf).isPdf, isTrue);
      expect(_file('scan.pdf', _jpg).isPdf, isTrue); // by its name
      expect(_file('IMG_0002.jpg', _jpg).isPdf, isFalse);
    });

    test('the summary line counts photos, PDFs and the size', () {
      final files = [
        _file('a.jpg', Uint8List(1024 * 1024)),
        _file('b.jpg', Uint8List(1024 * 1024)),
        _file('c.jpg', _jpg),
        _file('d.pdf', _pdf),
      ];
      expect(pickedSummary(files), '3 صور + ملف PDF · 2.0 ميجا');
      expect(sizeLabel(350 * 1024), '350 ك.ب');
    });

    test('uploads run side by side; a failure keeps only that file',
        () async {
      final files = [
        for (final n in ['1', '2', 'bad', '3', '4']) _file('$n.jpg', _jpg),
      ];
      var running = 0;
      var most = 0;
      final progress = <int>[];
      final result = await uploadPrepFiles(
        files: files,
        upload: (f) async {
          running++;
          most = running > most ? running : most;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          if (f.file.name == 'bad.jpg') throw Exception('dropped');
          return 'p1/${f.file.name}';
        },
        onProgress: (done, _) => progress.add(done),
      );
      expect(most, 3);
      expect(result.paths, ['p1/1.jpg', 'p1/2.jpg', 'p1/3.jpg', 'p1/4.jpg']);
      expect(result.failed.single.file.name, 'bad.jpg');
      expect(progress.last, 5);
    });
  });

  test('one look per prep status', () {
    expect(prepStatusColor('pending'), AppColors.warning);
    expect(prepStatusColor('commented'), AppColors.sky);
    expect(prepStatusColor('accepted'), AppColors.success);
    final chip = prepChipLook(_prep('commented'), manualPresent: false);
    expect(chip.color, prepStatusColor('commented'));
    expect(chip.icon, prepStatusIcon('commented'));
  });

  testWidgets('the fallback card', (tester) async {
    await tester.pumpWidget(_rtl(const FileFallbackCard(url: 'https://x/y')));
    expect(find.text(AppStrings.openFile), findsOneWidget);
  });

  group('الخدام: sorting and the prep rate', () {
    final list = [
      _summary('بولا', ss: 8, meeting: 8, mass: 8, conf: 8, preps: 8),
      _summary('أندرو', ss: 2, meeting: 2, mass: 2, conf: 2, preps: 3,
          pending: 1),
      _summary('ابانوب', ss: 5, meeting: 5, mass: 5, conf: 5, preps: 5,
          pending: 2),
      _summary('خادم عام', classes: 0, preps: 1),
    ];

    test('by name, Arabic order', () {
      expect(sortServants(list, ServantSort.name, held: 8)
          .map((s) => s.servantName)
          .first, 'ابانوب');
    });

    test('lowest attendance first', () {
      expect(sortServants(list, ServantSort.lowest, held: 8)
          .map((s) => s.servantName)
          .take(2), ['خادم عام', 'أندرو']);
    });

    test('most waiting for review first, or only those', () {
      expect(
          sortServants(list, ServantSort.pending, held: 8)
              .map((s) => s.servantName)
              .take(2),
          ['ابانوب', 'أندرو']);
      expect(
          sortServants(list, ServantSort.name, held: 8, onlyPending: true),
          hasLength(2));
    });

    test('a class servant prepares every Saturday; a خادم عام has no rate',
        () {
      expect(list.first.expectedPreps(8), 8);
      expect(list.last.expectedPreps(8), isNull);
      expect(list.first.averageRate(8), 1.0);
      expect(list.first.averageRate(0), isNull);
    });
  });

  test('«الكل حضروا» adds only the missing marks', () {
    final date = DateTime(2026, 11, 21);
    final marks = ServantMarks([
      ServantAttendance(
        id: 'a1',
        servantId: 's1',
        activityType: 'mass',
        date: date,
        recordedBy: 'admin',
      ),
    ]);
    final toggles = marks.beginAll(
      servantIds: ['s1', 's2', 's3'],
      type: 'mass',
      date: date,
      recordedBy: 'admin',
    );
    expect(toggles.map((t) => t.servantId), ['s2', 's3']);
    expect(marks.find('s2', 'mass'), isNotNull);
    expect(
      marks.beginAll(
        servantIds: ['s1', 's2', 's3'],
        type: 'mass',
        date: date,
        recordedBy: 'admin',
      ),
      isEmpty,
    );
  });

  group('تحضيراتي', () {
    testWidgets('next Saturday not sent: a big upload button', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_rtl(PrepTodoCard(
        date: DateTime(2026, 11, 28),
        prep: null,
        onOpen: () => opened++,
      )));
      expect(find.text(AppStrings.prepTodoTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.prepTodoUpload));
      expect(opened, 1);
    });

    testWidgets('commented: asks to fix and send again', (tester) async {
      await tester.pumpWidget(_rtl(PrepTodoCard(
        date: DateTime(2026, 11, 28),
        prep: _prep('commented'),
        onOpen: () {},
      )));
      expect(find.text(AppStrings.prepResend), findsOneWidget);
      expect(find.textContaining(AppStrings.prepCommented), findsOneWidget);
    });

    testWidgets('«حضوري» counts the Saturdays I came', (tester) async {
      final held = [DateTime(2026, 11, 7), DateTime(2026, 11, 14)];
      await tester.pumpWidget(_rtl(MyAttendanceCard(
        held: held,
        marks: [
          ServantAttendance(
            id: 'm',
            servantId: 's',
            activityType: 'mass',
            date: DateTime(2026, 11, 14),
            recordedBy: 'a',
          ),
        ],
      )));
      // Folded at first: open it.
      await tester.tap(find.text(AppStrings.myAttendanceTitle));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.myAttendanceOf(1, 2)), findsOneWidget);
      expect(find.text('14 نوفمبر'), findsOneWidget);
    });
  });
}
