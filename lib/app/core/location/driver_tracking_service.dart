import 'dart:async';

import 'package:get/get.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../storage/storage_service.dart';
import '../utils/app_snackbar.dart';
import '../../data/repositories/booking_repository.dart';
import 'background_tracking_service.dart';
import 'location_service.dart';

enum DriverTrackingMode { off, snapshot, live }

typedef DriverLocationSyncedCallback =
    FutureOr<void> Function(DriverLocation location);

/// Keeps the backend informed of the driver's position.
///
/// Two flavours:
///   - [DriverTrackingMode.snapshot] — an assigned, not-yet-started trip. A
///     low-frequency Dart timer that only lives while the screen watching it
///     is open (see [detach]).
///   - [DriverTrackingMode.live] — a trip in progress. Delegated to
///     [BackgroundTrackingService] (foreground service / background location)
///     so it survives leaving the screen, backgrounding the app, the lock
///     screen and external navigation. It is only torn down when the trip
///     ends ([DriverTrackingMode.off]), on logout ([stop]) or after
///     [maxLiveDuration].
///
/// If the platform refuses to start the service, live mode falls back to the
/// in-process timer so tracking still works while the app is in front.
class DriverTrackingService extends GetxService {
  DriverTrackingService(
    this._bookingRepository,
    this._locationService,
    this._api,
    this._storage,
  );

  static const Duration snapshotInterval = Duration(minutes: 3);
  static const Duration liveInterval =
      BackgroundTrackingService.defaultInterval;
  static const Duration maxLiveDuration = BackgroundTrackingService.maxDuration;

  final BookingRepository _bookingRepository;
  final LocationService _locationService;
  final ApiClient _api;
  final StorageService _storage;

  Timer? _timer;
  String? _activeKey;
  DateTime? _watchStartedAt;
  DriverTrackingMode _mode = DriverTrackingMode.off;
  DriverLocationSyncedCallback? _onLocationSynced;
  bool _isSyncing = false;
  bool _expiredNoticeShown = false;
  Future<void>? _ensuringLive;

  /// Bumped by [stop] so an in-flight service start can tell it was
  /// superseded (a plain [detach] must not have that effect).
  int _stopCount = 0;

  @override
  void onInit() {
    super.onInit();
    BackgroundTrackingService.init();
    BackgroundTrackingService.listen(_onBackgroundEvent);
  }

  Future<DriverLocation?> syncSnapshot({
    required String uuid,
    required int? assignmentId,
  }) async {
    if (uuid.isEmpty || assignmentId == null) return null;

    final location = await _locationService.current();
    await _bookingRepository.storeLocation(
      uuid,
      assignmentId: assignmentId,
      location: location,
    );

    return location;
  }

  /// Track [uuid]/[assignmentId] in [mode] on behalf of the screen that is
  /// currently showing it.
  ///
  /// [DriverTrackingMode.off] stops the background session only when it is
  /// tracking this very trip — opening a completed booking must not kill the
  /// live session of another trip.
  void watch({
    required String uuid,
    required int? assignmentId,
    required DriverTrackingMode mode,
    DriverLocationSyncedCallback? onLocationSynced,
  }) {
    if (uuid.isEmpty || assignmentId == null) {
      detach();
      return;
    }

    if (mode == DriverTrackingMode.off) {
      detach();
      unawaited(stopLive(uuid: uuid, assignmentId: assignmentId));
      return;
    }

    final key = '$uuid:$assignmentId';
    if (_activeKey == key && _mode == mode) {
      _onLocationSynced = onLocationSynced;
      if (mode == DriverTrackingMode.live) {
        unawaited(_ensureLiveService(uuid: uuid, assignmentId: assignmentId));
      }
      return;
    }

    _cancelTimer();
    _activeKey = key;
    _mode = mode;
    _onLocationSynced = onLocationSynced;
    _watchStartedAt = DateTime.now();
    _expiredNoticeShown = false;

    if (mode == DriverTrackingMode.live) {
      unawaited(_ensureLiveService(uuid: uuid, assignmentId: assignmentId));
      return;
    }

    // Report once straight away, then on the interval. Waiting the full three
    // minutes meant a driver who opened the app was invisible to dispatch for
    // longer than most people keep the app open.
    unawaited(_safeSync(uuid: uuid, assignmentId: assignmentId));
    _startTimer(snapshotInterval, uuid: uuid, assignmentId: assignmentId);
  }

  /// The watching screen is going away. Drops the snapshot timer and the
  /// foreground-only callback but leaves a live background session running.
  void detach() {
    _cancelTimer();
    _activeKey = null;
    _watchStartedAt = null;
    _mode = DriverTrackingMode.off;
    _onLocationSynced = null;
  }

  /// Stop everything, including the background session (logout, or the
  /// server says no trip is in progress).
  Future<void> stop() async {
    _stopCount++;
    detach();
    await BackgroundTrackingService.stop();
  }

  /// Stop the background session. When [uuid]/[assignmentId] are given, only
  /// stops a session that tracks that exact trip.
  Future<void> stopLive({String? uuid, int? assignmentId}) async {
    if (uuid != null && assignmentId != null) {
      final target = await BackgroundTrackingService.runningTarget();
      if (target != null && !target.matches(uuid, assignmentId)) return;
    }
    await BackgroundTrackingService.stop();
  }

  /// Serialised so back-to-back [watch] calls (load → action → refresh) never
  /// race two `startService` requests.
  Future<void> _ensureLiveService({
    required String uuid,
    required int assignmentId,
  }) {
    final pending = _ensuringLive;
    if (pending != null) {
      return pending.then(
        (_) => _ensureLiveService(uuid: uuid, assignmentId: assignmentId),
      );
    }

    final run = _ensureLiveServiceNow(uuid: uuid, assignmentId: assignmentId);
    _ensuringLive = run;
    return run.whenComplete(() {
      if (identical(_ensuringLive, run)) _ensuringLive = null;
    });
  }

  Future<void> _ensureLiveServiceNow({
    required String uuid,
    required int assignmentId,
  }) async {
    if (_activeKey != '$uuid:$assignmentId' ||
        _mode != DriverTrackingMode.live) {
      return;
    }

    final token = _api.token;
    if (token == null || token.isEmpty) return;

    final stopCountAtStart = _stopCount;
    try {
      final running = await BackgroundTrackingService.runningTarget();
      if (running != null && running.matches(uuid, assignmentId)) {
        if (running.isExpired) {
          _notifyTrackingExpired();
          await BackgroundTrackingService.stop();
          return;
        }
        // The trip may already be tracked at the slower pre-trip cadence
        // dispatch asked for before departure; now it is live, so fall
        // through and restart it at [liveInterval].
        if (running.interval == liveInterval) return;
      }

      await BackgroundTrackingService.ensureNotificationPermission();

      final started = await BackgroundTrackingService.start(
        baseUrl: AppConfig.bookingsApiUrl,
        token: token,
        locale: _storage.locale ?? 'en_US',
        uuid: uuid,
        assignmentId: assignmentId,
        interval: liveInterval,
      );
      if (started) {
        // [stop] raced the start (e.g. logout mid-request): honour it.
        if (_stopCount != stopCountAtStart) {
          await BackgroundTrackingService.stop();
          return;
        }
        _cancelTimer();
        return;
      }
    } catch (_) {
      // Fall through to the in-process timer.
    }

    _fallbackToTimer(uuid: uuid, assignmentId: assignmentId);
  }

  /// The platform would not start the service: keep tracking from the main
  /// isolate (foreground only) so the trip is not left blind.
  void _fallbackToTimer({required String uuid, required int assignmentId}) {
    if (_activeKey != '$uuid:$assignmentId' ||
        _mode != DriverTrackingMode.live) {
      return;
    }
    if (_timer?.isActive == true) return;

    AppSnackbar.info('tracking_background_unavailable'.tr);
    unawaited(_safeSync(uuid: uuid, assignmentId: assignmentId));
    _startTimer(liveInterval, uuid: uuid, assignmentId: assignmentId);
  }

  void _startTimer(
    Duration interval, {
    required String uuid,
    required int assignmentId,
  }) {
    _timer = Timer.periodic(interval, (_) {
      if (_mode == DriverTrackingMode.live && _liveWindowExpired) {
        _notifyTrackingExpired();
        detach();
        return;
      }

      unawaited(_safeSync(uuid: uuid, assignmentId: assignmentId));
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  bool get _liveWindowExpired {
    final startedAt = _watchStartedAt;
    if (startedAt == null) return false;

    return DateTime.now().difference(startedAt) > maxLiveDuration;
  }

  void _notifyTrackingExpired() {
    if (_expiredNoticeShown) return;

    _expiredNoticeShown = true;
    AppSnackbar.info('tracking_action_required'.tr);
  }

  /// Messages from the task isolate: forward live fixes to the watching
  /// screen (near-pickup reminder) and surface the 12h expiry.
  void _onBackgroundEvent(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final key = '${data['uuid']}:${data['assignment_id']}';

    if (type == BackgroundTrackingService.eventExpired) {
      _notifyTrackingExpired();
      return;
    }

    if (type != BackgroundTrackingService.eventLocation ||
        _mode != DriverTrackingMode.live ||
        _activeKey != key) {
      return;
    }

    final latitude = _toDouble(data['latitude']);
    final longitude = _toDouble(data['longitude']);
    if (latitude == null || longitude == null) return;

    final location = DriverLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: _toDouble(data['accuracy']),
      speedMetersPerSecond: _toDouble(data['speed']),
      heading: _toDouble(data['heading']),
    );
    unawaited(_notifySynced(location));
  }

  Future<void> _notifySynced(DriverLocation location) async {
    try {
      await _onLocationSynced?.call(location);
    } catch (_) {
      // UI reminders must never break tracking.
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<void> _safeSync({
    required String uuid,
    required int assignmentId,
  }) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final location = await syncSnapshot(
        uuid: uuid,
        assignmentId: assignmentId,
      );
      if (location != null) {
        await _onLocationSynced?.call(location);
      }
    } catch (_) {
      // Tracking must never block the driver's trip workflow.
    } finally {
      _isSyncing = false;
    }
  }

  @override
  void onClose() {
    BackgroundTrackingService.listen(null);
    detach();
    super.onClose();
  }
}
