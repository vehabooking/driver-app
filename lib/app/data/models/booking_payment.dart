/// The `payment` block on a driver booking resource.
///
/// Onboard bookings are settled in cash by the passenger to the driver, so the
/// trip cannot be completed while [requiresCollection] is true.
///
/// The block is optional: an older backend omits it entirely, which parses to
/// [BookingPayment.none] — no collector, nothing to collect.
class BookingPayment {
  const BookingPayment({
    this.collectorType,
    this.status,
    this.requiresCollection = false,
    this.amountDue,
    this.formattedAmountDue,
    this.amountPaid,
    this.note,
    this.collectedAt,
    this.collectedBy,
  });

  /// `onboard` | `admin` | `pay_later` | null.
  final String? collectorType;

  /// `unpaid` | `partially_paid` | `paid` | `refunded` | `cancelled`.
  final String? status;

  /// Collector is onboard, the booking is not paid and money is still due.
  final bool requiresCollection;

  /// Remaining balance the driver must take from the passenger.
  final double? amountDue;

  /// Server-formatted [amountDue], e.g. `$65.00`.
  final String? formattedAmountDue;
  final double? amountPaid;

  /// Free-text instruction written by dispatch for the driver, e.g.
  /// "collect the balance only". Onboard bookings only, often absent.
  final String? note;

  final String? collectedAt;

  /// Who recorded the payment. Absent on the list resource.
  final String? collectedBy;

  /// Nothing to collect - also what an absent `payment` block parses to.
  static const BookingPayment none = BookingPayment();

  bool get isOnboard => collectorType == 'onboard';
  bool get isPaid => status == 'paid';

  /// Settled with the office, nothing for the driver to handle.
  bool get isAdminCollected => collectorType == 'admin';

  /// The passenger settles after the trip, elsewhere.
  bool get isPayLater => collectorType == 'pay_later';

  /// Dispatch left an instruction worth showing.
  bool get hasNote => note != null && note!.trim().isNotEmpty;

  /// Onboard cash that has already been taken and recorded.
  bool get isCollected =>
      isOnboard && !requiresCollection && (isPaid || collectedAt != null);

  /// The amount to show while collection is outstanding.
  String get amountLabel =>
      formattedAmountDue ?? _formatAmount(amountDue) ?? '';

  /// The amount to show once the cash is in. `amount_due` has dropped to zero
  /// by then, so this reads from `amount_paid` instead.
  String get collectedAmountLabel =>
      _formatAmount(amountPaid) ?? formattedAmountDue ?? '';

  /// Reuse whatever currency prefix/suffix the server formatted `amount_due`
  /// with, so a locally formatted amount still reads as money.
  String? _formatAmount(double? value) {
    if (value == null) return null;
    final amount = value.toStringAsFixed(2);
    final formatted = formattedAmountDue;
    if (formatted == null || formatted.isEmpty) return amount;

    final digit = RegExp(r'[0-9]');
    final start = formatted.indexOf(digit);
    if (start < 0) return amount;
    final end = formatted.lastIndexOf(digit);

    return '${formatted.substring(0, start)}$amount'
        '${formatted.substring(end + 1)}';
  }

  factory BookingPayment.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return none;

    return BookingPayment(
      collectorType: _string(json['collector_type']),
      status: _string(json['status']),
      requiresCollection: json['requires_collection'] == true,
      amountDue: _toDouble(json['amount_due']),
      formattedAmountDue: _string(json['formatted_amount_due']),
      amountPaid: _toDouble(json['amount_paid']),
      note: _string(json['note']),
      collectedAt: _string(json['collected_at']),
      collectedBy: _string(json['collected_by']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String? _string(dynamic v) {
    if (v == null) return null;
    final value = v.toString();
    return value.isEmpty ? null : value;
  }
}

/// One selectable payment method from `GET /payment-methods` (active only,
/// the same list the vendor portal offers).
///
/// The driver picks one on the drop confirmation; sending no id at all records
/// cash, so a failed lookup is never a blocker.
class PaymentMethod {
  const PaymentMethod({required this.id, required this.name, this.code});

  final int id;
  final String name;

  /// Stable machine code, e.g. `cash`, `aba_pay`.
  final String? code;

  /// The default pick: money in hand is what a driver almost always takes.
  bool get isCash =>
      (code ?? '').toLowerCase().contains('cash') ||
      name.toLowerCase().contains('cash');

  static PaymentMethod? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'] is num
        ? (json['id'] as num).toInt()
        : int.tryParse(json['id']?.toString() ?? '');
    if (id == null) return null;

    final name = json['name']?.toString() ?? '';
    final code = json['code']?.toString();

    return PaymentMethod(
      id: id,
      name: name.isEmpty ? (code ?? '#$id') : name,
      code: code == null || code.isEmpty ? null : code,
    );
  }
}
