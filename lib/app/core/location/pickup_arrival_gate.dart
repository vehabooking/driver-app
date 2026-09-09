import 'dart:math' as math;

import 'location_service.dart';

/// Guards the "I've arrived" step: the driver must physically be at the
/// pickup point before the trip can advance.
///
/// The radius comes from the backend (`arrival_radius_meters` on the booking,
/// tuned via `TAXI_DRIVER_ARRIVAL_RADIUS_METERS`); the server re-checks the
/// driver's last posted location too. `0` disables the gate.
class PickupArrivalGate {
  PickupArrivalGate._();

  /// Fallback when the API doesn't send `arrival_radius_meters`.
  static const double defaultRadiusMeters = 100;

  /// GPS accuracy is added to the radius so a driver standing at the pickup
  /// with a mediocre fix isn't blocked — capped so a bad fix can't be abused.
  static const double maxAccuracyAllowanceMeters = 50;

  /// Distance from [location] to the pickup, or null when the pickup has no
  /// coordinates (nothing to check against).
  static double? distanceToPickup(
    DriverLocation location, {
    required double? pickupLatitude,
    required double? pickupLongitude,
  }) {
    if (pickupLatitude == null || pickupLongitude == null) return null;
    return distanceMeters(
      location.latitude,
      location.longitude,
      pickupLatitude,
      pickupLongitude,
    );
  }

  /// True when [distance] is inside the arrival zone for this fix.
  /// A [radiusMeters] of 0 (or less) means the gate is disabled.
  static bool isWithinRadius(
    double distance,
    DriverLocation location, {
    required double radiusMeters,
  }) {
    if (radiusMeters <= 0) return true;
    final allowance = math.min(
      location.accuracyMeters ?? 0,
      maxAccuracyAllowanceMeters,
    );
    return distance <= radiusMeters + allowance;
  }

  /// "85 m" / "1.2 km" for snackbars.
  static String formatDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  /// Haversine great-circle distance in meters.
  static double distanceMeters(
    double aLat,
    double aLng,
    double bLat,
    double bLng,
  ) {
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

  static double _radians(double degrees) => degrees * math.pi / 180;
}
