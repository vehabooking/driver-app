import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/models/takeover_challenge.dart';
import '../../data/services/auth_service.dart';

/// "Use this phone instead": the account is signed in elsewhere, a one-time
/// code was sent to its registered number, and the driver proves ownership
/// here. Reached from the login screen with the login, password and the
/// [TakeoverChallenge] in the route arguments.
class DeviceTakeoverController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();

  final formKey = GlobalKey<FormState>();
  final otpCtrl = TextEditingController();
  final otpFocusNode = FocusNode();

  final otpCode = ''.obs;
  final canVerify = false.obs;
  final isLoading = false.obs;
  final isResending = false.obs;
  final otpError = RxnString();

  final destinationMasked = ''.obs;
  final viaEmail = false.obs;

  /// Seconds until the current code stops being accepted (0 = expired).
  final expiresIn = 0.obs;

  /// Seconds until "Resend code" is allowed again (0 = allowed).
  final cooldownRemaining = 0.obs;

  String _login = '';
  String _password = '';
  String _token = '';
  DateTime? _expiresAt;
  DateTime? _cooldownEndsAt;
  Timer? _ticker;

  bool get isExpired => expiresIn.value <= 0;
  bool get canResend =>
      cooldownRemaining.value <= 0 && !isLoading.value && !isResending.value;

  /// `mm:ss` for the expiry countdown.
  String get expiresLabel => _clock(expiresIn.value);

  @override
  void onInit() {
    otpCtrl.addListener(_syncOtpState);

    final args = Get.arguments;
    if (args is Map) {
      _login = args['login']?.toString().trim() ?? '';
      _password = args['password']?.toString() ?? '';
      final challenge = TakeoverChallenge.fromArguments(args);
      // Arriving here via a 429 means a code is already out and the backend
      // told us how long to wait; a fresh request starts the client-side
      // default cooldown instead.
      _applyChallenge(challenge, cooldownSeconds: challenge.cooldownRemaining);
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    if (_login.isEmpty || _password.isEmpty || _token.isEmpty) {
      // Deep-linked or restored without state: nothing to verify against.
      AppSnackbar.error('reset_request_expired'.tr);
      goBack();
      return;
    }
    otpFocusNode.requestFocus();
  }

  void goBack() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
      return;
    }
    Get.offAllNamed(Routes.login, arguments: {'identifier': _login});
  }

  Future<void> verify() async {
    if (isLoading.value) return;
    if (!canVerify.value) {
      otpError.value = 'verification_code_required'.tr;
      otpFocusNode.requestFocus();
      return;
    }
    if (isExpired) {
      otpError.value = 'code_expired'.tr;
      return;
    }

    isLoading.value = true;
    otpError.value = null;
    try {
      await _auth.login(
        _login,
        _password,
        takeoverToken: _token,
        takeoverOtp: otpCtrl.text.trim(),
      );
      _password = '';
      otpCtrl.clear();
      AppSnackbar.success('takeover_success'.tr);
      Get.offAllNamed(Routes.home);
    } on ApiException catch (e) {
      if (e.errorCode == 'TAKEOVER_OTP_INVALID') {
        otpError.value = e.message;
        otpCtrl.clear();
        otpFocusNode.requestFocus();
        return;
      }
      if (e.errorCode == 'ALREADY_SIGNED_IN_ELSEWHERE') {
        // Challenge no longer valid on the server (expired / consumed).
        otpError.value = 'code_expired'.tr;
        return;
      }
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resend() async {
    if (!canResend) return;

    isResending.value = true;
    otpError.value = null;
    try {
      final challenge = await _auth.resendTakeover(_token);
      _applyChallenge(challenge);
      otpCtrl.clear();
      otpFocusNode.requestFocus();
      AppSnackbar.success('reset_code_sent'.tr);
    } on ApiException catch (e) {
      if (e.isRateLimited) {
        // Still cooling down: adopt the server's timings and keep waiting.
        final pending = TakeoverChallenge.fromJson(e.extra);
        _applyChallenge(
          pending.token.isEmpty ? pending.copyWith(token: _token) : pending,
          cooldownSeconds: pending.cooldownRemaining,
          keepExpiryIfMissing: true,
        );
        AppSnackbar.info(e.message);
        return;
      }
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    } finally {
      isResending.value = false;
    }
  }

  /// Adopt a (re)issued challenge: token, destination, expiry and cooldown.
  ///
  /// [cooldownSeconds] `<= 0` means "not told" and falls back to the default
  /// resend cooldown. With [keepExpiryIfMissing] an absent `expires_in` leaves
  /// the running expiry untouched (a 429 may omit it).
  void _applyChallenge(
    TakeoverChallenge challenge, {
    int cooldownSeconds = 0,
    bool keepExpiryIfMissing = false,
  }) {
    if (challenge.token.isNotEmpty) _token = challenge.token;
    if (challenge.destinationMasked.isNotEmpty) {
      destinationMasked.value = challenge.destinationMasked;
    }
    viaEmail.value = challenge.viaEmail;

    final now = DateTime.now();
    if (challenge.expiresIn > 0) {
      _expiresAt = now.add(Duration(seconds: challenge.expiresIn));
    } else if (!keepExpiryIfMissing || _expiresAt == null) {
      _expiresAt = now.add(
        const Duration(seconds: AppConstants.takeoverOtpDefaultExpirySeconds),
      );
    }

    final cooldown = cooldownSeconds > 0
        ? cooldownSeconds
        : AppConstants.takeoverResendCooldownSeconds;
    _cooldownEndsAt = now.add(Duration(seconds: cooldown));
    _tick();
  }

  void _tick() {
    if (isClosed) return;
    expiresIn.value = _secondsUntil(_expiresAt);
    cooldownRemaining.value = _secondsUntil(_cooldownEndsAt);
  }

  int _secondsUntil(DateTime? at) {
    if (at == null) return 0;
    final diff = at.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  String _clock(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _syncOtpState() {
    otpCode.value = otpCtrl.text.trim();
    canVerify.value = otpCode.value.length == 6;
    if (otpError.value != null && otpCode.value.isNotEmpty) {
      otpError.value = null;
    }
  }

  @override
  void onClose() {
    _ticker?.cancel();
    otpCtrl.removeListener(_syncOtpState);
    otpCtrl.dispose();
    otpFocusNode.dispose();
    super.onClose();
  }
}
