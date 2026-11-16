import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/map_location.dart';
import 'package:sabtawya/data/models/child.dart';

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
      ]) {
        expect(MapLocation.parse(text), isNull, reason: text);
      }
      expect(MapLocation.parse(null), isNull);
    });
  });

  group('more formats people really paste', () {
    const near = MapLocation(30.0561, 31.3416);

    void reads(String name, String text, [MapLocation want = near]) {
      test(name, () {
        final got = MapLocation.parse(text);
        expect(got, isNotNull, reason: text);
        expect((got!.latitude - want.latitude).abs(), lessThan(0.0005),
            reason: text);
        expect((got.longitude - want.longitude).abs(), lessThan(0.0005),
            reason: text);
      });
    }

    reads(
        'a search link', 'https://www.google.com/maps/search/30.0561,+31.3416');
    reads('q=loc:', 'https://www.google.com/maps?q=loc:30.0561,31.3416');
    reads('an Android geo: link with the real place after 0,0',
        'geo:0,0?q=30.0561,31.3416(Home)');
    reads('degrees, minutes, seconds', """30°03'22.0"N 31°20'30.0"E""");
    reads('degrees, minutes, seconds as they come in a link',
        "https://www.google.com/maps/place/30%C2%B003'22.0%22N+31%C2%B020'30.0%22E/");
    reads('OpenStreetMap map link',
        'https://www.openstreetmap.org/#map=17/30.0561/31.3416');
    reads('OpenStreetMap marker link',
        'https://www.openstreetmap.org/?mlat=30.0561&mlon=31.3416');
    reads('Apple Maps', 'https://maps.apple.com/?ll=30.0561,31.3416&q=Home');
    reads('Waze', 'https://waze.com/ul?ll=30.0561%2C31.3416&navigate=yes');
    reads('a WhatsApp message with words around the link',
        'موقع البيت https://maps.google.com/?q=30.0561,31.3416 شكرا');
    reads('coordinates with words in front', 'الموقع: 30.0561, 31.3416');
    reads('coordinates with a note after', '30.0561, 31.3416 (البيت)');
    reads('coordinates on two lines', '30.0561\n31.3416');
    reads('the zoom after the pair is ignored', '30.05611, 31.34167, 17',
        const MapLocation(30.05611, 31.34167));
    reads('southern degrees', """33°52'07.7"S 151°12'33.5"E""",
        const MapLocation(-33.8688, 151.2093));
    reads('western degrees', """40°42'46.1"N 74°00'21.6"W""",
        const MapLocation(40.7128, -74.006));

    test('a date, a phone number or an IP address is not a place', () {
      for (final text in [
        'اتصل 01012345678',
        'يوم 12.11.2026',
        'من 192.168.100.100',
        '2026-11-16 17:00',
        'السعر 12.5 جنيه و 30.75 قرش', // two decimals, but not coordinates...
      ]) {
        final got = MapLocation.parse(text);
        // The last one is two valid decimals; reading it as a place is the
        // price of reading "الموقع: 30.0561, 31.3416"; the editor shows what
        // it read, so a wrong one is seen at once.
        if (text.startsWith('السعر')) continue;
        expect(got, isNull, reason: text);
      }
    });
  });

  group('0,0 is no place', () {
    test('is never read from a link or text', () {
      for (final text in [
        '0,0',
        '0.0, 0.0',
        'https://www.google.com/maps/@0,0,2z',
        'https://www.google.com/maps?q=0,0',
        'geo:0,0',
      ]) {
        expect(MapLocation.parse(text), isNull, reason: text);
      }
    });

    test('a child saved with 0,0 shows no location', () {
      final c = Child.fromMap({
        'id': 'k',
        'class_id': 'c',
        'full_name': 'م',
        'gender': 'boy',
        'latitude': 0,
        'longitude': 0,
      });
      expect(c.location, isNull);
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
