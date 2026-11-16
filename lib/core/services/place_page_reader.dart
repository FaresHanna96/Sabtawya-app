import 'package:http/http.dart' as http;

import '../utils/map_location.dart';

/// Reads the place off Google's own page for a place shared by name or address
/// (a link with a place id, `ftid` or `cid`, and no coordinates in it).
///
/// That page's preview image is centred on the place, so the centre is the
/// pin. It only works from the phone's own connection: sent from a server,
/// Google answers with a generic map of somewhere else, which is why this is
/// not done by the `resolve-map-link` function. The result is therefore shown
/// as "check it on the map", never trusted blindly.
class PlacePageReader {
  const PlacePageReader._();

  /// True for a Google Maps link that names one specific place.
  static bool namesAPlace(Uri uri) {
    final host = uri.host.toLowerCase();
    final google = host == 'maps.google.com' ||
        host == 'google.com' ||
        host.endsWith('.google.com');
    if (!google || uri.scheme != 'https') return false;
    final q = uri.queryParameters;
    return (q['ftid'] ?? '').isNotEmpty || (q['cid'] ?? '').isNotEmpty;
  }

  /// The centre of the preview image named in the page's `og:image` or
  /// `twitter:image` tag, and nothing else on the page.
  static MapLocation? centreFrom(String html) {
    final tags = RegExp(
      r'<meta[^>]+(?:og:image|twitter:image)[^>]*>',
      caseSensitive: false,
    ).allMatches(html);
    final centre = RegExp(
      r'center=(-?\d{1,3}\.\d+)(?:%2C|,)(-?\d{1,3}\.\d+)',
      caseSensitive: false,
    );
    for (final tag in tags) {
      final text = tag.group(0)!.replaceAll('&amp;', '&');
      final m = centre.firstMatch(text);
      if (m == null) continue;
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat != null && lng != null && MapLocation.isValid(lat, lng)) {
        return MapLocation(lat, lng);
      }
    }
    return null;
  }

  /// Fetches [url] from this device and reads the place off the page; null
  /// when it names no specific place, cannot be fetched, or shows none.
  static Future<MapLocation?> read(String url, {http.Client? client}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !namesAPlace(uri)) return null;
    final own = client ?? http.Client();
    try {
      final response = await own.get(uri, headers: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
        'Accept-Language': 'en',
        'Cookie': 'CONSENT=YES+; SOCS=CAI',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = response.body;
      return centreFrom(
          body.length > 600000 ? body.substring(0, 600000) : body);
    } catch (_) {
      return null;
    } finally {
      if (client == null) own.close();
    }
  }
}
