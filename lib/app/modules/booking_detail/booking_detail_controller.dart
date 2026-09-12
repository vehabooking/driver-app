import 'dart:async';

import 'package:get/get.dart';

import '../../core/location/driver_tracking_service.dart';
import '../../core/location/location_service.dart';
import '../../core/location/pickup_arrival_gate.dart';
import '../../core/maps/route_map_args.dart';
import '../../core/network/api_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/external_launcher.dart';
import '../../core/widgets/collect_payment_sheet.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/models/booking_detail.dart';
import '../../data/repositories/booking_repository.dart';

class BookingDetailController extends GetxController {
  final BookingRepository _repo = Get.find<BookingRepository>();
  final DriverTrackingService _trackingService =
      Get.find<DriverTrackingService>();
  final LocationService _locationService = Get.find<LocationService>();

  late final String uuid;
  late final int? assignmentId;

  final isLoading = false.obs;
  final isActing = false.obs;
  final error = RxnString();
  final Rxn<BookingDetail> booking = Rxn<BookingDetail>();
  final isLocating = false.obs;
  final Rxn<DriverLocation> driverLocation = Rxn<DriverLocation>();
  final RxnString locationMessage = RxnString();
  final Set<String> _nearPickupReminderKeys = {};

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      uuid = args['uuid']?.toString() ?? '';
      assignmentId = _parseId(args['assignment_id']);
    } else {
      uuid = args?.toString() ?? '';
      assignmentId = null;
    }
    load();
  }

  Future<void> load() async {
    if (uuid.isEmpty) {
      booking.value = null;
      error.value = 'error_generic'.tr;
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    error.value = null;
    try {
      booking.value = await _repo.show(uuid, assignmentId: assignmentId);
      _watchTracking();
    } on ApiException catch (e) {
      error.value = e.message;
    } catch (_) {
      error.value = 'error_generic'.tr;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshDriverLocation({bool showErrors = true}) async {
    if (isLocating.value) return;
    isLocating.value = true;
    locationMessage.value = null;
    try {
      final location = await _trackingService.syncSnapshot(
        uuid: uuid,
        assignmentId: _currentAssignmentId,
      );
      if (location != null) driverLocation.value = location;
    } on LocationUnavailableException catch (e) {
      locationMessage.value = e.messageKey.tr;
      if (showErrors) AppSnackbar.error(e.messageKey.tr);
    } catch (_) {
      locationMessage.value = 'location_unavailable'.tr;
      if (showErrors) AppSnackbar.error('location_unavailable'.tr);
    } finally {
      isLocating.value = false;
    }
  }

  // Trip lifecycle.
  Future<void> start() async {
    if (!await _ensureLocationReady()) {
      return;
    }

    await _act(
      () => _repo.start(uuid, assignmentId: _currentAssignmentId),
      'started_done'.tr,
    );

    // Same as the Home card: once the backend accepts Start, go straight to
    // the live map with the road route to the pickup point.
    if (booking.value?.driverTripStatus == 'start') {
      await openMap();
    }
  }

  Future<void> arrived() async {
    if (!await _ensureAtPickup()) return;

    await _act(
      () => _repo.arrived(uuid, assignmentId: _currentAssignmentId),
      'arrived_done'.tr,
    );
  }

  /// "Arrived" only counts when the driver is physically at the pickup point.
  /// Takes a fresh GPS fix (and stores it server-side) rather than trusting
  /// the last periodic sync.
  Future<bool> _ensureAtPickup() async {
    final b = booking.value;
    if (b == null) return false;

    final DriverLocation? location;
    try {
      location = await _trackingService.syncSnapshot(
        uuid: uuid,
        assignmentId: _currentAssignmentId,
      );
    } on LocationUnavailableException catch (e) {
      AppSnackbar.error(e.messageKey.tr);
      return false;
    } catch (_) {
      AppSnackbar.error('location_unavailable'.tr);
      return false;
    }
    if (location == null) {
      AppSnackbar.error('location_unavailable'.tr);
      return false;
    }
    driverLocation.value = location;

    final distance = PickupArrivalGate.distanceToPickup(
      location,
      pickupLatitude: b.pickup.latitude,
      pickupLongitude: b.pickup.longitude,
    );
    // No pickup coordinates → nothing to check against.
    if (distance == null) return true;

    final radius = b.arrivalRadiusMeters;
    if (!PickupArrivalGate.isWithinRadius(
      distance,
      location,
      radiusMeters: radius,
    )) {
      AppSnackbar.error(
        'arrived_too_far'.trParams({
          'distance': PickupArrivalGate.formatDistance(distance),
          'radius': PickupArrivalGate.formatDistance(radius),
        }),
      );
      return false;
    }
    return true;
  }

  Future<void> meetPassenger() async {
    await _act(
      () => _repo.meetPassenger(uuid, assignmentId: _currentAssignmentId),
      'met_done'.tr,
    );
  }

  /// Drop the passenger - always one confirmation first.
  ///
  /// Plain bookings get the Yes/No prompt. Onboard bookings get the same
  /// moment with the money on it, and confirming records the payment before
  /// completing. The server's own guard (`PAYMENT_NOT_COLLECTED`) falls back
  /// to that same dialog rather than a raw error.
  Future<void> complete() async {
    if (isActing.value) return;

    if (booking.value?.requiresPaymentCollection == true) {
      await _collectAndComplete();
      return;
    }

    if (!await confirmStepAction('complete')) return;

    final error = await _completeNow(reportErrors: false);
    if (error == null) return;

    if (error.errorCode == 'PAYMENT_NOT_COLLECTED') {
      await _collectAndComplete();
      return;
    }

    AppSnackbar.error(error.message);
  }

  Future<ApiException?> _completeNow({bool reportErrors = true}) => _act(
    () => _repo.complete(uuid, assignmentId: _currentAssignmentId),
    'completed_done'.tr,
    syncBefore: true,
    syncAfter: false,
    reportErrors: reportErrors,
  );

  /// The onboard drop: confirm + take the money + complete, in one dialog.
  Future<void> _collectAndComplete() async {
    final payment = booking.value?.payment;

    await showCollectPaymentDialog(
      amountLabel: payment?.amountLabel ?? '',
      note: payment?.note,
      loadMethods: _repo.paymentMethods,
      onConfirm: (paymentMethodId) async {
        // 1. Record the money. A failure stops here: the trip stays open.
        final failure = await _recordPayment(paymentMethodId);
        if (failure != null) return failure;

        // 2. Close the trip.
        final error = await _completeNow(reportErrors: false);
        return error?.message;
      },
    );
  }

  /// Records the collected payment. Null on success, else a message for the
  /// dialog to show.
  Future<String?> _recordPayment(int? paymentMethodId) async {
    isActing.value = true;
    try {
      booking.value = await _repo.collectPayment(
        uuid,
        assignmentId: _currentAssignmentId,
        paymentMethodId: paymentMethodId,
      );
      return null;
    } on ApiException catch (e) {
      // Someone else (vendor/admin) already recorded it, or the booking is not
      // an onboard one after all - either way there is nothing left to collect,
      // so let the completion carry on.
      if (e.errorCode == 'ALREADY_PAID' ||
          e.errorCode == 'PAYMENT_NOT_REQUIRED') {
        return null;
      }
      return e.message;
    } catch (_) {
      return 'error_generic'.tr;
    } finally {
      isActing.value = false;
    }
  }

  Future<void> resolveLateCompletion() async {
    final assignmentId = _currentAssignmentId;
    if (assignmentId == null) {
      AppSnackbar.error('error_generic'.tr);
      return;
    }

    await _act(
      () => _repo.resolveLateCompletion(uuid, assignmentId: assignmentId),
      'old_trip_resolved'.tr,
      syncAfter: false,
    );
  }

  /// Pickup issue → terminal outcome for this exact assignment leg.
  Future<void> reportPickupIssue(String reason, String? note) async {
    await _act(
      () => _repo.reportPickupIssue(
        uuid,
        assignmentId: _currentAssignmentId,
        reason: reason,
        note: note,
      ),
      'pickup_issue_reported'.tr,
      syncBefore: true,
      syncAfter: false,
    );
  }

  /// Run the action key from `allowed_actions`.
  Future<void> runAction(String action) {
    switch (action) {
      case 'start':
        return start();
      case 'arrived':
        return arrived();
      case 'meet_passenger':
        return meetPassenger();
      case 'complete':
        return complete();
      case 'resolve_completed':
        return resolveLateCompletion();
      default:
        return Future.value();
    }
  }

  /// Runs [action] with the shared acting/loading plumbing. Returns null on
  /// success, or the failure - already shown to the driver unless
  /// [reportErrors] is false, which lets the caller recover from it instead.
  Future<ApiException?> _act(
    Future<BookingDetail> Function() action,
    String successMsg, {
    bool syncBefore = false,
    bool syncAfter = true,
    bool reportErrors = true,
  }) async {
    if (isActing.value) return null;
    isActing.value = true;
    try {
      if (syncBefore) {
        await _syncCurrentLocationSnapshot();
      }
      booking.value = await action();
      _watchTracking();
      if (syncAfter) {
        unawaited(refreshDriverLocation(showErrors: false));
      }
      AppSnackbar.success(successMsg);
      return null;
    } on ApiException catch (e) {
      if (reportErrors) AppSnackbar.error(e.message);
      return e;
    } catch (_) {
      final e = ApiException(message: 'error_generic'.tr);
      if (reportErrors) AppSnackbar.error(e.message);
      return e;
    } finally {
      isActing.value = false;
    }
  }

  int? get _currentAssignmentId => assignmentId ?? booking.value?.assignmentId;

  int? _parseId(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _syncCurrentLocationSnapshot() async {
    try {
      final location = await _trackingService.syncSnapshot(
        uuid: uuid,
        assignmentId: _currentAssignmentId,
      );
      if (location != null) driverLocation.value = location;
    } catch (_) {
      // Location sync must not block the driver's trip workflow.
    }
  }

  /// Live tracking runs in the background service and is only torn down when
  /// this trip reaches a terminal state (mode → off); it deliberately survives
  /// leaving this screen (see [onClose]).
  void _watchTracking() {
    final b = booking.value;
    if (b == null) {
      _trackingService.detach();
      return;
    }

    _trackingService.watch(
      uuid: uuid,
      assignmentId: _currentAssignmentId,
      mode: _trackingModeFor(b),
      onLocationSynced: (location) => _maybeShowNearPickupReminder(b, location),
    );
  }

  DriverTrackingMode _trackingModeFor(BookingDetail b) {
    return DriverTrackingService.modeFor(
      bookingStatus: b.status,
      driverTripStatus: b.driverTripStatus,
      stage: b.stage,
      hasPickupIssue: b.pickupIssueReason != null,
    );
  }

  void _maybeShowNearPickupReminder(
    BookingDetail booking,
    DriverLocation location,
  ) {
    const radiusMeters = 150.0;
    const maxAccuracyMeters = 100.0;

    if (!booking.allows('arrived') || !booking.pickup.hasCoordinates) {
      return;
    }

    final accuracy = location.accuracyMeters;
    if (accuracy != null && accuracy > maxAccuracyMeters) {
      return;
    }

    final key = '${booking.uuid}:${_currentAssignmentId ?? 'none'}';
    if (_nearPickupReminderKeys.contains(key)) {
      return;
    }

    final distance = PickupArrivalGate.distanceMeters(
      location.latitude,
      location.longitude,
      booking.pickup.latitude!,
      booking.pickup.longitude!,
    );

    if (distance > radiusMeters) {
      return;
    }

    _nearPickupReminderKeys.add(key);
    AppSnackbar.info('near_pickup_attention'.tr);
  }

  Future<void> navigateToPickup() async {
    final b = booking.value;
    if (b == null) return;

    if (!await _ensureLocationReady()) {
      return;
    }

    final ok = await ExternalLauncher.navigateTo(
      latitude: b.pickup.latitude,
      longitude: b.pickup.longitude,
      address: b.pickup.address,
    );
    if (!ok) AppSnackbar.error('error_generic'.tr);
  }

  Future<void> navigateToActiveDestination() async {
    final b = booking.value;
    if (b == null) return;

    if (!await _ensureLocationReady()) {
      return;
    }

    final destination = switch (b.stage) {
      'meet_passenger' || 'drop_passenger' => b.dropoff,
      _ => b.pickup,
    };

    final ok = await ExternalLauncher.navigateTo(
      latitude: destination.latitude,
      longitude: destination.longitude,
      address: destination.address,
    );
    if (!ok) AppSnackbar.error('error_generic'.tr);
  }

  Future<void> openMap() async {
    final b = booking.value;
    if (b == null || !b.pickup.hasCoordinates || !b.dropoff.hasCoordinates) {
      return;
    }

    if (!await _ensureLocationReady()) {
      return;
    }

    Get.toNamed(
      Routes.tripMap,
      arguments: RouteMapArgs(
        uuid: uuid,
        assignmentId: _currentAssignmentId,
        title: 'trip_map'.tr,
        subtitle: b.code ?? b.customerName ?? '',
        pickup: b.pickup,
        dropoff: b.dropoff,
        navigateToDropoff:
            b.stage == 'meet_passenger' || b.stage == 'drop_passenger',
      ),
    )?.then((_) => load());
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

  Future<void> callCustomer() async {
    final phone = booking.value?.customerPhone;
    if (phone == null || phone.isEmpty || phone == 'N/A') return;
    await ExternalLauncher.call(phone);
  }

  Future<void> callOperator() async {
    final phone = booking.value?.operator?.phone;
    if (phone == null || phone.isEmpty || phone == 'N/A') {
      AppSnackbar.error('dispatch_phone_unavailable'.tr);
      return;
    }

    final launched = await ExternalLauncher.call(phone);
    if (!launched) {
      AppSnackbar.error('call_failed'.tr);
    }
  }

  Future<void> emailOperator() async {
    final email = booking.value?.operator?.email;
    if (email == null || email.isEmpty || email == 'N/A') {
      AppSnackbar.error('dispatch_email_unavailable'.tr);
      return;
    }

    final launched = await ExternalLauncher.email(email);
    if (!launched) {
      AppSnackbar.error('email_failed'.tr);
    }
  }

  @override
  void onClose() {
    // Keep a live background session running; only drop the screen-bound
    // snapshot timer and reminder callback.
    _trackingService.detach();
    super.onClose();
  }
}
