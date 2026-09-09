import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/network/api_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/models/takeover_challenge.dart';
import '../../data/services/auth_service.dart';

class LoginController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();

  final formKey = GlobalKey<FormState>();
  final loginCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final passwordFocusNode = FocusNode();

  final isLoading = false.obs;
  final canSignIn = false.obs;
  final obscure = true.obs;

  String? _appliedRouteIdentifier;

  @override
  void onInit() {
    loginCtrl.addListener(_syncSignInState);
    passwordCtrl.addListener(_syncSignInState);
    applyRouteArguments();
    _syncSignInState();
    super.onInit();
  }

  void toggleObscure() => obscure.toggle();

  void showHelp() => AppSnackbar.info('login_help_message'.tr);

  void applyRouteArguments() {
    final args = Get.arguments;
    if (args is! Map) return;

    final identifier = args['identifier']?.toString().trim();
    if (identifier == null || identifier.isEmpty) return;
    if (_appliedRouteIdentifier == identifier) return;

    _appliedRouteIdentifier = identifier;
    if (loginCtrl.text != identifier) {
      loginCtrl.text = identifier;
    }
    passwordCtrl.clear();
    _syncSignInState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        passwordFocusNode.requestFocus();
      }
    });
  }

  void forgotPassword() {
    Get.toNamed(
      Routes.forgotPassword,
      arguments: {'identifier': loginCtrl.text.trim()},
    );
  }

  Future<void> submit() async {
    if (!canSignIn.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    final login = loginCtrl.text.trim();
    final password = passwordCtrl.text;

    isLoading.value = true;
    try {
      await _auth.login(login, password);
      _enterApp();
    } on ApiException catch (e) {
      if (e.errorCode == 'ALREADY_SIGNED_IN_ELSEWHERE') {
        isLoading.value = false;
        await _startTakeover(login, password);
        return;
      }
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  /// One phone per account: the account is live on another phone. Offer to
  /// move it here — the backend texts a code to the registered number, the
  /// driver types it on the takeover screen, and the other phone is signed out.
  Future<void> _startTakeover(String login, String password) async {
    final proceed = await showConfirmDialog(
      title: 'takeover_title'.tr,
      message: 'takeover_message'.tr,
      confirmLabel: 'takeover_send_code'.tr,
      cancelLabel: 'cancel'.tr,
      centered: true,
    );
    if (!proceed || isClosed) return;

    isLoading.value = true;
    try {
      final challenge = await _auth.requestTakeover(login, password);
      if (challenge == null) {
        // The other phone is gone (signed out meanwhile) — plain login works.
        await _auth.login(login, password);
        _enterApp();
        return;
      }
      _openTakeoverScreen(login, password, challenge);
    } on ApiException catch (e) {
      // Still in the resend cooldown from an earlier attempt: a code is
      // already out there, so go straight to entering it.
      final pending = _pendingChallengeFromCooldown(e);
      if (pending != null) {
        AppSnackbar.info(e.message);
        _openTakeoverScreen(login, password, pending);
        return;
      }
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  TakeoverChallenge? _pendingChallengeFromCooldown(ApiException e) {
    if (!e.isRateLimited) return null;
    final challenge = TakeoverChallenge.fromJson(e.extra);
    if (challenge.token.isEmpty) return null;
    return challenge.cooldownRemaining > 0
        ? challenge
        : challenge.copyWith(cooldownRemaining: 1);
  }

  void _openTakeoverScreen(
    String login,
    String password,
    TakeoverChallenge challenge,
  ) {
    Get.toNamed(
      Routes.deviceTakeover,
      arguments: {
        'login': login,
        'password': password,
        ...challenge.toArguments(),
      },
    );
  }

  void _enterApp() {
    passwordCtrl.clear();
    Get.offAllNamed(Routes.home);
  }

  void _syncSignInState() {
    canSignIn.value =
        loginCtrl.text.trim().isNotEmpty && passwordCtrl.text.isNotEmpty;
  }

  @override
  void onClose() {
    loginCtrl.removeListener(_syncSignInState);
    passwordCtrl.removeListener(_syncSignInState);
    loginCtrl.dispose();
    passwordCtrl.dispose();
    passwordFocusNode.dispose();
    super.onClose();
  }
}
