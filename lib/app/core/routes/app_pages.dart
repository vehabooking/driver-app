import 'package:get/get.dart';

import '../../modules/auth/device_takeover_binding.dart';
import '../../modules/auth/device_takeover_view.dart';
import '../../modules/auth/forgot_password_binding.dart';
import '../../modules/auth/forgot_password_view.dart';
import '../../modules/auth/login_binding.dart';
import '../../modules/auth/login_view.dart';
import '../../modules/booking_detail/booking_detail_binding.dart';
import '../../modules/booking_detail/booking_detail_view.dart';
import '../../modules/documents/documents_binding.dart';
import '../../modules/documents/documents_view.dart';
import '../../modules/home/home_binding.dart';
import '../../modules/home/home_view.dart';
import '../../modules/notifications/notifications_binding.dart';
import '../../modules/notifications/notifications_view.dart';
import '../../modules/splash/splash_binding.dart';
import '../../modules/splash/splash_view.dart';
import '../../modules/trip_map/trip_map_view.dart';
import '../../modules/welcome/welcome_binding.dart';
import '../../modules/welcome/welcome_view.dart';
import 'app_routes.dart';

/// Route table. Bindings register each screen's controllers lazily.
class AppPages {
  AppPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.welcome,
      page: () => const WelcomeView(),
      binding: WelcomeBinding(),
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: Routes.forgotPassword,
      page: () => const ForgotPasswordView(),
      binding: ForgotPasswordBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.deviceTakeover,
      page: () => const DeviceTakeoverView(),
      binding: DeviceTakeoverBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.bookingDetail,
      page: () => const BookingDetailView(),
      binding: BookingDetailBinding(),
    ),
    GetPage(
      name: Routes.tripMap,
      page: () => const TripMapView(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: Routes.documents,
      page: () => const DocumentsView(),
      binding: DocumentsBinding(),
    ),
    GetPage(
      name: Routes.notifications,
      page: () => const NotificationsView(),
      binding: NotificationsBinding(),
      transition: Transition.rightToLeft,
    ),
  ];
}
