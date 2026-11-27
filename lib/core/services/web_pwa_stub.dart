/// The phone app has none of the browser's features: each does nothing here.
/// The website's versions are in web_pwa_web.dart.
library;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

/// True while the browser offers to install the website as an app.
final ValueNotifier<bool> installAvailable = ValueNotifier<bool>(false);

void listenForInstall() {}
Future<bool> promptInstall() async => false;

/// The icon shortcut the app was opened with (read once), or null.
String? takeLaunchShortcut() => null;

/// Whether the app was opened from the share sheet (read once).
bool takeLaunchShared() => false;

Future<List<XFile>> takeSharedFiles() async => const <XFile>[];
Future<void> clearSharedFiles() async {}

void askPersistentStorage() {}
void vibrate(int milliseconds) {}
void setScreenAwake(bool on) {}

/// True the first time for [build] in this tab.
bool firstReloadFor(int build) => false;

Future<bool> passkeySupported() async => false;
Future<String?> createPasskey(String name) async => null;
Future<bool> checkPasskey(String id) async => false;
