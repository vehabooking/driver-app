import '../../core/location/pickup_arrival_gate.dart';
import 'booking_payment.dart';
import 'place.dart';
import 'trip_staleness.dart';

/// Full booking detail (from `DriverBookingDetailResource`).
class BookingDetail {
  const BookingDetail({
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
    this.status,
    this.driverPickupStatus,
    this.driverTripStatus,
    this.acceptedAt,
    this.startedAt,
    this.arrivedAt,
    this.metPassengerAt,
    this.droppedAt,
    this.pickupIssueReason,
    this.pickupIssueReasonOptions = const [],
    this.pickupIssueNoteMaxLength = 500,
    this.allowedActions = const [],
    this.startLocked = false,
    this.startAvailableAtRaw,
    this.arrivalRadiusMeters = PickupArrivalGate.defaultRadiusMeters,
    this.needsResolution = false,
    this.resolutionAvailableAt,
    this.lateResolvedAt,
    this.lateResolutionType,
    this.lateResolutionNote,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.pickup = const Place(),
    this.dropoff = const Place(),
    this.payment = BookingPayment.none,
    this.routeOrigin,
    this.routeDestination,
    this.departureDatetime,
    this.legDepartureDatetime,
    this.linkedOutboundDatetime,
    this.linkedReturnDatetime,
    this.arrivalDatetime,
    this.duration,
    this.passengerCount,
    this.nationality,
    this.notes,
    this.vehicleBooked,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleColor,
    this.vehicleSeats,
    this.operator,
    this.isReturn = false,
    this.returnDate,
    this.returnTime,
    this.flightNumber,
    this.airline,
    this.terminal,
    this.flightDatetime,
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
  final String? status;
  final String? driverPickupStatus;
  final String? driverTripStatus;

  /// The "arrive 15 minutes early" rule only helps while the driver is still
  /// on their way to the pickup. Once they have arrived — let alone picked the
  /// passenger up — it is stale advice sitting above the next action.
  bool get showsArrivalRule =>
      driverTripStatus == null ||
      driverTripStatus == 'assigned' ||
      driverTripStatus == 'start';
  final String? acceptedAt;
  final String? startedAt;
  final String? arrivedAt;
  final String? metPassengerAt;
  final String? droppedAt;
  final String? pickupIssueReason;
  final List<String> pickupIssueReasonOptions;
  final int pickupIssueNoteMaxLength;
  final List<String> allowedActions;

  /// Start is gated behind "finish your current trip first" (another trip blocks it).
  final bool startLocked;

  /// Raw ISO-8601 `start_available_at` from the API.
  final String? startAvailableAtRaw;

  /// How close (m) the driver must be to the pickup to mark Arrived. Set
  /// server-side (`taxi.driver_arrival_gate`); 0 disables the gate.
  final double arrivalRadiusMeters;
  final bool needsResolution;
  final String? resolutionAvailableAt;
  final String? lateResolvedAt;
  final String? lateResolutionType;
  final String? lateResolutionNote;

  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;

  final Place pickup;
  final Place dropoff;

  /// Cash the driver must take from the passenger (onboard bookings).
  /// [BookingPayment.none] when the backend sends no `payment` block.
  final BookingPayment payment;
  final String? routeOrigin;
  final String? routeDestination;

  final String? departureDatetime;
  final String? legDepartureDatetime;
  final String? linkedOutboundDatetime;
  final String? linkedReturnDatetime;
  final String? arrivalDatetime; // estimated drop = departure + duration
  final int? duration; // route minutes
  final int? passengerCount;
  final String? nationality;
  final String? notes;

  final String? vehicleBooked; // class the customer booked, e.g. "Van 10 Seats"
  final String? vehicleModel; // real assigned vehicle, e.g. "Luxis Camary"
  final String? vehiclePlate;
  final String? vehicleColor;
  final int? vehicleSeats;
  final OperatorContact? operator;

  final bool isReturn;
  final String? returnDate; // ISO date (yyyy-MM-dd)
  final String? returnTime; // HH:mm

  final String? flightNumber;
  final String? airline;
  final String? terminal;
  final String? flightDatetime;

  bool get isAirport => serviceType == 'airport';
  bool get isReturnLeg => tripType == 'return';
  bool get isOutboundLeg => tripType == null || tripType == 'outbound';
  String get displayDepartureDatetime =>
      legDepartureDatetime ?? departureDatetime ?? '';
  String? get linkedLegDatetime =>
      isReturnLeg ? linkedOutboundDatetime : linkedReturnDatetime;
  bool get can => allowedActions.isNotEmpty;
  bool allows(String action) => allowedActions.contains(action);
  bool get canReportPickupIssue => allows('report_pickup_issue');

  /// Onboard cash is still outstanding, so the trip cannot be completed yet.
  bool get requiresPaymentCollection => payment.requiresCollection;
  bool get isClosed =>
      status == 'completed' ||
      status == 'cancelled' ||
      stage == 'completed' ||
      stage == 'cancelled' ||
      stage == 'pickup_issue' ||
      driverTripStatus == 'drop_passenger' ||
      driverTripStatus == 'pickup_issue' ||
      pickupIssueReason != null;

  DateTime? get departureAt {
    final value = displayDepartureDatetime;
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  Duration? get startOverdueBy {
    final dt = departureAt;
    if (!allows('start') || dt == null) return null;
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
    if (allows('start') || !can) return false;
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

  /// An upcoming trip the driver cannot act on yet: the start window is shut
  /// AND the trip has not begun.
  ///
  /// The stage check is the safeguard. If the API ever keeps sending
  /// `start_available_at` after a trip starts, stage alone still proves the
  /// trip is running, so a live booking never loses its step controls.
  bool get isUpcomingOnly =>
      (startLocked || isStartWindowClosed) &&
      stage == 'assigned' &&
      !isClosed;

  /// Whether this assignment belongs to a two-leg trip contract.
  bool get hasReturn => isRoundTrip;

  /// Whether any vehicle info (booked or assigned) exists.
  bool get hasVehicle =>
      (vehicleBooked?.isNotEmpty ?? false) ||
      (vehicleModel?.isNotEmpty ?? false) ||
      (vehiclePlate?.isNotEmpty ?? false);

  /// The real assigned vehicle line, e.g. "Luxis Camary · 2A-2025".
  String? get assignedVehicleLabel {
    final parts = <String>[
      if (vehicleModel != null && vehicleModel!.isNotEmpty) vehicleModel!,
      if (vehiclePlate != null && vehiclePlate!.isNotEmpty) vehiclePlate!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  bool get hasOperatorContact => operator?.hasContact == true;

  factory BookingDetail.fromJson(Map<String, dynamic> json) {
    final customer = _map(json['customer']);
    final leg = _map(json['leg']);
    final vehicle = _map(json['vehicle']);
    final operator = _map(json['operator']);
    final flight = _map(json['flight']);
    final returnTrip = _map(json['return_trip']);
    final routeSummary = _map(json['route_summary']);

    return BookingDetail(
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
      isRoundTrip: json['is_round_trip'] == true || json['is_return'] == true,
      status: _string(json['status']),
      driverPickupStatus: _string(json['driver_pickup_status']),
      driverTripStatus: _string(json['driver_trip_status']),
      acceptedAt: _string(json['accepted_at']),
      startedAt: _string(json['started_at']),
      arrivedAt: _string(json['arrived_at']),
      metPassengerAt: _string(json['met_passenger_at']),
      droppedAt: _string(json['dropped_at']),
      pickupIssueReason: _string(json['pickup_issue_reason']),
      pickupIssueReasonOptions: _stringList(
        json['pickup_issue_reason_options'],
      ),
      pickupIssueNoteMaxLength:
          _toInt(json['pickup_issue_note_max_length']) ?? 500,
      allowedActions: _stringList(json['allowed_actions']),
      startLocked: json['start_locked'] == true,
      startAvailableAtRaw: _string(json['start_available_at']),
      arrivalRadiusMeters:
          _toInt(json['arrival_radius_meters'])?.toDouble() ??
          PickupArrivalGate.defaultRadiusMeters,
      needsResolution: json['needs_resolution'] == true,
      resolutionAvailableAt: _string(json['resolution_available_at']),
      lateResolvedAt: _string(json['late_resolved_at']),
      lateResolutionType: _string(json['late_resolution_type']),
      lateResolutionNote: _string(json['late_resolution_note']),
      customerName: _string(customer['name']),
      customerPhone: _string(customer['phone']),
      customerEmail: _string(customer['email']),
      pickup: Place.fromJson(_map(json['pickup'])),
      dropoff: Place.fromJson(_map(json['dropoff'])),
      payment: BookingPayment.fromJson(_map(json['payment'])),
      routeOrigin: _string(routeSummary['origin']),
      routeDestination: _string(routeSummary['destination']),
      departureDatetime: _string(json['departure_datetime']),
      legDepartureDatetime: _string(json['leg_departure_datetime']),
      linkedOutboundDatetime: _string(json['linked_outbound_datetime']),
      linkedReturnDatetime: _string(json['linked_return_datetime']),
      arrivalDatetime: _string(json['arrival_datetime']),
      duration: _toInt(json['duration']),
      passengerCount: _toInt(json['passenger_count']),
      nationality: _string(json['nationality']),
      notes: _string(json['notes']),
      vehicleBooked: _string(vehicle['booked_name']),
      vehicleModel: _string(vehicle['model']),
      vehiclePlate: _string(vehicle['plate_number']),
      vehicleColor: _string(vehicle['color']),
      vehicleSeats: _toInt(vehicle['seats']),
      operator: OperatorContact.fromJson(operator),
      isReturn: json['is_return'] == true,
      returnDate: _string(returnTrip['date']),
      returnTime: _string(returnTrip['time']),
      flightNumber: _string(flight['number']),
      airline: _string(flight['airline']),
      terminal: _string(flight['terminal']),
      flightDatetime: _string(flight['datetime']),
    );
  }

  static Map<String, dynamic> _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
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

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
}

class OperatorContact {
  const OperatorContact({
    this.name,
    this.phone,
    this.email,
    this.address,
    this.telegramChatId,
  });

  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final String? telegramChatId;

  bool get hasContact =>
      (name != null && name!.isNotEmpty) ||
      (phone != null && phone!.isNotEmpty) ||
      (email != null && email!.isNotEmpty) ||
      (address != null && address!.isNotEmpty) ||
      (telegramChatId != null && telegramChatId!.isNotEmpty);

  bool get hasPhone => phone != null && phone!.isNotEmpty && phone != 'N/A';
  bool get hasEmail => email != null && email!.isNotEmpty && email != 'N/A';
  bool get hasAddress =>
      address != null && address!.isNotEmpty && address != 'N/A';

  factory OperatorContact.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OperatorContact();

    return OperatorContact(
      name: BookingDetail._string(json['name']),
      phone: BookingDetail._string(json['phone']),
      email: BookingDetail._string(json['email']),
      address: BookingDetail._string(json['address']),
      telegramChatId: BookingDetail._string(json['telegram_chat_id']),
    );
  }
}
