import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/supabase/db.dart';
import '../utils/map_location.dart';
import 'place_page_reader.dart';

/// What opening a shortened link gave.
class ResolvedLink {
  const ResolvedLink({
    this.place,
    required this.opened,
    this.approximate = false,
  });

  /// The link could not be opened (no connection, a wrong or expired link).
  static const failed = ResolvedLink(opened: false);

  /// The place, when the link's address holds its coordinates.
  final MapLocation? place;

  /// The link opened. With no [place] it was a place shared by name or
  /// address: Google keeps its coordinates out of the link.
  final bool opened;

  /// The [place] was read off Google's page for a place shared by name, not
  /// from coordinates in the link: it should be checked on the map.
  final bool approximate;
}

/// Reads the place behind a shortened Google Maps link (maps.app.goo.gl/…).
/// The short link only says where to go, so a small server function opens it
/// (Google's own hosts only) and sends back the long address.
class MapLinkResolver {
  const MapLinkResolver._();

  static Future<ResolvedLink> resolve(
    String text, {
    Future<MapLocation?> Function(String url)? readPage,
  }) async {
    try {
      final resp = await Db.client.functions.invoke(
        'resolve-map-link',
        body: <String, dynamic>{'url': text},
      );
      final data = resp.data;
      if (data is! Map || data['url'] is! String) return ResolvedLink.failed;
      final coords = data['coords'];
      final url = data['url'] as String;
      final place = MapLocation.parse(coords is String ? coords : null) ??
          MapLocation.parse(url);
      if (place != null) return ResolvedLink(place: place, opened: true);

      // A place shared by name: the phone itself reads Google's page (a
      // server gets a generic map). Not possible in a browser (no CORS).
      if (!kIsWeb) {
        final fromPage = await (readPage ?? PlacePageReader.read)(url);
        // Zurich is what Google sends when it does not know the place.
        if (fromPage != null && fromPage.isInEgypt) {
          return ResolvedLink(
            place: fromPage,
            opened: true,
            approximate: true,
          );
        }
      }
      return const ResolvedLink(opened: true);
    } catch (_) {
      return ResolvedLink.failed;
    }
  }
}
