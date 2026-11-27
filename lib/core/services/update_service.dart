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
    this.forced = false,
  });

  final String version;
  final int build;

  /// True when this build is below the published `min_build`: the app must
  /// be updated before it can be used.
  final bool forced;

  /// This phone's APK and its fingerprint, for installing from inside the
  /// app. Null when version.json does not list them (then the download page).
  final String? apkUrl;
  final String? sha256;

  bool get canInstallInApp =>
      apkUrl != null && sha256 != null && sha256!.length == 64;
}

enum UpdateStatus { upToDate, available, failed }

/// What a check found: [update] is set only when [status] is available.
class UpdateCheck {
  const UpdateCheck.upToDate()
      : status = UpdateStatus.upToDate,
        update = null;
  const UpdateCheck.available(AppUpdate this.update)
      : status = UpdateStatus.available;
  const UpdateCheck.failed()
      : status = UpdateStatus.failed,
        update = null;

  final UpdateStatus status;
  final AppUpdate? update;
}

/// Checks the site's version.json (written by build_web.ps1 on every deploy)
/// against this build. A newer one is installed on Android and reloaded on the
/// website, where an open tab or home-screen app can stay on an old copy.
class UpdateService {
  const UpdateService._();

  /// A newer version found away from the home shell (a tapped update notice),
  /// which then shows its banner or forced screen.
  static final ValueNotifier<AppUpdate?> found = ValueNotifier<AppUpdate?>(null);

  static const _url = 'https://sabtawya.vercel.app/version.json';

  /// The newer version, or null when up to date or offline. Runs by itself at
  /// launch and on resume, so it stays silent.
  static Future<AppUpdate?> check({
    http.Client? client,
    bool web = kIsWeb,
    int current = kAppBuild,
  }) async =>
      (await checkNow(client: client, web: web, current: current)).update;

  /// The check the servant asks for (المزيد): unlike [check] it tells "up to
  /// date" apart from "could not check". On the web it reads the site's own
  /// version.json, so a tab left open for days learns a newer one is out.
  static Future<UpdateCheck> checkNow({
    http.Client? client,
    bool web = kIsWeb,
    int current = kAppBuild,
  }) async {
    final c = client ?? http.Client();
    try {
      final url = web
          ? Uri.base.resolve('version.json').replace(
              queryParameters: {
                't': '${DateTime.now().millisecondsSinceEpoch}'
              },
            )
          : Uri.parse(_url);
      final resp = await c.get(url, headers: {
        'Cache-Control': 'no-cache'
      }).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return const UpdateCheck.failed();
      final raw = jsonDecode(utf8.decode(resp.bodyBytes));
      if (raw is! Map) return const UpdateCheck.failed();
      // build_web.ps1 writes `build`; a plain `flutter build web` (the dev
      // site) only has Flutter's own `build_number`, as text.
      final json = {
        ...raw,
        if (raw['build'] == null && raw['build_number'] is String)
          'build': int.tryParse(raw['build_number'] as String),
      };
      if (json['build'] is! int || json['version'] is! String) {
        return const UpdateCheck.failed();
      }
      final u = newerThanThis(
        json,
        current: current,
        abi: web ? 'arm64' : deviceAbi(),
      );
      return u == null
          ? const UpdateCheck.upToDate()
          : UpdateCheck.available(u);
    } catch (_) {
      return const UpdateCheck.failed(); // offline, timed out, bad file
    } finally {
      if (client == null) c.close();
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
    final minBuild = json['min_build'];
    return AppUpdate(
      version: version,
      build: build,
      forced: minBuild is int && current < minBuild,
      apkUrl: apk is Map && apk['url'] is String ? apk['url'] as String : null,
      sha256: apk is Map && apk['sha256'] is String
          ? (apk['sha256'] as String).toLowerCase()
          : null,
    );
  }
}
