import '../../data/supabase/db.dart';
import '../utils/map_location.dart';

/// What opening a shortened link gave.
class ResolvedLink {
  const ResolvedLink({this.place, required this.opened});

  /// The link could not be opened (no connection, a wrong or expired link).
  static const failed = ResolvedLink(opened: false);

  /// The place, when the link's address holds its coordinates.
  final MapLocation? place;

  /// The link opened. With no [place] it was a place shared by name or
  /// address: Google keeps its coordinates out of the link.
  final bool opened;
}

/// Reads the place behind a shortened Google Maps link (maps.app.goo.gl/…).
/// The short link only says where to go, so a small server function opens it
/// (Google's own hosts only) and sends back the long address.
class MapLinkResolver {
  const MapLinkResolver._();

  static Future<ResolvedLink> resolve(String text) async {
    try {
      final resp = await Db.client.functions.invoke(
        'resolve-map-link',
        body: <String, dynamic>{'url': text},
      );
      final data = resp.data;
      if (data is! Map || data['url'] is! String) return ResolvedLink.failed;
      final coords = data['coords'];
      final place = MapLocation.parse(coords is String ? coords : null) ??
          MapLocation.parse(data['url'] as String);
      return ResolvedLink(place: place, opened: true);
    } catch (_) {
      return ResolvedLink.failed;
    }
  }
}
