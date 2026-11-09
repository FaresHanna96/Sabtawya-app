/// Supabase connection details.
///
/// Supplied at build time so no key is committed:
///
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// The anon key is safe to ship in a mobile binary — every table is protected
/// by row level security, so the key alone grants no data access.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Sabtawya';
  static const String appNameAr = 'سبتاوية';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Points per activity, used only for labels. The authoritative values live
  /// in `attendance_years` and the database recomputes every score on write.
  static const int defaultActivityPoints = 5;
  static const int defaultSessionMaxPoints = 15;
}
