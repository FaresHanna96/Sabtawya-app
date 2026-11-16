import '../../data/supabase/db.dart';
import '../utils/map_location.dart';

/// Reads the place behind a shortened Google Maps link (maps.app.goo.gl/…).
/// The short link only says where to go, so a small server function opens it
/// (Google's own hosts only) and sends back the long address.
class MapLinkResolver {
  const MapLinkResolver._();

  /// The place, or null when the link cannot be opened or holds no place.
  static Future<MapLocation?> resolve(String text) async {
    try {
      final resp = await Db.client.functions.invoke(
        'resolve-map-link',
        body: <String, dynamic>{'url': text},
      );
      final data = resp.data;
      if (data is! Map) return null;
      final coords = data['coords'];
      if (coords is String) {
        final place = MapLocation.parse(coords);
        if (place != null) return place;
      }
      final url = data['url'];
      return url is String ? MapLocation.parse(url) : null;
    } catch (_) {
      return null;
    }
  }
}
