import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const _apiOverride = String.fromEnvironment('API_BASE_URL');
  static const _socketOverride = String.fromEnvironment('SOCKET_BASE_URL');

  static String get apiBaseUrl {
    if (_apiOverride.isNotEmpty) return _apiOverride;
    if (kIsWeb) return '${Uri.base.scheme}://${Uri.base.host}:3001/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://192.168.0.185:3001/api/v1';
    return 'http://127.0.0.1:3001/api/v1';
  }

  static String get socketBaseUrl {
    if (_socketOverride.isNotEmpty) return _socketOverride;
    if (kIsWeb) return '${Uri.base.scheme}://${Uri.base.host}:3001';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://192.168.0.185:3001';
    return 'http://127.0.0.1:3001';
  }

  static const appName = 'منچ ایرانی';
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');
}
