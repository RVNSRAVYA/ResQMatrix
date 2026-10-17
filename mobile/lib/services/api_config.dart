import 'package:flutter/foundation.dart';

class ApiConfig {
  // For a physical Android phone, replace this at build/run time with:
  // flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    // Android emulator maps the host computer to 10.0.2.2.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }
}
