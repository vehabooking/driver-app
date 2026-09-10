import 'package:geolocator/geolocator.dart';

class DriverLocation {
  const DriverLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    this.heading,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speedMetersPerSecond;
  final double? heading;

  double? get speedKmh {
    final speed = speedMetersPerSecond;
    if (speed == null || speed.isNaN || speed < 0) {
      return null;
    }

    return speed * 3.6;
  }

  bool get isMoving => (speedKmh ?? 0) > 3;
}

class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.messageKey);

  final String messageKey;
}

class LocationService {
  /// A fix older than this no longer says where the driver is. The platform
  /// can answer a one-shot read from its cache, so the age is checked rather
  /// than trusted.
  static const Duration maxFixAge = Duration(minutes: 2);

  Future<void> ensureReady() => _ensurePermission();

  Future<DriverLocation> current() async {
    await _ensurePermission();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    final age = DateTime.now().difference(position.timestamp);
    if (!age.isNegative && age > maxFixAge) {
      throw const LocationUnavailableException('location_unavailable');
    }

    return DriverLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedMetersPerSecond: position.speed.isNaN ? null : position.speed,
      heading: position.heading.isNaN ? null : position.heading,
    );
  }

  Stream<DriverLocation> liveStream({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilterMeters = 5,
  }) async* {
    await _ensurePermission();

    yield* Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    ).map(
      (position) => DriverLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        speedMetersPerSecond: position.speed.isNaN ? null : position.speed,
        heading: position.heading.isNaN ? null : position.heading,
      ),
    );
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationUnavailableException('location_service_disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationUnavailableException('location_permission_denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException(
        'location_permission_denied_forever',
      );
    }
  }
}
