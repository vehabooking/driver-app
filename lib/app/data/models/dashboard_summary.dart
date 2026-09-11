import 'booking_list_item.dart';

/// Driver pipeline counts for the Home dashboard.
class DashboardCounts {
  const DashboardCounts({
    this.assigned = 0,
    this.active = 0,
    this.completed = 0,
  });

  final int assigned;
  final int active;
  final int completed;

  factory DashboardCounts.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    int n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return DashboardCounts(
      assigned: n(json['assigned']),
      active: n(json['active']),
      completed: n(json['completed']),
    );
  }
}

/// Home dashboard summary (from `GET api/taxi/v1/driver/dashboard`).
class DashboardSummary {
  const DashboardSummary({
    required this.status,
    required this.statusLabel,
    required this.active,
    required this.counts,
    this.nextPickup,
    this.upcoming = const [],
  });

  /// Dummy summary so the Home skeleton has a card and a row to trace.
  factory DashboardSummary.placeholder() => DashboardSummary(
    status: 'active',
    statusLabel: 'Active',
    active: true,
    counts: const DashboardCounts(),
    nextPickup: BookingListItem.placeholder(),
    upcoming: [BookingListItem.placeholder()],
  );

  /// Verification status: pending · approved · rejected.
  final String status;
  final String statusLabel;

  /// Working/in-service toggle, controlled by admin/vendor.
  final bool active;

  final DashboardCounts counts;

  /// The one trip to act on now (in progress, or soonest assigned).
  final BookingListItem? nextPickup;

  /// The remaining assigned pickups after [nextPickup], soonest first.
  final List<BookingListItem> upcoming;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final next = json['next_pickup'];
    final status = json['status']?.toString() ?? 'pending';
    final counts = json['counts'];
    return DashboardSummary(
      status: status,
      statusLabel: json['status_label']?.toString() ?? _labelForStatus(status),
      active: json['active'] is bool
          ? json['active'] as bool
          : status == 'approved',
      counts: DashboardCounts.fromJson(_map(counts)),
      nextPickup: next is Map
          ? BookingListItem.fromJson(Map<String, dynamic>.from(next))
          : null,
      upcoming: (json['upcoming'] as List? ?? [])
          .whereType<Map>()
          .map((e) => BookingListItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static Map<String, dynamic>? _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String _labelForStatus(String status) {
    return switch (status) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };
  }
}
