/// A pending "use this phone instead" verification: the backend has sent a
/// one-time code to the account's registered destination and expects it back
/// with the next login attempt (see `AuthRepository.requestTakeover`).
class TakeoverChallenge {
  const TakeoverChallenge({
    required this.token,
    required this.expiresIn,
    required this.destinationMasked,
    required this.channel,
    this.cooldownRemaining = 0,
  });

  /// Opaque challenge token, echoed back as `takeover_token` on login.
  final String token;

  /// Seconds until the current code stops being accepted.
  final int expiresIn;

  /// Where the code went, masked by the backend (e.g. `***172`).
  final String destinationMasked;

  /// `sms` or `email`.
  final String channel;

  /// Seconds before another code may be requested. Zero when unknown; the
  /// client then falls back to its own default.
  final int cooldownRemaining;

  bool get viaEmail => channel.toLowerCase() == 'email';

  /// Parse the `data` object of a successful request/resend response.
  factory TakeoverChallenge.fromJson(Map<String, dynamic> json) =>
      TakeoverChallenge(
        token: json['token']?.toString() ?? '',
        expiresIn: _int(json['expires_in']),
        destinationMasked: json['destination_masked']?.toString() ?? '',
        channel: json['channel']?.toString() ?? 'sms',
        cooldownRemaining: _int(json['cooldown_remaining']),
      );

  /// Rebuild from route arguments (see [toArguments]).
  factory TakeoverChallenge.fromArguments(Map<dynamic, dynamic> args) =>
      TakeoverChallenge(
        token: args['token']?.toString() ?? '',
        expiresIn: _int(args['expires_in']),
        destinationMasked: args['destination_masked']?.toString() ?? '',
        channel: args['channel']?.toString() ?? 'sms',
        cooldownRemaining: _int(args['cooldown_remaining']),
      );

  Map<String, dynamic> toArguments() => {
    'token': token,
    'expires_in': expiresIn,
    'destination_masked': destinationMasked,
    'channel': channel,
    'cooldown_remaining': cooldownRemaining,
  };

  TakeoverChallenge copyWith({
    String? token,
    int? expiresIn,
    String? destinationMasked,
    String? channel,
    int? cooldownRemaining,
  }) => TakeoverChallenge(
    token: token ?? this.token,
    expiresIn: expiresIn ?? this.expiresIn,
    destinationMasked: destinationMasked ?? this.destinationMasked,
    channel: channel ?? this.channel,
    cooldownRemaining: cooldownRemaining ?? this.cooldownRemaining,
  );

  static int _int(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;
}
