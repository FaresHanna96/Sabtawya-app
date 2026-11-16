import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/map_location.dart';

void main() {
  const home = MapLocation(30.05611, 31.34167);

  group('reading what is pasted', () {
    test('plain coordinates, however they are separated', () {
      for (final text in [
        '30.05611, 31.34167',
        '30.05611,31.34167',
        '30.05611 31.34167',
        '  30.05611 ,  31.34167  ',
        '30.05611،31.34167', // Arabic comma
        '30.05611;31.34167',
      ]) {
        expect(MapLocation.parse(text), home, reason: text);
      }
    });

    test('Arabic-Indic digits', () {
      expect(MapLocation.parse('٣٠٫٠٥٦١١، ٣١٫٣٤١٦٧'), home);
    });

    test('a Google Maps link with the map centre (@)', () {
      expect(
        MapLocation.parse('https://www.google.com/maps/@30.05611,31.34167,17z'),
        home,
      );
      expect(
        MapLocation.parse(
            'https://www.google.com/maps/place/Home/@30.05611,31.34167,15z/data=!4m5'),
        home,
      );
    });

    test('the pin itself wins over the centre of the map', () {
      expect(
        MapLocation.parse(
            'https://www.google.com/maps/place/X/@30.1,31.1,17z/data=!3d30.05611!4d31.34167'),
        home,
      );
    });

    test('query links', () {
      for (final link in [
        'https://www.google.com/maps?q=30.05611,31.34167',
        'https://maps.google.com/?q=30.05611%2C31.34167',
        'https://www.google.com/maps/search/?api=1&query=30.05611,31.34167',
        'https://www.google.com/maps/dir/?api=1&destination=30.05611,31.34167',
        'https://maps.google.com/maps?ll=30.05611,31.34167&z=16',
      ]) {
        expect(MapLocation.parse(link), home, reason: link);
      }
    });

    test('a geo: link', () {
      expect(MapLocation.parse('geo:30.05611,31.34167'), home);
      expect(MapLocation.parse('geo:30.05611,31.34167?q=Home'), home);
    });

    test('southern and western places keep their sign', () {
      expect(MapLocation.parse('-33.8688, 151.2093'),
          const MapLocation(-33.8688, 151.2093));
      expect(MapLocation.parse('40.7128, -74.0060'),
          const MapLocation(40.7128, -74.006));
    });

    test('whole numbers are fine', () {
      expect(MapLocation.parse('30, 31'), const MapLocation(30, 31));
    });

    test('things that are not a place give nothing', () {
      for (final text in [
        '',
        '   ',
        'القاهرة',
        'https://www.google.com/maps',
        '30.05611',
        'a, b',
        '91.0, 31.0', // no such latitude
        '30.0, 181.0', // no such longitude
        '30.05611, 31.34167, 17', // three numbers: not a pair
      ]) {
        expect(MapLocation.parse(text), isNull, reason: text);
      }
      expect(MapLocation.parse(null), isNull);
    });
  });

  group('shortened links', () {
    test('are recognised, so the person can be told what to paste', () {
      expect(MapLocation.isShortLink('https://maps.app.goo.gl/abc123'), isTrue);
      expect(MapLocation.isShortLink('https://goo.gl/maps/xyz'), isTrue);
      expect(MapLocation.isShortLink('https://www.google.com/maps/@1,2,3z'),
          isFalse);
      expect(MapLocation.isShortLink(null), isFalse);
    });

    test('cannot be read', () {
      expect(MapLocation.parse('https://maps.app.goo.gl/abc123'), isNull);
    });
  });

  group('opening it', () {
    test('the place on Google Maps', () {
      expect(
        home.viewUri.toString(),
        'https://www.google.com/maps/search/?api=1&query=30.05611%2C31.34167',
      );
    });

    test('directions to it', () {
      final uri = home.directionsUri;
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['destination'], '30.05611,31.34167');
    });

    test('what the link means round-trips through the parser', () {
      expect(MapLocation.parse(home.viewUri.toString()), home);
      expect(MapLocation.parse(home.directionsUri.toString()), home);
    });

    test('the label shows five decimals', () {
      expect(home.label, '30.05611, 31.34167');
      expect(const MapLocation(30, 31).label, '30.00000, 31.00000');
    });
  });

  test('two places are equal when their numbers are', () {
    expect(const MapLocation(1, 2), const MapLocation(1, 2));
    expect(const MapLocation(1, 2) == const MapLocation(1, 3), isFalse);
    expect(const MapLocation(1, 2).hashCode, const MapLocation(1, 2).hashCode);
  });
}
