class AppConfig {
  AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3001/api/v1',
  );

  static const socketBaseUrl = String.fromEnvironment(
    'SOCKET_BASE_URL',
    defaultValue: 'http://10.0.2.2:3001',
  );

  static const appName = 'منچ ایرانی';
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');
}
