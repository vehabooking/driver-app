import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  const AppConfig._();

  static const String appName = 'Veha Driver';

  static const String envFileName = '.env';

  /// Version the build actually carries, read once at startup. Hardcoding it
  /// meant every build claimed 1.0.0, so a driver could never tell you which
  /// one they were running.
  static String appVersion = '';

  static Future<void> load() async {
    await dotenv.load(fileName: envFileName);

    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      appVersion = '';
    }
    if (_rawBaseUrl.isEmpty) {
      throw StateError(
        'APP_URL is missing or empty in $envFileName. '
        'Set it to the backend host, e.g. https://staging.app.vehabooking.com',
      );
    }
  }

  static String get _rawBaseUrl => dotenv.env['APP_URL']?.trim() ?? '';

  static String get baseUrl {
    var url = _rawBaseUrl;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static String get authApiUrl => '$baseUrl/api/driver/v1';

  static String get bookingsApiUrl => '$baseUrl/api/taxi/v1/driver';

  static String get guideApiUrl => '$baseUrl/api/driver/v1/guideline';

  static String get platformInfoApiUrl => '$baseUrl/api/v1/platform/info';

  /// Resolves backend-owned media URLs against the host configured for this
  /// app. Herd returns `.test` URLs locally, which Android devices cannot
  /// resolve when the API is reached through a LAN IP or emulator alias.
  static String resolveBackendAssetUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return raw;

    final configuredBase = Uri.tryParse(baseUrl);
    final asset = Uri.tryParse(raw);
    if (configuredBase == null || asset == null) return raw;

    if (!asset.hasScheme) {
      return configuredBase.resolve(raw).toString();
    }

    if (!_isLocalBackendHost(asset.host)) return raw;

    return asset
        .replace(
          scheme: configuredBase.scheme,
          host: configuredBase.host,
          port: configuredBase.hasPort ? configuredBase.port : null,
        )
        .toString();
  }

  static bool _isLocalBackendHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '10.0.2.2' ||
        normalized.endsWith('.test');
  }

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const Duration bookingsPollInterval = Duration(seconds: 45);
}
