import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabtawya/core/services/place_page_reader.dart';
import 'package:sabtawya/core/utils/map_location.dart';

const _named =
    'https://www.google.com/maps?q=12+Ahmed+Abou+El-Ola,+Nasr+City&ftid=0x14583e63698ae30d:0x35dd035fbec01dfc&entry=gps';

const _page = '''
<html><head>
<meta content="Name" property="og:title">
<meta content="https://maps.google.com/maps/api/staticmap?center=30.0580864%2C31.3851904&amp;zoom=15&amp;size=900x900" property="og:image">
</head><body>
<script>var x = "center=47.4269527%2C8.6713222";</script>
</body></html>
''';

void main() {
  group('which links name one place', () {
    test('a place id (ftid or cid) on a Google host does', () {
      expect(PlacePageReader.namesAPlace(Uri.parse(_named)), isTrue);
      expect(
          PlacePageReader.namesAPlace(
              Uri.parse('https://maps.google.com/?cid=123456789')),
          isTrue);
    });

    test('a name alone, another host or plain http does not', () {
      for (final u in [
        'https://www.google.com/maps/place/Cairo+Tower/',
        'https://www.google.com/maps?q=Cairo+Tower',
        'https://evil.example.com/?ftid=0x1:0x2',
        'http://www.google.com/maps?ftid=0x1:0x2',
      ]) {
        expect(PlacePageReader.namesAPlace(Uri.parse(u)), isFalse, reason: u);
      }
    });
  });

  group('the centre of the preview image', () {
    test('is read from the og:image tag only', () {
      final got = PlacePageReader.centreFrom(_page)!;
      expect(got.latitude, closeTo(30.05809, 0.0001));
      expect(got.longitude, closeTo(31.38519, 0.0001));
    });

    test('is nothing when the page has no such tag', () {
      expect(
          PlacePageReader.centreFrom(
              '<html><script>center=47.4%2C8.6</script></html>'),
          isNull);
      expect(PlacePageReader.centreFrom(''), isNull);
    });

    test('0,0 is no centre', () {
      expect(
          PlacePageReader.centreFrom(
              '<meta property="og:image" content="x?center=0.0%2C0.0">'),
          isNull);
    });
  });

  group('reading the page', () {
    test('gives the place for a link that names one', () async {
      final client = MockClient((_) async => http.Response(_page, 200));
      final got = await PlacePageReader.read(_named, client: client);
      expect(got, isA<MapLocation>());
      expect(got!.latitude, closeTo(30.05809, 0.0001));
    });

    test('gives nothing for a name alone, without asking Google', () async {
      var asked = 0;
      final client = MockClient((_) async {
        asked++;
        return http.Response(_page, 200);
      });
      expect(
          await PlacePageReader.read('https://www.google.com/maps?q=Cairo',
              client: client),
          isNull);
      expect(asked, 0);
    });

    test('gives nothing when Google refuses or cannot be reached', () async {
      expect(
          await PlacePageReader.read(_named,
              client: MockClient((_) async => http.Response('no', 429))),
          isNull);
      expect(
          await PlacePageReader.read(_named,
              client: MockClient((_) async => throw Exception('offline'))),
          isNull);
    });
  });
}
