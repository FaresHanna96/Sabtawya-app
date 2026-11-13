import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_version.dart';

/// A newer published version than the one running.
class AppUpdate {
  const AppUpdate({required this.version, required this.build});

  final String version;
  final int build;
}

/// Checks the site's version.json (written by build_web.ps1 on every deploy)
/// against this build. Android only: the website is always the latest one.
class UpdateService {
  const UpdateService._();

  static const _url = 'https://sabtawya.vercel.app/version.json';

  /// The newer version, or null when up to date, on the web, or offline.
  static Future<AppUpdate?> check({http.Client? client}) async {
    if (kIsWeb) return null;
    try {
      final c = client ?? http.Client();
      final resp = await c
          .get(Uri.parse(_url), headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      return newerThanThis(jsonDecode(utf8.decode(resp.bodyBytes)));
    } catch (_) {
      return null; // never bother anyone because the check failed
    }
  }

  /// The update described by [json], when its build is newer than this one.
  @visibleForTesting
  static AppUpdate? newerThanThis(Object? json, {int current = kAppBuild}) {
    if (json is! Map) return null;
    final build = json['build'];
    final version = json['version'];
    if (build is! int || version is! String) return null;
    return build > current ? AppUpdate(version: version, build: build) : null;
  }
}
