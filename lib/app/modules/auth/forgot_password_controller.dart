import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/network/api_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/storage/storage_service.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/repositories/auth_repository.dart';

enum ForgotPasswordStep { request, verify, reset }

enum ResetIdentifierMode { phone, email }

class ForgotPasswordController extends GetxController {
  final AuthRepository _auth = Get.find<AuthRepository>();
  final StorageService _storage = Get.find<StorageService>();

  final requestFormKey = GlobalKey<FormState>();
  final verifyFormKey = GlobalKey<FormState>();
  final resetFormKey = GlobalKey<FormState>();

  final identifierCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  final otpFocusNode = FocusNode();

  final step = ForgotPasswordStep.request.obs;
  final identifierMode = ResetIdentifierMode.phone.obs;
  final isLoading = false.obs;
  final canRequestCode = false.obs;
  final canVerifyCode = false.obs;
  final canSavePassword = false.obs;
  final otpCode = ''.obs;
  final minPasswordLength = 8.obs;
  final passwordError = RxnString();
  final confirmPasswordError = RxnString();
  final maskedDestination = ''.obs;
  final obscurePassword = true.obs;
  final obscureConfirmPassword = true.obs;

  String? _otpToken;
  String? _resetToken;
  Worker? _otpFocusWorker;
  Timer? _otpKeyboardTimer;

  @override
  void onInit() {
    identifierCtrl.addListener(_syncIdentifierState);
    otpCtrl.addListener(_syncOtpState);
    passwordCtrl.addListener(_syncPasswordState);
    confirmPasswordCtrl.addListener(_syncPasswordState);

    final args = Get.arguments;
    final shouldForceRestore =
        args is Map && args['restore_pending_reset'] == true;

    if (args is Map &&
        (args['identifier']?.toString().trim().isNotEmpty ?? false)) {
      identifierCtrl.text = args['identifier'].toString().trim();
      _syncIdentifierModeFromValue(identifierCtrl.text);
      _syncMaskedDestination();
    }
    _restorePendingReset(force: shouldForceRestore);
    _syncIdentifierState();
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    // Closing the app and reopening it restores this step with a new field
    // that has never been focused, so the boxes look ready and the pad stays
    // down. Ask for it whenever the code step is shown.
    _otpFocusWorker = ever(step, (ForgotPasswordStep value) {
      if (value == ForgotPasswordStep.verify) _focusOtp();
    });
    if (step.value == ForgotPasswordStep.verify) _focusOtp();
  }

  void _focusOtp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || step.value != ForgotPasswordStep.verify) return;
      if (defaultTargetPlatform != TargetPlatform.android) {
        otpFocusNode.requestFocus();
        return;
      }
      // The route is not ready for an IME on the same frame it appears.
      _otpKeyboardTimer?.cancel();
      _otpKeyboardTimer = Timer(const Duration(milliseconds: 280), () {
        if (isClosed || step.value != ForgotPasswordStep.verify) return;
        otpFocusNode.requestFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isClosed || !otpFocusNode.hasFocus) return;
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        });
      });
    });
  }

  void togglePassword() => obscurePassword.toggle();

  void toggleConfirmPassword() => obscureConfirmPassword.toggle();

  void setIdentifierMode(ResetIdentifierMode mode) {
    if (identifierMode.value == mode) return;

    identifierMode.value = mode;
    identifierCtrl.clear();
    maskedDestination.value = '';
    _syncIdentifierState();
  }

  void goBack() {
    if (step.value == ForgotPasswordStep.verify) {
      otpCtrl.clear();
      step.value = ForgotPasswordStep.request;
      return;
    }

    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
      return;
    }

    Get.offNamed(Routes.login);
  }

  Future<void> requestCode() async {
    if (!canRequestCode.value) return;
    if (!(requestFormKey.currentState?.validate() ?? false)) return;

    if (_restoreMatchingPendingReset()) {
      return;
    }

    await _run(() async {
      final result = await _auth.requestPasswordReset(
        identifier: identifierCtrl.text.trim(),
        viaEmail: identifierMode.value == ResetIdentifierMode.email,
      );
      _otpToken = result.token;
      await _savePendingReset(result.token, result.expiresIn);
      step.value = ForgotPasswordStep.verify;
      AppSnackbar.success(
        result.message.isNotEmpty ? result.message : 'reset_code_sent'.tr,
      );
    });
  }

  Future<void> verifyCode() async {
    if (!canVerifyCode.value) {
      AppSnackbar.error('verification_code_required'.tr);
      return;
    }
    if (!(verifyFormKey.currentState?.validate() ?? false)) return;
    final token = _otpToken;
    if (token == null || token.isEmpty) {
      AppSnackbar.error('reset_request_expired'.tr);
      step.value = ForgotPasswordStep.request;
      return;
    }

    await _run(() async {
      final result = await _auth.verifyPasswordResetOtp(
        identifier: identifierCtrl.text.trim(),
        viaEmail: identifierMode.value == ResetIdentifierMode.email,
        otp: otpCtrl.text.trim(),
        token: token,
      );
      _resetToken = result.resetToken;
      minPasswordLength.value = result.minPasswordLength;
      await _storage.clearPendingPasswordReset();
      step.value = ForgotPasswordStep.reset;
      _syncPasswordState();
      AppSnackbar.success(
        result.message.isNotEmpty ? result.message : 'reset_code_verified'.tr,
      );
    });
  }

  Future<void> resendCode() async {
    final token = _otpToken;
    if (token == null || token.isEmpty) {
      await requestCode();
      return;
    }

    await _run(() async {
      final result = await _auth.resendPasswordResetOtp(token: token);
      _otpToken = result.token;
      otpCtrl.clear();
      await _savePendingReset(result.token, result.expiresIn);
      AppSnackbar.success(
        result.message.isNotEmpty ? result.message : 'reset_code_sent'.tr,
      );
    });
  }

  Future<void> savePassword() async {
    if (!canSavePassword.value) {
      _syncPasswordState();
      return;
    }

    if (!(resetFormKey.currentState?.validate() ?? false)) return;
    final token = _resetToken;
    if (token == null || token.isEmpty) {
      AppSnackbar.error('reset_request_expired'.tr);
      step.value = ForgotPasswordStep.request;
      return;
    }

    await _run(() async {
      await _auth.resetPassword(
        resetToken: token,
        password: passwordCtrl.text,
        passwordConfirmation: confirmPasswordCtrl.text,
      );
      AppSnackbar.success('password_reset_success'.tr);
      await _storage.clearPendingPasswordReset();
      Get.offAllNamed(
        Routes.login,
        arguments: {'identifier': identifierCtrl.text.trim()},
      );
    });
  }

  void _restorePendingReset({bool force = false}) {
    if (!_storage.hasValidPendingPasswordReset) {
      _storage.clearPendingPasswordReset();
      return;
    }

    final pendingIdentifier = _storage.passwordResetIdentifier ?? '';
    final currentIdentifier = identifierCtrl.text.trim();

    if (!force &&
        currentIdentifier.isNotEmpty &&
        currentIdentifier != pendingIdentifier) {
      return;
    }

    identifierCtrl.text = pendingIdentifier;
    _syncIdentifierModeFromValue(pendingIdentifier);
    _syncMaskedDestination();
    _otpToken = _storage.passwordResetOtpToken;
    step.value = ForgotPasswordStep.verify;
  }

  bool _restoreMatchingPendingReset() {
    if (!_storage.hasValidPendingPasswordReset) {
      _storage.clearPendingPasswordReset();
      return false;
    }

    final pendingIdentifier = _storage.passwordResetIdentifier?.trim() ?? '';
    final currentIdentifier = identifierCtrl.text.trim();

    if (pendingIdentifier.isEmpty ||
        currentIdentifier.toLowerCase() != pendingIdentifier.toLowerCase()) {
      return false;
    }

    _otpToken = _storage.passwordResetOtpToken;
    otpCtrl.clear();
    _syncMaskedDestination();
    step.value = ForgotPasswordStep.verify;
    return true;
  }

  Future<void> _savePendingReset(String token, int expiresIn) {
    final safeExpiresIn = expiresIn > 0 ? expiresIn : 300;

    return _storage.savePendingPasswordReset(
      identifier: identifierCtrl.text.trim(),
      otpToken: token,
      expiresAt: DateTime.now().add(Duration(seconds: safeExpiresIn)),
    );
  }

  void _syncIdentifierState() {
    final identifier = identifierCtrl.text.trim();

    if (identifier.contains('@') &&
        identifierMode.value != ResetIdentifierMode.email) {
      identifierMode.value = ResetIdentifierMode.email;
    }

    _syncMaskedDestination();
    canRequestCode.value = _isIdentifierValid(identifier);
  }

  bool _isIdentifierValid(String identifier) {
    if (identifier.isEmpty) {
      return false;
    }

    if (identifierMode.value == ResetIdentifierMode.email) {
      return GetUtils.isEmail(identifier);
    }

    return identifier.replaceAll(RegExp(r'\D+'), '').length >= 6;
  }

  void _syncIdentifierModeFromValue(String value) {
    identifierMode.value = value.trim().contains('@')
        ? ResetIdentifierMode.email
        : ResetIdentifierMode.phone;
  }

  void _syncMaskedDestination() {
    final identifier = identifierCtrl.text.trim();

    if (identifier.isEmpty) {
      maskedDestination.value = '';
      return;
    }

    maskedDestination.value = identifierMode.value == ResetIdentifierMode.email
        ? _maskEmail(identifier)
        : _maskPhone(identifier);
  }

  String _maskEmail(String email) {
    final parts = email.trim().toLowerCase().split('@');

    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return email;
    }

    final name = parts.first;
    final domain = parts.last;
    final visibleName = name.length <= 2 ? name[0] : name.substring(0, 2);
    final domainParts = domain.split('.');
    final domainName = domainParts.first;
    final domainSuffix = domainParts.length > 1
        ? '.${domainParts.sublist(1).join('.')}'
        : '';
    final visibleDomain = domainName.isEmpty ? '' : domainName[0];

    return '$visibleName••••@$visibleDomain••••$domainSuffix';
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D+'), '');

    if (digits.length <= 4) {
      return '••••';
    }

    return '••••${digits.substring(digits.length - 4)}';
  }

  void _syncOtpState() {
    otpCode.value = otpCtrl.text.trim();
    canVerifyCode.value = otpCode.value.length == 6;
  }

  void _syncPasswordState() {
    final password = passwordCtrl.text;
    final confirmation = confirmPasswordCtrl.text;
    final hasPassword = password.isNotEmpty;
    final hasConfirmation = confirmation.isNotEmpty;
    final isLongEnough = password.length >= minPasswordLength.value;
    final matches = password == confirmation;

    if (hasPassword && !isLongEnough) {
      passwordError.value = 'password_min_length'.trParams({
        'count': minPasswordLength.value.toString(),
      });
    } else {
      passwordError.value = null;
    }

    if (hasPassword && hasConfirmation && !matches) {
      confirmPasswordError.value = 'passwords_do_not_match'.tr;
    } else {
      confirmPasswordError.value = null;
    }

    canSavePassword.value =
        hasPassword && isLongEnough && hasConfirmation && matches;
  }

  Future<void> _run(Future<void> Function() action) async {
    isLoading.value = true;
    try {
      await action();
    } on ApiException catch (e) {
      if (await _restorePendingResetFromCooldown(e)) {
        AppSnackbar.info(e.message);
        return;
      }

      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _restorePendingResetFromCooldown(ApiException exception) async {
    if (exception.statusCode != 429) {
      return false;
    }

    final payload = exception.payload;
    final token = payload?['token']?.toString();
    final expiresIn = int.tryParse(payload?['expires_in']?.toString() ?? '');

    if (token == null || token.isEmpty || expiresIn == null || expiresIn <= 0) {
      return false;
    }

    _otpToken = token;
    otpCtrl.clear();
    step.value = ForgotPasswordStep.verify;
    await _savePendingReset(token, expiresIn);

    return true;
  }

  @override
  void onClose() {
    _otpKeyboardTimer?.cancel();
    _otpFocusWorker?.dispose();
    identifierCtrl.removeListener(_syncIdentifierState);
    otpCtrl.removeListener(_syncOtpState);
    passwordCtrl.removeListener(_syncPasswordState);
    confirmPasswordCtrl.removeListener(_syncPasswordState);
    identifierCtrl.dispose();
    otpCtrl.dispose();
    otpFocusNode.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.onClose();
  }
}
