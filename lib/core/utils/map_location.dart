import 'map_link_formats.dart';

/// A place on the map (a child's home): latitude and longitude in degrees.
class MapLocation {
  const MapLocation(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Within the globe, and not 0,0: that is where a missing position ends up
  /// (an empty link, a failed fix), never a child's home.
  static bool isValid(double lat, double lng) =>
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0 && lng == 0);

  /// Roughly inside Egypt; a place outside is probably a wrong paste.
  bool get isInEgypt =>
      latitude >= 21.5 &&
      latitude <= 32.0 &&
      longitude >= 24.5 &&
      longitude <= 37.0;

  /// Google Maps showing the place.
  Uri get viewUri => Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '$latitude,$longitude',
      });

  /// Google Maps with directions to the place, from where the phone is.
  Uri get directionsUri => Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
      });

  /// "30.05611, 31.34167": five decimals are about a metre.
  String get label =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  /// What a person pastes: a Google Maps place or share link, a link from
  /// WhatsApp's location message, Apple Maps, Waze or OpenStreetMap, a `geo:`
  /// link, degrees-minutes-seconds (30°03'22"N 31°20'30"E), or just the two
  /// numbers, with words around them or not. Null when no coordinates can be
  /// found in it (a shortened `maps.app.goo.gl` link hides them: see
  /// [isShortLink]).
  static MapLocation? parse(String? input) {
    if (input == null) return null;
    final text = _latin(input.trim());
    if (text.isEmpty) return null;

    // Yandex writes longitude first, so it is read before the general rules.
    final yandex = _place(MapLinkFormats.yandex(text));
    if (yandex != null) return yandex;

    const n = r'(-?\d{1,3}(?:\.\d+)?)';
    final patterns = <RegExp>[
      // .../place/Name/data=!3d30.05!4d31.34 (the pin itself)
      RegExp('!3d$n!4d$n'),
      // .../@30.05,31.34,17z (where the map is centred)
      RegExp('@$n,$n'),
      // ?q=30.05,31.34   ?q=loc:30.05,31.34   &ll=...   &query=...
      // &destination=...   &center=...   &daddr=...
      RegExp(
        '[?&](?:q|ll|sll|query|destination|center|daddr)='
        '(?:loc(?::|%3A))?$n(?:,|%2C|\\+)$n',
        caseSensitive: false,
      ),
      // OpenStreetMap: ?mlat=30.05&mlon=31.34   #map=17/30.05/31.34
      RegExp('[?&]mlat=$n&(?:amp;)?mlon=$n'),
      RegExp('#map=\\d+/$n/$n'),
      // .../maps/search/30.05,+31.34
      RegExp('/(?:search|place|dir)/$n,(?:\\+|%20|\\s)*$n'),
      // geo:30.05,31.34
      RegExp('^geo:$n,$n'),
      // 30.05, 31.34   30.05 31.34   30.05،31.34
      RegExp('^$n\\s*[,،;\\s]\\s*$n\$'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m == null) continue;
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat != null && lng != null && isValid(lat, lng)) {
        return MapLocation(lat, lng);
      }
    }

    final dms = _parseDms(text);
    if (dms != null) return dms;

    // Bing, HERE, Apple, lat=&lon=, Waze short links, plus codes, hemisphere
    // letters, comma decimals.
    for (final found in [
      MapLinkFormats.other(text),
      MapLinkFormats.hemisphere(text),
      MapLinkFormats.commaDecimals(text),
    ]) {
      final place = _place(found);
      if (place != null) return place;
    }

    // Two decimal numbers among other words ("الموقع: 30.0561, 31.3416").
    // Decimals only, so a date or a phone number is never taken for a place.
    final loose =
        RegExp(r'(-?\d{1,3}\.\d{3,})\s*[,،;\s]\s*(-?\d{1,3}\.\d{3,})');
    for (final m in loose.allMatches(text)) {
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat != null && lng != null && isValid(lat, lng)) {
        return MapLocation(lat, lng);
      }
    }
    return null;
  }

  static MapLocation? _place((double, double)? found) =>
      found != null && isValid(found.$1, found.$2)
          ? MapLocation(found.$1, found.$2)
          : null;

  /// 30°03'22.0"N 31°20'30.0"E, also as it comes in a link (%C2%B0, %22, +).
  static MapLocation? _parseDms(String raw) {
    var text = raw;
    try {
      text = Uri.decodeComponent(raw.replaceAll('+', ' '));
    } catch (_) {}
    final m = RegExp(
      r'''(\d{1,3})\s*[°º]\s*(\d{1,2})\s*['′’]\s*(\d{1,2}(?:\.\d+)?)\s*(?:"|″|”|'')?\s*([NSns])[\s,،;]*(\d{1,3})\s*[°º]\s*(\d{1,2})\s*['′’]\s*(\d{1,2}(?:\.\d+)?)\s*(?:"|″|”|'')?\s*([EWew])''',
    ).firstMatch(text);
    if (m == null) return null;
    double degrees(String d, String min, String sec) =>
        double.parse(d) + double.parse(min) / 60 + double.parse(sec) / 3600;
    final lat = degrees(m.group(1)!, m.group(2)!, m.group(3)!) *
        (m.group(4)!.toUpperCase() == 'S' ? -1 : 1);
    final lng = degrees(m.group(5)!, m.group(6)!, m.group(7)!) *
        (m.group(8)!.toUpperCase() == 'W' ? -1 : 1);
    return isValid(lat, lng) ? MapLocation(lat, lng) : null;
  }

  /// A shortened Google Maps link: it cannot be read without opening it, so
  /// the person is asked to paste the full link or the coordinates.
  static bool isShortLink(String? input) {
    final text = (input ?? '').toLowerCase();
    return text.contains('maps.app.goo.gl') ||
        text.contains('goo.gl/maps') ||
        text.contains('g.co/kgs');
  }

  /// Arabic-Indic and Persian digits and the Arabic decimal and thousands
  /// separators, as Latin ones.
  static String _latin(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final out = StringBuffer();
    for (final rune in s.runes) {
      final c = String.fromCharCode(rune);
      final a = arabic.indexOf(c);
      final p = persian.indexOf(c);
      out.write(a >= 0
          ? '$a'
          : p >= 0
              ? '$p'
              : c == '٫'
                  ? '.'
                  : c);
    }
    return out.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is MapLocation &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'MapLocation($label)';
}
