/// Application-wide environment configuration resolved via compile-time --dart-define.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'production');
  static const bool isStagingFlag = bool.fromEnvironment('IS_STAGING', defaultValue: false);

  /// True if compiling or running against the dedicated staging environment.
  static bool get isStaging =>
      isStagingFlag ||
      appEnv.toLowerCase() == 'staging' ||
      supabaseUrl.contains('hywownmlimseyboraosl');

  /// Production reference guard: returns true if configuration targets live production.
  static bool get isProduction =>
      supabaseUrl.contains('fvjgnxgsmsgowmffwcpw') ||
      (!isStaging && appEnv.toLowerCase() == 'production');

  /// Returns the current active environment label.
  static String get environmentLabel => isStaging ? 'STAGING' : 'PRODUCTION';
}
