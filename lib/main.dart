import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app/core/config/app_config.dart';
import 'app/core/i18n/app_translations.dart';
import 'app/core/location/driver_tracking_service.dart';
import 'app/core/location/location_service.dart';
import 'app/core/network/api_client.dart';
import 'app/core/routes/app_pages.dart';
import 'app/core/routes/app_routes.dart';
import 'app/core/storage/storage_service.dart';
import 'app/core/theme/app_theme.dart';
import 'app/data/repositories/auth_repository.dart';
import 'app/data/repositories/booking_repository.dart';
import 'app/data/repositories/guide_repository.dart';
import 'app/data/repositories/notification_repository.dart';
import 'app/data/services/auth_service.dart';
import 'app/data/services/push_notification_service.dart';
import 'app/data/services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Backend host comes from the bundled `.env` (APP_URL) — load it first so
  // AppConfig is resolved before any repository builds a URL.
  await AppConfig.load();

  await StorageService.init();

  // Core singletons (order matters: storage → client → repos → services).
  final storage = Get.put(StorageService(), permanent: true);
  final api = Get.put(ApiClient(storage), permanent: true);

  Get.put(AuthRepository(api), permanent: true);
  Get.put(BookingRepository(api), permanent: true);
  Get.put(GuideRepository(api), permanent: true);
  Get.put(NotificationRepository(api), permanent: true);
  final locationService = Get.put(LocationService(), permanent: true);
  Get.put(
    DriverTrackingService(
      Get.find<BookingRepository>(),
      locationService,
      api,
      storage,
    ),
    permanent: true,
  );

  final auth = Get.put(
    AuthService(Get.find<AuthRepository>(), api, storage),
    permanent: true,
  );
  await auth.bootstrap();

  await Get.put(
    PushNotificationService(Get.find<NotificationRepository>(), api, storage),
    permanent: true,
  ).init();

  final settings = Get.put(SettingsService(storage).init(), permanent: true);

  // On a 401 anywhere, reset to login (and drop any background tracking
  // session that would otherwise keep posting with the dead token).
  // Tokens never expire server-side, so a 401 means the session was revoked —
  // the account signed in on another phone, or dispatch reset it. (A silent
  // push usually gets there first; this is the fallback.)
  api.onUnauthorized = () => unawaited(auth.forceSignOut());

  // Every launch starts on the animated splash, which then routes to
  // Welcome (first run) / Home (logged in) / Login.
  runApp(VehaDriverApp(settings: settings));
}

class VehaDriverApp extends StatelessWidget {
  const VehaDriverApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode.value,
      translations: AppTranslations(),
      locale: settings.locale.value,
      fallbackLocale: AppTranslations.fallbackLocale,
      supportedLocales: AppTranslations.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, child) => _MobileAppFrame(child: child),
      initialRoute: Routes.splash,
      getPages: AppPages.pages,
    );
  }
}

class _MobileAppFrame extends StatelessWidget {
  const _MobileAppFrame({required this.child});

  static const double _maxWidth = 430;
  static const double _maxHeight = 940;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final app = child ?? const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 600) {
          return app;
        }

        final width = constraints.maxWidth < _maxWidth
            ? constraints.maxWidth
            : _maxWidth;
        final height = constraints.maxHeight < _maxHeight
            ? constraints.maxHeight
            : _maxHeight;
        final media = MediaQuery.of(context).copyWith(
          size: Size(width, height),
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
        );

        return ColoredBox(
          color: const Color(0xFFEFF7F6),
          child: Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: MediaQuery(data: media, child: app),
            ),
          ),
        );
      },
    );
  }
}
