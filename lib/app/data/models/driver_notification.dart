class DriverNotificationPage {
  const DriverNotificationPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<DriverNotification> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

class DriverNotification {
  const DriverNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.isRead,
    this.bookingUuid,
    this.bookingCode,
    this.assignmentId,
    this.bookingLegId,
    this.tripType,
    this.serviceType,
    this.routeOrigin,
    this.routeDestination,
    this.departureAt,
    this.route,
    this.readAt,
    this.createdAt,
    this.createdAtHuman,
  });

  /// Dummy row so the list skeleton traces a real tile.
  factory DriverNotification.placeholder() => DriverNotification(
    id: 'placeholder',
    type: 'trip_assigned',
    title: 'Notification title',
    message: 'Notification message line',
    data: const {},
    isRead: true,
    bookingCode: 'TX-000000',
    routeOrigin: 'Siem Reap',
    routeDestination: 'Phnom Penh',
    departureAt: DateTime.now()
        .add(const Duration(hours: 3))
        .toIso8601String(),
  );

  final String id;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final String? bookingUuid;
  final String? bookingCode;
  final int? assignmentId;
  final int? bookingLegId;
  final String? tripType;
  final String? serviceType;
  final String? routeOrigin;
  final String? routeDestination;
  final String? departureAt;
  final String? route;
  final DateTime? readAt;
  final DateTime? createdAt;
  final String? createdAtHuman;

  bool get canOpenTrip => bookingUuid != null && bookingUuid!.isNotEmpty;

  String? get routeLine {
    if (routeOrigin != null &&
        routeOrigin!.isNotEmpty &&
        routeDestination != null &&
        routeDestination!.isNotEmpty) {
      return '$routeOrigin to $routeDestination';
    }

    return null;
  }

  factory DriverNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = rawData is Map
        ? rawData.map((key, value) => MapEntry('$key', value))
        : <String, dynamic>{};

    return DriverNotification(
      id: '${json['id'] ?? ''}',
      type: '${json['type'] ?? data['type'] ?? ''}',
      title: '${json['title'] ?? data['title'] ?? ''}',
      message: '${json['message'] ?? data['message'] ?? ''}',
      data: data,
      isRead:
          json['is_read'] == true ||
          json['read_at'] != null ||
          data['read_at'] != null,
      bookingUuid: _string(json['booking_uuid'] ?? data['booking_uuid']),
      bookingCode: _string(json['booking_code'] ?? data['booking_code']),
      assignmentId: _int(json['assignment_id'] ?? data['assignment_id']),
      bookingLegId: _int(json['booking_leg_id'] ?? data['booking_leg_id']),
      tripType: _string(json['trip_type'] ?? data['trip_type']),
      serviceType: _string(json['service_type'] ?? data['service_type']),
      routeOrigin: _string(json['route_origin'] ?? data['route_origin']),
      routeDestination: _string(
        json['route_destination'] ?? data['route_destination'],
      ),
      departureAt: _string(json['departure_at'] ?? data['departure_at']),
      route: _string(json['route'] ?? data['route']),
      readAt: _date(json['read_at']),
      createdAt: _date(json['created_at']),
      createdAtHuman: _string(json['created_at_human']),
    );
  }

  static String? _string(dynamic value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _date(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
