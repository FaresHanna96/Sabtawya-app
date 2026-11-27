/// The browser features of the website, through web/pwa.js. Every call is
/// safe when that script or the feature is missing: they are conveniences.
library;

import 'dart:js_interop';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../data/services/web_photo_picker_web.dart' show browserFile;

@JS('sabtawyaPwa')
external _Pwa? get _pwa;

extension type _Pwa(JSObject _) implements JSObject {
  external String launchShortcut();
  external bool launchShared();
  external void onInstallChange(JSFunction listener);
  external JSPromise<JSBoolean> install();
  external void persist();
  external void vibrate(int ms);
  external void keepAwake(bool on);
  external bool firstReloadFor(int build);
  external JSPromise<JSArray<web.File>> takeShared();
  external JSPromise<JSAny?> clearShared();
  external JSPromise<JSBoolean> passkeySupported();
  external JSPromise<JSString> passkeyCreate(String name);
  external JSPromise<JSBoolean> passkeyCheck(String id);
}

T _or<T>(T fallback, T Function(_Pwa pwa) run) {
  try {
    final pwa = _pwa;
    return pwa == null ? fallback : run(pwa);
  } catch (_) {
    return fallback;
  }
}

final ValueNotifier<bool> installAvailable = ValueNotifier<bool>(false);

void listenForInstall() => _or<void>(
      null,
      (p) => p.onInstallChange(
        ((bool available) {
          installAvailable.value = available;
        }).toJS,
      ),
    );

Future<bool> promptInstall() async {
  try {
    return (await _pwa?.install().toDart)?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

String? takeLaunchShortcut() {
  final go = _or('', (p) => p.launchShortcut());
  return go.isEmpty ? null : go;
}

bool takeLaunchShared() => _or(false, (p) => p.launchShared());

/// Photos are shrunk as picked ones are.
Future<List<XFile>> takeSharedFiles() async {
  try {
    final files = (await _pwa?.takeShared().toDart)?.toDart ?? const [];
    return [for (final f in files) await browserFile(f)];
  } catch (_) {
    return const <XFile>[];
  }
}

Future<void> clearSharedFiles() async {
  try {
    await _pwa?.clearShared().toDart;
  } catch (_) {}
}

void askPersistentStorage() => _or<void>(null, (p) => p.persist());
void vibrate(int milliseconds) =>
    _or<void>(null, (p) => p.vibrate(milliseconds));
void setScreenAwake(bool on) => _or<void>(null, (p) => p.keepAwake(on));
bool firstReloadFor(int build) => _or(false, (p) => p.firstReloadFor(build));

Future<bool> passkeySupported() async {
  try {
    return (await _pwa?.passkeySupported().toDart)?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

Future<String?> createPasskey(String name) async {
  try {
    final id = (await _pwa?.passkeyCreate(name).toDart)?.toDart ?? '';
    return id.isEmpty ? null : id;
  } catch (_) {
    return null;
  }
}

Future<bool> checkPasskey(String id) async {
  try {
    return (await _pwa?.passkeyCheck(id).toDart)?.toDart ?? false;
  } catch (_) {
    return false;
  }
}
