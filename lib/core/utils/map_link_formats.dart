/// The less common ways a place is written down, decoded into (latitude,
/// longitude). Each function answers null when the text is not in its format;
/// [MapLocation.parse] checks that what comes back is a real place.
class MapLinkFormats {
  const MapLinkFormats._();

  static const _n = r'(-?\d{1,3}(?:\.\d+)?)';

  /// Yandex Maps writes longitude first: `?ll=31.34%2C30.05`, `pt=31.34,30.05`.
  static (double, double)? yandex(String text) {
    if (!text.toLowerCase().contains('yandex.')) return null;
    final m = RegExp('[?&](?:ll|pt)=$_n(?:,|%2C)$_n', caseSensitive: false)
        .firstMatch(text);
    if (m == null) return null;
    final lng = double.tryParse(m.group(1)!);
    final lat = double.tryParse(m.group(2)!);
    return lat == null || lng == null ? null : (lat, lng);
  }

  /// Bing (`cp=30.05~31.34`), HERE (`map=30.05,31.34,15`), Apple
  /// (`coordinate=30.05,31.34`) and links that carry the two numbers under
  /// their own names (`lat=30.05&lon=31.34`), Waze's short links
  /// (`waze.com/ul/hsw0xyz`, a geohash) and full plus codes (`8GP4FQM2+VV`).
  static (double, double)? other(String text) {
    final pairs = <RegExp>[
      RegExp('[?&]cp=$_n(?:~|%7E)$_n', caseSensitive: false),
      RegExp('[?&]map=$_n,$_n', caseSensitive: false),
      RegExp('[?&](?:coordinate|latlng|location|pos|point)=$_n(?:,|%2C)$_n',
          caseSensitive: false),
      RegExp('[?&]lat(?:itude)?=$_n&(?:amp;)?(?:lon|lng|long|longitude)=$_n',
          caseSensitive: false),
    ];
    for (final p in pairs) {
      final m = p.firstMatch(text);
      if (m == null) continue;
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat != null && lng != null) return (lat, lng);
    }

    final waze =
        RegExp(r'waze\.com/ul/h([0-9b-hjkmnp-z]{4,12})', caseSensitive: false)
            .firstMatch(text);
    if (waze != null) return geohash(waze.group(1)!.toLowerCase());

    final plus = RegExp(
      r'(?<![0-9A-Za-z])([23456789CFGHJMPQRVWX]{8,10}\+[23456789CFGHJMPQRVWX]{0,3})(?![0-9A-Za-z])',
      caseSensitive: false,
    ).firstMatch(text);
    if (plus != null) return plusCode(plus.group(1)!.toUpperCase());
    return null;
  }

  /// A geohash (`sv8wnc3s`) as the middle of its cell.
  static (double, double)? geohash(String hash) {
    const alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';
    var latMin = -90.0, latMax = 90.0, lngMin = -180.0, lngMax = 180.0;
    var evenBit = true; // longitude first
    for (final c in hash.split('')) {
      final value = alphabet.indexOf(c);
      if (value < 0) return null;
      for (var bit = 4; bit >= 0; bit--) {
        final on = (value >> bit) & 1 == 1;
        if (evenBit) {
          final mid = (lngMin + lngMax) / 2;
          on ? lngMin = mid : lngMax = mid;
        } else {
          final mid = (latMin + latMax) / 2;
          on ? latMin = mid : latMax = mid;
        }
        evenBit = !evenBit;
      }
    }
    return ((latMin + latMax) / 2, (lngMin + lngMax) / 2);
  }

  /// A full Open Location Code (Google "plus code") such as `8FW4V75V+8Q`, as
  /// the middle of its cell. A short code (`V75V+8Q Paris`) needs a town to be
  /// placed and is not read.
  static (double, double)? plusCode(String code) {
    const alphabet = '23456789CFGHJMPQRVWX';
    final plusAt = code.indexOf('+');
    if (plusAt != 8) return null;
    final digits = code.replaceAll('+', '');
    if (digits.length < 10) return null;
    var lat = -90.0, lng = -180.0;
    var size = 20.0;
    for (var i = 0; i < 10; i += 2) {
      final a = alphabet.indexOf(digits[i]);
      final b = alphabet.indexOf(digits[i + 1]);
      if (a < 0 || b < 0) return null;
      lat += a * size;
      lng += b * size;
      if (i < 8) size /= 20;
    }
    // Ten digits name a cell 1/8000 of a degree wide; the middle of it.
    const cell = 0.000125;
    return (lat + cell / 2, lng + cell / 2);
  }

  /// Degrees with a hemisphere letter: `30.0561° N, 31.3416° E`,
  /// `N30.0561 E31.3416`, `30.0561N 31.3416E`, and degrees with decimal
  /// minutes: `30°03.366'N 31°20.5'E`.
  static (double, double)? hemisphere(String text) {
    double sign(String letter, String negative) =>
        letter.toUpperCase() == negative ? -1 : 1;

    final minutes = RegExp(
      r'''(\d{1,3})\s*[°º]\s*(\d{1,2}(?:\.\d+)?)\s*['′’]?\s*([NSns])[\s,،;]*(\d{1,3})\s*[°º]\s*(\d{1,2}(?:\.\d+)?)\s*['′’]?\s*([EWew])''',
    ).firstMatch(text);
    if (minutes != null) {
      final lat = (double.parse(minutes.group(1)!) +
              double.parse(minutes.group(2)!) / 60) *
          sign(minutes.group(3)!, 'S');
      final lng = (double.parse(minutes.group(4)!) +
              double.parse(minutes.group(5)!) / 60) *
          sign(minutes.group(6)!, 'W');
      return (lat, lng);
    }

    final after = RegExp(
      r'(\d{1,3}(?:\.\d+)?)\s*[°º]?\s*([NSns])[\s,،;]+(\d{1,3}(?:\.\d+)?)\s*[°º]?\s*([EWew])(?![A-Za-z])',
    ).firstMatch(text);
    if (after != null) {
      return (
        double.parse(after.group(1)!) * sign(after.group(2)!, 'S'),
        double.parse(after.group(3)!) * sign(after.group(4)!, 'W'),
      );
    }
    final before = RegExp(
      r'(?<![A-Za-z])([NSns])\s*(\d{1,3}(?:\.\d+)?)\s*[°º]?[\s,،;]*([EWew])\s*(\d{1,3}(?:\.\d+)?)',
    ).firstMatch(text);
    if (before != null) {
      return (
        double.parse(before.group(2)!) * sign(before.group(1)!, 'S'),
        double.parse(before.group(4)!) * sign(before.group(3)!, 'W'),
      );
    }
    return null;
  }

  /// Comma as the decimal mark, the two numbers split by a semicolon or a
  /// space: `30,0561; 31,3416` or `30,0561 31,3416`.
  static (double, double)? commaDecimals(String text) {
    final m = RegExp(
            r'(?<![\d.,])(-?\d{1,3},\d{4,})\s*[;\s]\s*(-?\d{1,3},\d{4,})(?![\d,])')
        .firstMatch(text);
    if (m == null) return null;
    final lat = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    final lng = double.tryParse(m.group(2)!.replaceAll(',', '.'));
    return lat == null || lng == null ? null : (lat, lng);
  }
}
