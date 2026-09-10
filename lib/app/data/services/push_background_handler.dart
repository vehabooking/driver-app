import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_constants.dart';
import '../../core/location/tracking_push_handler.dart';

/// Entry point for pushes that arrive while the app is backgrounded or not
/// running at all. Must stay top-level so the engine can look it up.
///
/// This runs in its own isolate: `main()` never ran there, so GetX is empty,
/// `AppConfig` is unloaded and no service is registered. Everything the
/// tracking session needs is therefore read straight from storage below.
///
/// Only the silent tracking pushes are acted on — a notification push is
/// already shown by the system tray and is handled by
/// `PushNotificationService` when the driver taps it.
@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  if (!TrackingPushHandler.handles(data)) return;

  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Already initialized for this isolate, or unavailable — the message is
    // in hand either way, so keep going.
  }

  await TrackingPushHandler.handle(data, session: _storedSession);
}

/// The driver's session as the launcher isolate left it on disk.
Future<TrackingSession?> _storedSession() async {
  try {
    final token = await const FlutterSecureStorage().read(
      key: AppConstants.tokenKey,
    );
    // Signed out: there is nobody to report for.
    if (token == null || token.isEmpty) return null;

    await AppConfig.load();
    await GetStorage.init();

    return TrackingSession(
      baseUrl: AppConfig.bookingsApiUrl,
      token: token,
      locale: GetStorage().read<String>(AppConstants.localeKey) ?? 'en_US',
    );
  } catch (_) {
    return null;
  }
}
