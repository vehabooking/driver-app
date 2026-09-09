import 'booking_payment.dart';
import 'place.dart';
import 'trip_staleness.dart';

/// Compact booking card (from `DriverBookingListResource`).
class BookingListItem {
  const BookingListItem({
    required this.uuid,
    required this.stage,
    this.assignmentId,
    this.bookingLegId,
    this.bookingLegUuid,
    this.bookingLegStatus,
    this.scheduleId,
    this.originId,
    this.destinationId,
    this.code,
    this.serviceType,
    this.tripType,
    this.isRoundTrip = false,
    this.driverTripStatus,
    this.customerName,
    this.customerPhone,
    this.routeOrigin,
    this.routeDestination,
    this.pickupPoint,
    this.pickupLocationName,
    this.pickupNearbyLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffPoint,
    this.dropoffLocationName,
    this.dropoffNearbyLocation,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.departureDatetime,
    this.legDepartureDatetime,
    this.linkedOutboundDatetime,
    this.linkedReturnDatetime,
    this.passengerCount,
    this.vehicleBooked,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleColor,
    this.vehicleSeats,
    this.acceptedAt,
    this.startBlockedBy,
    this.startAvailableAtRaw,
    this.needsResolution = false,
    this.resolutionAvailableAt,
    this.allowedActions = const [],
    this.pickupIssueReasonOptions = const [],
    this.pickupIssueNoteMaxLength = 500,
    this.payment = BookingPayment.none,
  });

  final String uuid;
  final String stage;
  final int? assignmentId;
  final int? bookingLegId;
  final String? bookingLegUuid;
  final String? bookingLegStatus;
  final int? scheduleId;
  final int? originId;
  final int? destinationId;
  final String? code;
  final String? serviceType;
  final String? tripType;
  final bool isRoundTrip;
  final String? driverTripStatus;
  final String? customerName;
  final String? customerPhone;
  final String? routeOrigin;
  final String? routeDestination;
  final String? pickupPoint;
  final String? pickupLocationName;
  final String? pickupNearbyLocation;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? dropoffPoint;
  final String? dropoffLocationName;
  final String? dropoffNearbyLocation;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String? departureDatetime;
  final String? legDepartureDatetime;
  final String? linkedOutboundDatetime;
  final String? linkedReturnDatetime;
  final int? passengerCount;
  final String? vehicleBooked;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? vehicleColor;
  final int? vehicleSeats;
  final String? acceptedAt;
  final BlockingTrip? startBlockedBy;

  /// Raw ISO-8601 `start_available_at` from the API.
  final String? startAvailableAtRaw;
  final bool needsResolution;
  final String? resolutionAvailableAt;
  final List<String> allowedActions;
  final List<String> pickupIssueReasonOptions;
  final int pickupIssueNoteMaxLength;

  /// Cash the driver must take from the passenger (onboard bookings). The list
  /// resource omits `collected_by`; [BookingPayment.none] when absent.
  final BookingPayment payment;

  /// Onboard cash is still outstanding on this trip.
  bool get requiresPaymentCollection => payment.requiresCollection;

  String get pickupLabel {
    if (pickupLocationName != null && pickupLocationName!.isNotEmpty) {
      return pickupLocationName!;
    }
    return pickupPoint ?? '—';
  }

  String get dropoffLabel {
    if (dropoffLocationName != null && dropoffLocationName!.isNotEmpty) {
      return dropoffLocationName!;
    }
    return dropoffPoint ?? '—';
  }

  String get routeOriginLabel {
    if (routeOrigin != null && routeOrigin!.isNotEmpty) return routeOrigin!;
    return pickupLabel;
  }

  String get routeDestinationLabel {
    if (routeDestination != null && routeDestination!.isNotEmpty) {
      return routeDestination!;
    }
    return dropoffLabel;
  }

  String get driverRouteOriginLabel => routeOriginLabel;

  String get driverRouteDestinationLabel => routeDestinationLabel;

  /// Whether a usable destination is present.
  bool get hasDropoff => dropoffLabel != '—';

  Place get pickupPlace => Place(
    address: pickupPoint,
    locationName: pickupLocationName,
    nearbyLocation: pickupNearbyLocation,
    latitude: pickupLatitude,
    longitude: pickupLongitude,
  );

  Place get dropoffPlace => Place(
    address: dropoffPoint,
    locationName: dropoffLocationName,
    nearbyLocation: dropoffNearbyLocation,
    latitude: dropoffLatitude,
    longitude: dropoffLongitude,
  );

  /// Whether a dialable customer phone is present.
  bool get hasPhone =>
      customerPhone != null &&
      customerPhone!.isNotEmpty &&
      customerPhone != 'N/A';

  bool get hasVehicle =>
      (vehicleBooked?.isNotEmpty ?? false) ||
      (vehicleModel?.isNotEmpty ?? false) ||
      (vehiclePlate?.isNotEmpty ?? false);

  String? get assignedVehicleLabel {
    final parts = <String>[
      if (vehicleModel != null && vehicleModel!.isNotEmpty) vehicleModel!,
      if (vehiclePlate != null && vehiclePlate!.isNotEmpty) vehiclePlate!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  bool get isReturnLeg => tripType == 'return';
  bool get isOutboundLeg => tripType == null || tripType == 'outbound';
  String get displayDepartureDatetime =>
      legDepartureDatetime ?? departureDatetime ?? '';

  String? get linkedLegDatetime =>
      isReturnLeg ? linkedOutboundDatetime : linkedReturnDatetime;

  /// The forward trip step to act on (start → arrived → meet_passenger →
  /// complete), ignoring the secondary pickup-issue action. Null when there's
  /// nothing to advance.
  String? get nextAction {
    for (final a in allowedActions) {
      if (a != 'report_pickup_issue') return a;
    }
    return null;
  }

  DateTime? get departureAt {
    final value = displayDepartureDatetime;
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  Duration? get startOverdueBy {
    final dt = departureAt;
    if (nextAction != 'start' || dt == null) return null;
    final diff = DateTime.now().difference(dt);
    return diff.isNegative ? null : diff;
  }

  bool get isStartOverdue {
    final diff = startOverdueBy;
    return diff != null && diff.inMinutes >= 0;
  }

  bool get isStartVeryOverdue {
    final diff = startOverdueBy;
    return diff != null && diff >= const Duration(hours: 2);
  }

  bool get isStartTooOld {
    final diff = startOverdueBy;
    return diff != null && diff >= const Duration(hours: 6);
  }

  /// How long ago this trip was due to depart, whatever step it is on.
  /// Null when the departure is still in the future or unknown.
  Duration? get departedAgo {
    final dt = departureAt;
    if (dt == null) return null;
    final diff = DateTime.now().difference(dt);
    return diff.isNegative ? null : diff;
  }

  /// A trip that is already under way but departed long ago - almost always a
  /// trip the driver forgot to finish, or one whose app was killed mid-trip.
  ///
  /// Distinct from [isStartTooOld], which only covers trips that were never
  /// started: every `isStart*` getter switches off the moment the trip begins.
  bool get isStaleInProgress {
    if (needsResolution) return true;
    final action = nextAction;
    if (action == null || action == 'start') return false;
    final diff = departedAgo;
    return diff != null && diff >= staleTripThreshold;
  }

  /// When the Start button unlocks, for a trip whose departure is still too
  /// far away. Null once Start is available (or when the trip is not gated).
  DateTime? get startAvailableAt {
    final value = startAvailableAtRaw;
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  /// Start is withheld only because departure is not close enough yet. The
  /// trip is the driver's - it simply cannot begin before its window opens.
  bool get isStartWindowClosed => startAvailableAt != null;

  bool get isStartBlocked => startBlockedBy != null && nextAction == null;

  factory BookingListItem.fromJson(Map<String, dynamic> json) {
    final routeSummary = _map(json['route_summary']);
    final leg = _map(json['leg']);
    final vehicle = _map(json['vehicle']);
    final blockedBy = _map(json['start_blocked_by']);

    return BookingListItem(
      uuid: _string(json['uuid']) ?? '',
      stage: _string(json['stage']) ?? 'assigned',
      assignmentId: _toInt(json['assignment_id']),
      bookingLegId: _toInt(leg['id'] ?? json['booking_leg_id']),
      bookingLegUuid: _string(leg['uuid']),
      bookingLegStatus: _string(leg['status']),
      scheduleId: _toInt(leg['schedule_id']),
      originId: _toInt(leg['origin_id']),
      destinationId: _toInt(leg['destination_id']),
      code: _string(json['code']),
      serviceType: _string(json['service_type']),
      tripType: _string(json['trip_type']),
      isRoundTrip: json['is_round_trip'] == true,
      driverTripStatus: _string(json['driver_trip_status']),
      customerName: _string(json['customer_name']),
      customerPhone: _string(json['customer_phone']),
      routeOrigin: _string(routeSummary['origin']),
      routeDestination: _string(routeSummary['destination']),
      pickupPoint: _string(json['pickup_point']),
      pickupLocationName: _string(json['pickup_location_name']),
      pickupNearbyLocation: _string(json['pickup_nearby_location']),
      pickupLatitude: _toDouble(json['pickup_latitude']),
      pickupLongitude: _toDouble(json['pickup_longitude']),
      dropoffPoint: _string(json['dropoff_point']),
      dropoffLocationName: _string(json['dropoff_location_name']),
      dropoffNearbyLocation: _string(json['dropoff_nearby_location']),
      dropoffLatitude: _toDouble(json['dropoff_latitude']),
      dropoffLongitude: _toDouble(json['dropoff_longitude']),
      departureDatetime: _string(json['departure_datetime']),
      legDepartureDatetime: _string(json['leg_departure_datetime']),
      linkedOutboundDatetime: _string(json['linked_outbound_datetime']),
      linkedReturnDatetime: _string(json['linked_return_datetime']),
      passengerCount: _toInt(json['passenger_count']),
      vehicleBooked: _string(vehicle['booked_name']),
      vehicleModel: _string(vehicle['model']),
      vehiclePlate: _string(vehicle['plate_number']),
      vehicleColor: _string(vehicle['color']),
      vehicleSeats: _toInt(vehicle['seats']),
      acceptedAt: _string(json['accepted_at']),
      startAvailableAtRaw: _string(json['start_available_at']),
      needsResolution: json['needs_resolution'] == true,
      resolutionAvailableAt: _string(json['resolution_available_at']),
      startBlockedBy: blockedBy.isEmpty
          ? null
          : BlockingTrip.fromJson(blockedBy),
      pickupIssueReasonOptions: _stringList(
        json['pickup_issue_reason_options'],
      ),
      pickupIssueNoteMaxLength:
          _toInt(json['pickup_issue_note_max_length']) ?? 500,
      allowedActions: _stringList(json['allowed_actions']),
      payment: BookingPayment.fromJson(_map(json['payment'])),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _string(dynamic v) {
    if (v == null) return null;
    final value = v.toString();
    return value.isEmpty ? null : value;
  }

  static Map<String, dynamic> _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
}

class BlockingTrip {
  const BlockingTrip({
    required this.uuid,
    this.assignmentId,
    this.bookingLegId,
    this.code,
    this.customerName,
    this.tripType,
    this.stage,
    this.legDepartureDatetime,
  });

  final String uuid;
  final int? assignmentId;
  final int? bookingLegId;
  final String? code;
  final String? customerName;
  final String? tripType;
  final String? stage;
  final String? legDepartureDatetime;

  factory BlockingTrip.fromJson(Map<String, dynamic> json) => BlockingTrip(
    uuid: BookingListItem._string(json['uuid']) ?? '',
    assignmentId: BookingListItem._toInt(json['assignment_id']),
    bookingLegId: BookingListItem._toInt(json['booking_leg_id']),
    code: BookingListItem._string(json['code']),
    customerName: BookingListItem._string(json['customer_name']),
    tripType: BookingListItem._string(json['trip_type']),
    stage: BookingListItem._string(json['stage']),
    legDepartureDatetime: BookingListItem._string(
      json['leg_departure_datetime'],
    ),
  );
}
