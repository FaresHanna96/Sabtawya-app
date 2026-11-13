import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_version.dart';

/// A newer published version than the one running.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.build,
    this.apkUrl,
    this.sha256,
  });

  final String version;
  final int build;

  /// This phone's APK and its fingerprint, for installing from inside the
  /// app. Null when version.json does not list them (then the download page).
  final String? apkUrl;
  final String? sha256;

  bool get canInstallInApp =>
      apkUrl != null && sha256 != null && sha256!.length == 64;
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
      final resp = await c.get(Uri.parse(_url), headers: {
        'Cache-Control': 'no-cache'
      }).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      return newerThanThis(
        jsonDecode(utf8.decode(resp.bodyBytes)),
        abi: deviceAbi(),
      );
    } catch (_) {
      return null; // never bother anyone because the check failed
    }
  }

  /// "arm64" or "armv7": which of the two published APKs fits this phone.
  /// Dart reports it in Platform.version, e.g. `... on "android_arm64"`.
  @visibleForTesting
  static String deviceAbi([String? platformVersion]) {
    final v = platformVersion ?? (kIsWeb ? '' : Platform.version);
    if (v.contains('android_arm64')) return 'arm64';
    if (v.contains('android_arm')) return 'armv7';
    return 'arm64';
  }

  /// The update described by [json], when its build is newer than this one.
  @visibleForTesting
  static AppUpdate? newerThanThis(
    Object? json, {
    int current = kAppBuild,
    String abi = 'arm64',
  }) {
    if (json is! Map) return null;
    final build = json['build'];
    final version = json['version'];
    if (build is! int || version is! String) return null;
    if (build <= current) return null;
    final apks = json['apk'];
    final apk = apks is Map ? apks[abi] : null;
    return AppUpdate(
      version: version,
      build: build,
      apkUrl: apk is Map && apk['url'] is String ? apk['url'] as String : null,
      sha256: apk is Map && apk['sha256'] is String
          ? (apk['sha256'] as String).toLowerCase()
          : null,
    );
  }
}
