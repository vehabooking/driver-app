import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

/// Live-trip location tracking that outlives the UI.
///
/// Runs as a `flutter_foreground_task` service (Android foreground service
/// with a persistent notification; iOS background-location session) so the
/// driver's position keeps reaching the backend while the app is backgrounded,
/// the screen is locked, or the driver is navigating in Google Maps.
///
/// The task runs in its own isolate with no access to GetX/DI, so everything
/// it needs (endpoint, bearer token, locale, trip identifiers) is handed over
/// through [FlutterForegroundTask.saveData] before the service starts. The
/// main isolate only ever talks to this class through the static helpers.
class BackgroundTrackingService {
  const BackgroundTrackingService._();

  /// How often the task posts a fix while a trip is live. Also the fallback
  /// for a session started without an explicit cadence — dispatch's pre-trip
  /// push asks for a slower one (see [start]).
  static const Duration defaultInterval = Duration(seconds: 20);

  /// Hard cap so a forgotten trip never tracks forever.
  static const Duration maxDuration = Duration(hours: 12);

  static const int _serviceId = 4101;
  static const String _channelId = 'veha_trip_tracking';

  // Keys shared between the main isolate and the task isolate.
  static const String _keyBaseUrl = 'tracking.base_url';
  static const String _keyToken = 'tracking.token';
  static const String _keyLocale = 'tracking.locale';
  static const String _keyUuid = 'tracking.uuid';
  static const String _keyAssignmentId = 'tracking.assignment_id';
  static const String _keyStartedAt = 'tracking.started_at';
  static const String _keyIntervalSeconds = 'tracking.interval_seconds';

  /// Message types sent from the task isolate to the main isolate.
  static const String eventLocation = 'location';
  static const String eventExpired = 'expired';

  static bool _initialized = false;

  /// One-time setup for the UI isolate. Safe to call more than once.
  ///
  /// Deliberately not called from the FCM background isolate: registering the
  /// communication port there would steal the port name from the UI isolate
  /// and silence its location callbacks. That isolate only ever needs
  /// [_configure], which [start] does for it.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.initCommunicationPort();
    _configure(defaultInterval);
  }

  /// Hands the plugin the options the next `startService` will be given.
  /// The reporting cadence is per session, so it is applied here rather than
  /// baked into a constant.
  static void _configure(Duration interval) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: 'Trip tracking',
        channelDescription:
            'Shown while a trip is in progress and your live location is '
            'shared with dispatch and the passenger.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(interval.inMilliseconds),
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
      ),
    );
  }

  /// Whether the service is currently running (for any trip).
  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// The trip the running service is tracking, or `null` when not running.
  static Future<BackgroundTrackingTarget?> runningTarget() async {
    if (!await isRunning) return null;

    final uuid = await FlutterForegroundTask.getData<String>(key: _keyUuid);
    final assignmentId = await FlutterForegroundTask.getData<int>(
      key: _keyAssignmentId,
    );
    final startedAt = await FlutterForegroundTask.getData<int>(
      key: _keyStartedAt,
    );
    final intervalSeconds = await FlutterForegroundTask.getData<int>(
      key: _keyIntervalSeconds,
    );
    if (uuid == null || assignmentId == null) return null;

    return BackgroundTrackingTarget(
      uuid: uuid,
      assignmentId: assignmentId,
      interval: intervalSeconds == null
          ? defaultInterval
          : Duration(seconds: intervalSeconds),
      startedAt: startedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startedAt),
    );
  }

  /// Android 13+ needs the notification permission for the persistent
  /// notification. A denial is tolerated — the service still runs, the
  /// notification is simply hidden.
  static Future<void> ensureNotificationPermission() async {
    try {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {
      // Never block tracking on the permission prompt.
    }
  }

  /// Start (or restart with new data) the tracking service for one trip.
  ///
  /// [interval] is how often the task posts a fix: [defaultInterval] for a
  /// live trip, whatever dispatch asked for in the pre-trip push otherwise.
  /// Returns `false` when the platform refused to start it.
  ///
  /// Callable from the FCM background isolate — it touches nothing but the
  /// plugin.
  static Future<bool> start({
    required String baseUrl,
    required String token,
    required String locale,
    required String uuid,
    required int assignmentId,
    Duration interval = defaultInterval,
  }) async {
    _configure(interval);

    // A running service cannot be re-paced: `restartService` reuses the
    // options it was started with. Changing cadence (pre-trip 60s → live 20s)
    // therefore means dropping the service and starting a clean one.
    final wasRunning = await isRunning;
    final keepsCadence = wasRunning && await _runsAt(interval);
    if (wasRunning && !keepsCadence) {
      await FlutterForegroundTask.stopService();
    }

    await Future.wait([
      FlutterForegroundTask.saveData(key: _keyBaseUrl, value: baseUrl),
      FlutterForegroundTask.saveData(key: _keyToken, value: token),
      FlutterForegroundTask.saveData(key: _keyLocale, value: locale),
      FlutterForegroundTask.saveData(key: _keyUuid, value: uuid),
      FlutterForegroundTask.saveData(
        key: _keyAssignmentId,
        value: assignmentId,
      ),
      FlutterForegroundTask.saveData(
        key: _keyIntervalSeconds,
        value: interval.inSeconds,
      ),
      FlutterForegroundTask.saveData(
        key: _keyStartedAt,
        value: DateTime.now().millisecondsSinceEpoch,
      ),
    ]);

    final ServiceRequestResult result;
    if (keepsCadence) {
      // Restart re-runs onStart so the handler picks up the new trip data.
      result = await FlutterForegroundTask.restartService();
    } else {
      result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: 'Veha Driver',
        notificationText: 'Trip in progress · sharing live location',
        callback: backgroundTrackingCallback,
      );
    }

    return result is ServiceRequestSuccess;
  }

  /// Whether the running service already reports at [interval].
  static Future<bool> _runsAt(Duration interval) async {
    final seconds = await FlutterForegroundTask.getData<int>(
      key: _keyIntervalSeconds,
    );
    return (seconds ?? defaultInterval.inSeconds) == interval.inSeconds;
  }

  /// Stop the service and forget the hand-over data (including the token).
  static Future<void> stop() async {
    try {
      if (await isRunning) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {
      // Best effort; the data wipe below is what matters.
    }
    await _clearData();
  }

  static Future<void> _clearData() async {
    for (final key in const [
      _keyBaseUrl,
      _keyToken,
      _keyLocale,
      _keyUuid,
      _keyAssignmentId,
      _keyIntervalSeconds,
      _keyStartedAt,
    ]) {
      await FlutterForegroundTask.removeData(key: key);
    }
  }

  static DataCallback? _listener;

  /// Subscribe the main isolate to messages posted by the task isolate (see
  /// [eventLocation] and [eventExpired]). Only one listener is kept; passing
  /// `null` unsubscribes.
  static void listen(void Function(Map<String, dynamic> data)? onData) {
    final previous = _listener;
    if (previous != null) {
      FlutterForegroundTask.removeTaskDataCallback(previous);
      _listener = null;
    }
    if (onData == null) return;

    init();
    _listener = (Object data) {
      if (data is Map) onData(Map<String, dynamic>.from(data));
    };
    FlutterForegroundTask.addTaskDataCallback(_listener!);
  }
}

/// Identifies the trip a running background session belongs to.
class BackgroundTrackingTarget {
  const BackgroundTrackingTarget({
    required this.uuid,
    required this.assignmentId,
    this.interval = BackgroundTrackingService.defaultInterval,
    this.startedAt,
  });

  final String uuid;
  final int assignmentId;

  /// The cadence the session is running at — a live trip reports every
  /// [BackgroundTrackingService.defaultInterval], a pre-trip session slower.
  final Duration interval;
  final DateTime? startedAt;

  bool matches(String uuid, int assignmentId) =>
      this.uuid == uuid && this.assignmentId == assignmentId;

  bool get isExpired {
    final started = startedAt;
    if (started == null) return false;
    return DateTime.now().difference(started) >
        BackgroundTrackingService.maxDuration;
  }
}

/// Entry point for the task isolate. Must stay top-level so the engine can
/// look it up after the main isolate is gone.
@pragma('vm:entry-point')
void backgroundTrackingCallback() {
  FlutterForegroundTask.setTaskHandler(_BackgroundTrackingTaskHandler());
}

class _BackgroundTrackingTaskHandler extends TaskHandler {
  String? _baseUrl;
  String? _token;
  String? _locale;
  String? _uuid;
  int? _assignmentId;
  Duration _interval = BackgroundTrackingService.defaultInterval;
  DateTime? _startedAt;

  StreamSubscription<Position>? _positions;
  Position? _latest;
  bool _isPosting = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _loadData();
    _startPositionStream();
    unawaited(_post());
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_isExpired) {
      FlutterForegroundTask.sendDataToMain({
        'type': BackgroundTrackingService.eventExpired,
        'uuid': _uuid,
        'assignment_id': _assignmentId,
      });
      unawaited(FlutterForegroundTask.stopService());
      return;
    }

    unawaited(_post());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positions?.cancel();
    _positions = null;
  }

  // Tapping the notification opens the app's launcher activity by default
  // (plugin behaviour); no override needed.

  Future<void> _loadData() async {
    _baseUrl = await FlutterForegroundTask.getData<String>(
      key: BackgroundTrackingService._keyBaseUrl,
    );
    _token = await FlutterForegroundTask.getData<String>(
      key: BackgroundTrackingService._keyToken,
    );
    _locale = await FlutterForegroundTask.getData<String>(
      key: BackgroundTrackingService._keyLocale,
    );
    _uuid = await FlutterForegroundTask.getData<String>(
      key: BackgroundTrackingService._keyUuid,
    );
    _assignmentId = await FlutterForegroundTask.getData<int>(
      key: BackgroundTrackingService._keyAssignmentId,
    );
    final intervalSeconds = await FlutterForegroundTask.getData<int>(
      key: BackgroundTrackingService._keyIntervalSeconds,
    );
    _interval = intervalSeconds == null
        ? BackgroundTrackingService.defaultInterval
        : Duration(seconds: intervalSeconds);
    final startedAt = await FlutterForegroundTask.getData<int>(
      key: BackgroundTrackingService._keyStartedAt,
    );
    _startedAt = startedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(startedAt);
  }

  bool get _isExpired {
    final started = _startedAt;
    if (started == null) return false;
    return DateTime.now().difference(started) >
        BackgroundTrackingService.maxDuration;
  }

  /// A continuous stream keeps the GPS warm and — on iOS — is what keeps the
  /// process alive in the background (`UIBackgroundModes: location`). The
  /// periodic post uses the freshest fix from it, falling back to a one-shot
  /// request when the stream has been quiet.
  void _startPositionStream() {
    _positions?.cancel();

    final LocationSettings settings;
    if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    try {
      _positions = Geolocator.getPositionStream(locationSettings: settings)
          .listen(
            (position) => _latest = position,
            onError: (_) {
              // Keep going; the periodic one-shot request still works.
            },
            cancelOnError: false,
          );
    } catch (_) {
      _positions = null;
    }
  }

  /// A fix is only worth posting while it still describes where the driver is.
  ///
  /// The stream can stall (permission revoked, the OS throttling a background
  /// app) and a one-shot read can time out indoors. Falling back to whatever
  /// `_latest` held meant a frozen position was re-posted every tick and the
  /// server stamped it as current - a driver in Siem Reap showing in Phnom
  /// Penh. Better to send nothing and let the dashboard mark them stale.
  static const Duration _maxFixAge = Duration(minutes: 2);

  Future<Position?> _currentPosition() async {
    final latest = _latest;
    // A streamed fix from within this tick is as good as a new read — but a
    // slow (pre-trip) cadence must not stretch that past [_maxFixAge].
    final reusable = _interval < _maxFixAge ? _interval : _maxFixAge;
    if (_isFresh(latest, reusable)) return latest;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      // Only reuse the streamed fix while it is still recent enough to be true.
      return _isFresh(latest, _maxFixAge) ? latest : null;
    }
  }

  bool _isFresh(Position? position, Duration within) {
    if (position == null) return false;
    final age = DateTime.now().difference(position.timestamp);
    return !age.isNegative && age < within;
  }

  Future<void> _post() async {
    if (_isPosting) return;
    _isPosting = true;
    try {
      final baseUrl = _baseUrl;
      final token = _token;
      final uuid = _uuid;
      final assignmentId = _assignmentId;
      if (baseUrl == null ||
          token == null ||
          token.isEmpty ||
          uuid == null ||
          uuid.isEmpty ||
          assignmentId == null) {
        return;
      }

      final position = await _currentPosition();
      // Never report a position the device recorded long ago: a stale fix
      // posted as current is worse than a gap in the trail.
      if (position == null || !_isFresh(position, _maxFixAge)) return;

      final speedKmh = _speedKmh(position.speed);
      final payload = <String, dynamic>{
        'assignment_id': assignmentId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        if (!position.accuracy.isNaN) 'accuracy': position.accuracy,
        'speed': ?speedKmh,
        if (!position.heading.isNaN) 'heading': position.heading,
        'is_moving': (speedKmh ?? 0) > 3,
        'is_mock_location': position.isMocked,
        'provider': 'foreground_service',
      };

      await _send(
        Uri.parse('$baseUrl/bookings/$uuid/location'),
        payload,
        token: token,
        locale: _locale ?? 'en_US',
      );

      FlutterForegroundTask.sendDataToMain({
        'type': BackgroundTrackingService.eventLocation,
        'uuid': uuid,
        'assignment_id': assignmentId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy.isNaN ? null : position.accuracy,
        'speed': position.speed.isNaN ? null : position.speed,
        'heading': position.heading.isNaN ? null : position.heading,
      });
    } catch (_) {
      // The service must never die because of a bad fix or network blip.
    } finally {
      _isPosting = false;
    }
  }

  double? _speedKmh(double metersPerSecond) {
    if (metersPerSecond.isNaN || metersPerSecond < 0) return null;
    return metersPerSecond * 3.6;
  }

  /// Plain `dart:io` POST — mirrors the headers ApiClient sends.
  Future<void> _send(
    Uri url,
    Map<String, dynamic> payload, {
    required String token,
    required String locale,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(url);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set('Content-Language', locale);
      request.write(jsonEncode(payload));

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      // Drain so the connection can be reused/closed cleanly.
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
  }
}
