/// The app's version, shown in Settings and compared with the published one
/// (web/version.json) to offer an update on Android.
///
/// Must match `version:` in pubspec.yaml (`kAppVersion+kAppBuild`); a test
/// checks it. Raise both for every release that ships an APK.
const String kAppVersion = '1.0.11';
const int kAppBuild = 12;
