import 'background_tracking_service.dart';

/// Silent pushes dispatch sends to steer the background location session.
///
/// A booking assigned for 14:00 is useless to dispatch if the last known
/// position is from whenever the driver last opened the app. Shortly before
/// departure the backend sends [startType] and the phone starts the same
/// foreground service a live trip uses — at a slower cadence, since this only
/// answers "where is he?" — even when the app is backgrounded or was never
/// opened. [stopType] takes it back down when the trip goes away without the
/// app being involved (cancelled, reassigned).
///
/// Both isolates run this: the UI one through `PushNotificationService`, the
/// FCM background one through `firebasePushBackgroundHandler`. Nothing here
/// may touch GetX or a registered service — see [TrackingSession].
class TrackingPushHandler {
  const TrackingPushHandler._();

  static const String startType = 'tracking.start';
  static const String stopType = 'tracking.stop';

  /// Guard rails for the cadence dispatch asks for: never hammer the GPS,
  /// never sit so idle that every fix is older than the staleness guard.
  static const Duration _minInterval = Duration(seconds: 10);
  static const Duration _maxInterval = Duration(minutes: 2);

  /// Whether [data] is one of the tracking pushes. These carry no copy and
  /// must never be shown to the driver.
  static bool handles(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    return type == startType || type == stopType;
  }

  /// Act on a tracking push. [session] is only resolved when a session
  /// actually has to be started, and reads its values from wherever the
  /// calling isolate can reach them.
  static Future<void> handle(
    Map<String, dynamic> data, {
    required Future<TrackingSession?> Function() session,
  }) async {
    final type = data['type']?.toString();
    final assignmentId = int.tryParse(data['assignment_id']?.toString() ?? '');
    if (assignmentId == null) return;

    try {
      if (type == stopType) {
        await _stop(assignmentId);
        return;
      }
      if (type != startType) return;

      final uuid = data['booking_uuid']?.toString();
      if (uuid == null || uuid.isEmpty) return;

      await _start(
        uuid: uuid,
        assignmentId: assignmentId,
        interval: _interval(data['interval_seconds']),
        session: session,
      );
    } catch (_) {
      // A push must never crash the isolate handling it.
    }
  }

  static Future<void> _start({
    required String uuid,
    required int assignmentId,
    required Duration interval,
    required Future<TrackingSession?> Function() session,
  }) async {
    // Idempotent, and deliberately blind to which trip is running: a session
    // already reporting answers this push too. Restarting it would at best
    // reset the 12h cap and at worst slow a started trip down from its 20s
    // cadence to the pre-trip one — dispatch would lose the live trail.
    if (await BackgroundTrackingService.isRunning) return;

    final resolved = await session();
    if (resolved == null) return;

    // A refusal (permission gone, OS quota) has no fallback here — the app
    // may not even be running — so it is simply left to the backend, which
    // re-sends the trigger while the driver stays quiet.
    await BackgroundTrackingService.start(
      baseUrl: resolved.baseUrl,
      token: resolved.token,
      locale: resolved.locale,
      uuid: uuid,
      assignmentId: assignmentId,
      interval: interval,
    );
  }

  static Future<void> _stop(int assignmentId) async {
    final running = await BackgroundTrackingService.runningTarget();
    // Only this assignment's session: a stop for a reassigned leg must not
    // kill the session of the trip the driver is actually on.
    if (running == null || running.assignmentId != assignmentId) return;

    await BackgroundTrackingService.stop();
  }

  static Duration _interval(Object? value) {
    final seconds = int.tryParse(value?.toString() ?? '');
    if (seconds == null) return BackgroundTrackingService.defaultInterval;

    final interval = Duration(seconds: seconds);
    if (interval < _minInterval) return _minInterval;
    if (interval > _maxInterval) return _maxInterval;
    return interval;
  }
}

/// What the background service needs to post a fix, resolved per isolate:
/// from `ApiClient`/`StorageService` in the UI isolate, straight from storage
/// in the FCM background isolate where no service is registered.
class TrackingSession {
  const TrackingSession({
    required this.baseUrl,
    required this.token,
    required this.locale,
  });

  final String baseUrl;
  final String token;
  final String locale;
}
