/// A place on the map (a child's home): latitude and longitude in degrees.
class MapLocation {
  const MapLocation(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Within the globe.
  static bool isValid(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

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

  /// What a person pastes from Google Maps: a place link, a "share" link with
  /// the coordinates in it, a `geo:` link, or just the two numbers. Null when
  /// no coordinates can be found in it (a shortened `maps.app.goo.gl` link
  /// hides them: see [isShortLink]).
  static MapLocation? parse(String? input) {
    if (input == null) return null;
    final text = _latin(input.trim());
    if (text.isEmpty) return null;

    const n = r'(-?\d{1,3}(?:\.\d+)?)';
    final patterns = <RegExp>[
      // .../place/Name/data=!3d30.05!4d31.34 (the pin itself)
      RegExp('!3d$n!4d$n'),
      // .../@30.05,31.34,17z (where the map is centred)
      RegExp('@$n,$n'),
      // ?q=30.05,31.34   &ll=...   &query=...   &destination=...   &center=...
      RegExp('[?&](?:q|ll|query|destination|center|daddr)=$n(?:,|%2C|\\+)$n'),
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
    return null;
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
