import 'package:get/get.dart';

/// A normalized, UI-friendly error surfaced from the network layer.
///
/// The backend speaks one envelope: `{ success:false, message, error_code }`.
/// [ApiException] flattens GetConnect/transport/HTTP failures into that shape so
/// controllers never touch the raw [Response].
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.fieldErrors,
    this.payload,
  });

  /// Human-readable message (already localized by the backend, or a fallback).
  final String message;

  /// HTTP status code, when the failure reached the server.
  final int? statusCode;

  /// Stable machine code (e.g. `BOOKING_NOT_OWNED`) for branching in the app.
  final String? errorCode;

  /// Validation errors keyed by field name (422 responses).
  final Map<String, List<String>>? fieldErrors;

  /// Extra top-level response fields, useful for recoverable errors.
  final Map<String, dynamic>? payload;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 422;
  bool get isRateLimited => statusCode == 429;

  /// Seconds left before the action may be retried, from a 429 response's
  /// `cooldown_remaining` (top-level or under `data`). `null` when absent.
  int? get cooldownRemaining => _intField('cooldown_remaining');

  /// Read an integer field from the response envelope, checking the top level
  /// first and then the nested `data` object.
  int? _intField(String key) {
    final body = payload;
    if (body == null) return null;
    final nested = body['data'];
    final raw = body[key] ?? (nested is Map ? nested[key] : null);
    return int.tryParse(raw?.toString() ?? '');
  }

  /// Extra fields a recoverable error carries alongside the message, merged
  /// from the top level and the nested `data` object (top level wins).
  Map<String, dynamic> get extra {
    final body = payload;
    if (body == null) return const {};
    final nested = body['data'];
    return {
      if (nested is Map) ...Map<String, dynamic>.from(nested),
      ...body,
    };
  }

  /// Build from a GetConnect [Response], reading the backend envelope when
  /// present. A null [Response.statusCode] means the request never reached the
  /// server (timeout / no connection).
  factory ApiException.fromResponse(Response<dynamic> res) {
    final data = res.body;

    String message = 'Something went wrong. Please try again.';
    String? errorCode;
    Map<String, List<String>>? fieldErrors;

    if (data is Map) {
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        message = data['message'] as String;
      }
      if (data['error_code'] is String) {
        errorCode = data['error_code'] as String;
      }
      if (data['errors'] is Map) {
        fieldErrors = (data['errors'] as Map).map(
          (key, value) => MapEntry(
            key.toString(),
            (value is List)
                ? value.map((v) => v.toString()).toList()
                : [value.toString()],
          ),
        );
      }
    }

    // Transport-level failure → never reached the server → friendlier copy.
    if (res.statusCode == null) {
      message = 'Cannot reach the server. Check your connection.';
    }

    return ApiException(
      message: message,
      statusCode: res.statusCode,
      errorCode: errorCode,
      fieldErrors: fieldErrors,
      payload: data is Map ? Map<String, dynamic>.from(data) : null,
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $errorCode): $message';
}
