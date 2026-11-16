import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/map_link_formats.dart';
import 'package:sabtawya/core/utils/map_location.dart';

void main() {
  void reads(String text, double lat, double lng, {double within = 0.0005}) {
    final got = MapLocation.parse(text);
    expect(got, isNotNull, reason: text);
    expect((got!.latitude - lat).abs(), lessThan(within), reason: text);
    expect((got.longitude - lng).abs(), lessThan(within), reason: text);
  }

  group('other map services', () {
    test('Bing', () {
      reads('https://www.bing.com/maps?cp=30.0561%7E31.3416&lvl=17', 30.0561,
          31.3416);
      reads('https://www.bing.com/maps?cp=30.0561~31.3416', 30.0561, 31.3416);
    });

    test('HERE', () {
      reads('https://wego.here.com/?map=30.0561,31.3416,15,normal', 30.0561,
          31.3416);
    });

    test('Yandex writes longitude first', () {
      reads('https://yandex.com/maps/?ll=31.3416%2C30.0561&z=17', 30.0561,
          31.3416);
      reads(
          'https://yandex.ru/maps/?pt=31.3416,30.0561&z=17', 30.0561, 31.3416);
    });

    test('Apple Maps with a coordinate', () {
      reads('https://maps.apple.com/place?coordinate=30.0561,31.3416&name=Home',
          30.0561, 31.3416);
    });

    test('links that name the two numbers', () {
      reads(
          'https://example.com/map?lat=30.0561&lon=31.3416', 30.0561, 31.3416);
      reads('https://example.com/map?latitude=30.0561&longitude=31.3416',
          30.0561, 31.3416);
    });

    test('Waze short links are a geohash', () {
      reads('https://waze.com/ul/hstq6cpw32', 30.0561, 31.3416, within: 0.001);
      reads('https://www.waze.com/ul/hstq6cpw32?navigate=yes', 30.0561, 31.3416,
          within: 0.001);
    });
  });

  group('geohash and plus codes', () {
    test('a geohash is the middle of its cell', () {
      final (lat, lng) = MapLinkFormats.geohash('ezs42')!;
      expect(lat, closeTo(42.605, 0.01));
      expect(lng, closeTo(-5.603, 0.01));
      expect(MapLinkFormats.geohash('abc!'), isNull);
    });

    test('a full plus code, alone or among words', () {
      reads('8FW4V75V+8Q', 48.8584, 2.2945);
      reads('Eiffel Tower 8FW4V75V+8Q Paris', 48.8584, 2.2945);
    });

    test('a short plus code needs a town and is not read', () {
      expect(MapLocation.parse('V75V+8Q Paris'), isNull);
    });
  });

  group('degrees with letters', () {
    test('decimal degrees with N S E W', () {
      reads('30.0561° N, 31.3416° E', 30.0561, 31.3416);
      reads('N30.0561 E31.3416', 30.0561, 31.3416);
      reads('30.0561N 31.3416E', 30.0561, 31.3416);
      reads('الموقع 30.0561 N 31.3416 E شكرا', 30.0561, 31.3416);
    });

    test('degrees and decimal minutes', () {
      reads("30°03.366'N 31°20.496'E", 30.0561, 31.3416);
    });

    test('south and west are negative', () {
      reads('33.8688° S, 151.2093° E', -33.8688, 151.2093);
      reads('40.7128 N 74.0060 W', 40.7128, -74.006);
    });
  });

  group('a comma as the decimal mark', () {
    test('two numbers split by a semicolon or a space', () {
      reads('30,0561; 31,3416', 30.0561, 31.3416);
      reads('30,0561 31,3416', 30.0561, 31.3416);
    });

    test('thousands in a price or a count are not a place', () {
      for (final text in [
        'السعر 1,500 و 2,300',
        'دفع 12,500 جنيه وباقي 30,750',
        'عدد 1,000 و 2,000',
      ]) {
        expect(MapLocation.parse(text), isNull, reason: text);
      }
    });
  });

  test('none of this turns a date, a phone number or words into a place', () {
    for (final text in [
      'يوم 12.11.2026',
      'اتصل 01012345678',
      'N E S W',
      'نقطة N وبعدها E',
      'ABC123 7+8',
      'https://example.com/maps',
    ]) {
      expect(MapLocation.parse(text), isNull, reason: text);
    }
  });
}
