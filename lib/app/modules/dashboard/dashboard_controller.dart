import 'dart:async';
import 'dart:math' as math;

import 'package:get/get.dart';

import '../../core/location/driver_tracking_service.dart';
import '../../core/location/location_service.dart';
import '../../core/maps/route_map_args.dart';
import '../../core/network/api_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/external_launcher.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/booking_detail.dart';
import '../../data/models/booking_list_item.dart';
import '../../data/models/dashboard_summary.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/push_notification_service.dart';
import '../bookings/bookings_controller.dart';
import '../home/home_controller.dart';

class DashboardController extends GetxController {
  final BookingRepository _bookingRepo = Get.find<BookingRepository>();
  final DriverTrackingService _trackingService =
      Get.find<DriverTrackingService>();
  final LocationService _locationService = Get.find<LocationService>();
  final AuthService _auth = Get.find<AuthService>();

  final isLoading = false.obs;
  final isActing = false.obs;
  final error = RxnString();
  final Rxn<DashboardSummary> summary = Rxn<DashboardSummary>();
  final unreadNotifications = 0.obs;

  /// Verification status (pending / approved / rejected).
  final status = 'pending'.obs;
  final active = false.obs;
  final Set<String> _nearPickupReminderKeys = {};

  AuthUser? get user => _auth.currentUser.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final data = await _bookingRepo.dashboard();
      summary.value = data;
      status.value = data.status;
      active.value = data.active;
      await _loadUnreadNotifications();
      _watchNextPickupTracking();
    } on ApiException catch (e) {
      error.value = e.message;
    } catch (_) {
      error.value = 'error_generic'.tr;
    } finally {
      isLoading.value = false;
    }
  }

  /// Open the next pickup's detail; refresh on return.
  void openNextPickup() {
    final next = summary.value?.nextPickup;
    if (next == null) return;
    openBooking(next.uuid, assignmentId: next.assignmentId);
  }

  /// Load full detail for the NOW booking when the Home card needs data that
  /// is not present in the compact dashboard summary.
  Future<BookingDetail?> loadNextPickupDetail() async {
    final next = summary.value?.nextPickup;
    if (next == null) return null;

    try {
      return await _bookingRepo.show(
        next.uuid,
        assignmentId: next.assignmentId,
      );
    } on ApiException catch (e) {
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    }

    return null;
  }

  /// Open the trip that currently blocks the NOW card from starting.
  void openBlockingTrip() {
    final blockedBy = summary.value?.nextPickup?.startBlockedBy;
    if (blockedBy == null || blockedBy.uuid.isEmpty) return;
    openBooking(blockedBy.uuid, assignmentId: blockedBy.assignmentId);
  }

  /// Open the full-screen route map from the Home NOW card.
  Future<void> openNextPickupMap() async {
    final next = summary.value?.nextPickup;
    if (next == null) {
      return;
    }

    await _openNextPickupMapFor(next);
  }

  Future<void> _openNextPickupMapFor(
    BookingListItem next, {
    bool locationIsReady = false,
    bool? navigateToDropoff,
  }) async {
    if (!locationIsReady && !await _ensureLocationReady()) {
      return;
    }

    var pickup = next.pickupPlace;
    var dropoff = next.dropoffPlace;

    if (!pickup.hasCoordinates || !dropoff.hasCoordinates) {
      try {
        final detail = await _bookingRepo.show(
          next.uuid,
          assignmentId: next.assignmentId,
        );
        pickup = detail.pickup;
        dropoff = detail.dropoff;
      } on ApiException catch (e) {
        AppSnackbar.error(e.message);
        return;
      } catch (_) {
        AppSnackbar.error('location_unavailable'.tr);
        return;
      }
    }

    if (!pickup.hasCoordinates || !dropoff.hasCoordinates) {
      AppSnackbar.error('location_unavailable'.tr);
      return;
    }

    Get.toNamed(
      Routes.tripMap,
      arguments: RouteMapArgs(
        uuid: next.uuid,
        assignmentId: next.assignmentId,
        title: 'trip_map'.tr,
        subtitle: next.code ?? next.customerName ?? '',
        pickup: pickup,
        dropoff: dropoff,
        navigateToDropoff:
            navigateToDropoff ??
            _navigatesToDropoff(next.stage, next.nextAction),
      ),
    )?.then((_) => load());
  }

  /// Open any booking leg's detail by uuid + assignment id; refresh on return.
  void openBooking(String uuid, {int? assignmentId}) {
    Get.toNamed(
      Routes.bookingDetail,
      arguments: {'uuid': uuid, ...?(_assignmentArgument(assignmentId))},
    )?.then((_) => load());
  }

  Map<String, dynamic>? _assignmentArgument(int? assignmentId) =>
      assignmentId == null ? null : {'assignment_id': assignmentId};

  /// Dial the passenger from the NOW card.
  Future<void> callCustomer(String phone) => ExternalLauncher.call(phone);

  Future<void> callOperator(OperatorContact? operator) async {
    final phone = operator?.phone;
    if (phone == null || phone.isEmpty || phone == 'N/A') {
      AppSnackbar.error('dispatch_phone_unavailable'.tr);
      return;
    }

    final launched = await ExternalLauncher.call(phone);
    if (!launched) {
      AppSnackbar.error('call_failed'.tr);
    }
  }

  Future<void> emailOperator(OperatorContact? operator) async {
    final email = operator?.email;
    if (email == null || email.isEmpty || email == 'N/A') {
      AppSnackbar.error('dispatch_email_unavailable'.tr);
      return;
    }

    final launched = await ExternalLauncher.email(email);
    if (!launched) {
      AppSnackbar.error('email_failed'.tr);
    }
  }

  /// Advance the NOW pickup one step (start / arrived / meet_passenger /
  /// complete) straight from the Home card, then refresh the dashboard. A
  /// successful start continues directly to the live route-to-pickup map.
  Future<void> runNextAction(String action) async {
    final next = summary.value?.nextPickup;
    if (next == null || isActing.value) return;

    isActing.value = true;
    try {
      if (action == 'start' && !await _ensureLocationReady()) {
        return;
      }

      switch (action) {
        case 'start':
          await _bookingRepo.start(next.uuid, assignmentId: next.assignmentId);
          break;
        case 'arrived':
          await _bookingRepo.arrived(
            next.uuid,
            assignmentId: next.assignmentId,
          );
          break;
        case 'meet_passenger':
          await _bookingRepo.meetPassenger(
            next.uuid,
            assignmentId: next.assignmentId,
          );
          break;
        case 'complete':
          await _syncNextPickupLocation();
          await _bookingRepo.complete(
            next.uuid,
            assignmentId: next.assignmentId,
          );
          break;
        case 'resolve_completed':
          final assignmentId = next.assignmentId;
          if (assignmentId == null) {
            AppSnackbar.error('error_generic'.tr);
            return;
          }
          await _bookingRepo.resolveLateCompletion(
            next.uuid,
            assignmentId: assignmentId,
          );
          AppSnackbar.success('old_trip_resolved'.tr);
          break;
      }
      if (action != 'complete' && action != 'resolve_completed') {
        await _syncNextPickupLocation();
      }
      if (action == 'start') {
        // Location permission was confirmed before the lifecycle request.
        // Open only after the backend accepts Start, and force pickup mode so
        // the camera frames the driver's live position and customer pickup.
        await _openNextPickupMapFor(
          next,
          locationIsReady: true,
          navigateToDropoff: false,
        );
      }
      await load();
    } on ApiException catch (e) {
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    } finally {
      isActing.value = false;
    }
  }

  /// Report a pickup issue from the Home NOW card.
  Future<void> reportPickupIssue(String reason, {String? note}) async {
    final next = summary.value?.nextPickup;
    if (next == null || isActing.value) return;

    isActing.value = true;
    try {
      await _syncNextPickupLocation();
      await _bookingRepo.reportPickupIssue(
        next.uuid,
        assignmentId: next.assignmentId,
        reason: reason,
        note: note,
      );
      AppSnackbar.success('pickup_issue_reported'.tr);
      await load();
    } on ApiException catch (e) {
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    } finally {
      isActing.value = false;
    }
  }

  /// Jump to the Bookings tab filtered to [status].
  void goToBookings(String status) {
    Get.find<HomeController>().changeTab(1);
    final bookings = Get.find<BookingsController>();
    final index = BookingsController.tabs.indexOf(status);
    if (index >= 0) bookings.tabController.animateTo(index);
  }

  void openNotifications() {
    Get.toNamed(Routes.notifications)?.then((_) => _loadUnreadNotifications());
  }

  Future<void> _loadUnreadNotifications() async {
    if (!Get.isRegistered<PushNotificationService>()) {
      unreadNotifications.value = 0;
      return;
    }

    unreadNotifications.value = await Get.find<PushNotificationService>()
        .unreadCount();
  }

  Future<void> _syncNextPickupLocation() async {
    final next = summary.value?.nextPickup;
    final assignmentId = next?.assignmentId;
    if (next == null || assignmentId == null) return;

    try {
      await _trackingService.syncSnapshot(
        uuid: next.uuid,
        assignmentId: assignmentId,
      );
    } catch (_) {
      // Do not block the home action when location is unavailable.
    }
  }

  Future<bool> _ensureLocationReady() async {
    try {
      await _locationService.ensureReady();
      return true;
    } on LocationUnavailableException catch (e) {
      AppSnackbar.error(e.messageKey.tr);
    } catch (_) {
      AppSnackbar.error('location_unavailable'.tr);
    }

    return false;
  }

  /// The dashboard is the source of truth for which trip is in progress: it
  /// (re)starts the background session for it on every launch/refresh — also
  /// when the service survived a process restart — and stops a stale session
  /// when no trip is live any more.
  void _watchNextPickupTracking() {
    final next = summary.value?.nextPickup;
    if (next == null) {
      unawaited(_trackingService.stop());
      return;
    }

    final mode = _trackingModeFor(next);
    if (mode != DriverTrackingMode.live) {
      unawaited(_trackingService.stopLive());
    }

    _trackingService.watch(
      uuid: next.uuid,
      assignmentId: next.assignmentId,
      mode: mode,
      onLocationSynced: (location) =>
          _maybeShowNearPickupReminder(next, location),
    );
  }

  DriverTrackingMode _trackingModeFor(BookingListItem next) {
    final driverStatus = next.driverTripStatus;
    if (driverStatus == 'start' ||
        driverStatus == 'arrived_location' ||
        driverStatus == 'meet_passenger') {
      return DriverTrackingMode.live;
    }

    return switch (next.nextAction) {
      'arrived' || 'meet_passenger' || 'complete' => DriverTrackingMode.live,
      'start' => DriverTrackingMode.snapshot,
      _ => DriverTrackingMode.off,
    };
  }

  bool _navigatesToDropoff(String stage, String? nextAction) {
    return stage == 'meet_passenger' ||
        stage == 'drop_passenger' ||
        nextAction == 'complete';
  }

  void _maybeShowNearPickupReminder(
    BookingListItem booking,
    DriverLocation location,
  ) {
    const radiusMeters = 150.0;
    const maxAccuracyMeters = 100.0;

    if (booking.nextAction != 'arrived' ||
        !booking.pickupPlace.hasCoordinates) {
      return;
    }

    final accuracy = location.accuracyMeters;
    if (accuracy != null && accuracy > maxAccuracyMeters) {
      return;
    }

    final key = '${booking.uuid}:${booking.assignmentId ?? 'none'}';
    if (_nearPickupReminderKeys.contains(key)) {
      return;
    }

    final pickup = booking.pickupPlace;
    final distance = _distanceMeters(
      location.latitude,
      location.longitude,
      pickup.latitude!,
      pickup.longitude!,
    );

    if (distance > radiusMeters) {
      return;
    }

    _nearPickupReminderKeys.add(key);
    AppSnackbar.info('near_pickup_attention'.tr);
  }

  double _distanceMeters(double aLat, double aLng, double bLat, double bLng) {
    const radius = 6371000.0;
    final dLat = _radians(bLat - aLat);
    final dLng = _radians(bLng - aLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(aLat)) *
            math.cos(_radians(bLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  @override
  void onClose() {
    // Never stop a live background session from here.
    _trackingService.detach();
    super.onClose();
  }
}
