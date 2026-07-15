/// Zentrale Laufzeit-Konfiguration.
///
/// Die Supabase-Zugangsdaten kommen über `--dart-define` herein und liegen damit
/// nie im Repo. Fehlen sie, läuft die App gegen das Mock-Repository weiter — so
/// bleibt Entwicklung und Demo ohne Backend möglich.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Nur wenn beide Werte gesetzt sind, wird das echte Backend verwendet.
  static bool get useSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
