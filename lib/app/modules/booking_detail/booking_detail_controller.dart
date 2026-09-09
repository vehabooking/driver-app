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

    return _act(
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

  Future<void> meetPassenger() => _act(
    () => _repo.meetPassenger(uuid, assignmentId: _currentAssignmentId),
    'met_done'.tr,
  );

  Future<void> complete() => _act(
    () => _repo.complete(uuid, assignmentId: _currentAssignmentId),
    'completed_done'.tr,
    syncBefore: true,
    syncAfter: false,
  );

  Future<void> resolveLateCompletion() {
    final assignmentId = _currentAssignmentId;
    if (assignmentId == null) {
      AppSnackbar.error('error_generic'.tr);
      return Future.value();
    }

    return _act(
      () => _repo.resolveLateCompletion(uuid, assignmentId: assignmentId),
      'old_trip_resolved'.tr,
      syncAfter: false,
    );
  }

  /// Pickup issue → terminal outcome for this exact assignment leg.
  Future<void> reportPickupIssue(String reason, String? note) => _act(
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

  Future<void> _act(
    Future<BookingDetail> Function() action,
    String successMsg, {
    bool syncBefore = false,
    bool syncAfter = true,
  }) async {
    if (isActing.value) return;
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
    } on ApiException catch (e) {
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
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
    final status = b.status;
    final driverStatus = b.driverTripStatus;

    if (status == 'completed' ||
        status == 'cancelled' ||
        b.pickupIssueReason != null) {
      return DriverTrackingMode.off;
    }

    if (driverStatus == 'start' ||
        driverStatus == 'arrived_location' ||
        driverStatus == 'meet_passenger' ||
        b.stage == 'on_trip') {
      return DriverTrackingMode.live;
    }

    if (driverStatus == 'assigned' ||
        b.stage == 'assigned' ||
        b.stage == 'accepted') {
      return DriverTrackingMode.snapshot;
    }

    return DriverTrackingMode.off;
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
