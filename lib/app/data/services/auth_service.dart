import 'dart:convert';

import 'package:get/get.dart';

import '../../core/location/driver_tracking_service.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/device_identity.dart';
import '../models/auth_user.dart';
import '../models/takeover_challenge.dart';
import '../repositories/auth_repository.dart';
import 'push_notification_service.dart';

/// Owns the authenticated session: the current user, the token (mirrored to
/// [ApiClient] and [StorageService]), and login/logout.
class AuthService extends GetxService {
  AuthService(this._repo, this._api, this._storage);

  final AuthRepository _repo;
  final ApiClient _api;
  final StorageService _storage;

  final Rxn<AuthUser> currentUser = Rxn<AuthUser>();

  bool get isLoggedIn => _api.token != null && _api.token!.isNotEmpty;

  /// Restore a persisted session on app start.
  Future<AuthService> bootstrap() async {
    final token = await _storage.readToken();
    if (token != null && token.isNotEmpty) {
      _api.token = token;
      final userJson = await _storage.readUser();
      if (userJson != null && userJson.isNotEmpty) {
        currentUser.value = AuthUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
      }
    }
    return this;
  }

  /// Stable per-phone device name sent with login/logout (see [DeviceIdentity]).
  Future<String> deviceName() => DeviceIdentity(_storage).name();

  /// Sign in on this phone. Supply [takeoverToken] + [takeoverOtp] (from
  /// [requestTakeover]) to move the account here when it is live elsewhere.
  Future<void> login(
    String login,
    String password, {
    String? takeoverToken,
    String? takeoverOtp,
  }) async {
    final result = await _repo.login(
      login: login,
      password: password,
      deviceName: await deviceName(),
      takeoverToken: takeoverToken,
      takeoverOtp: takeoverOtp,
    );
    await _persist(result.token, result.user);
    if (Get.isRegistered<PushNotificationService>()) {
      await Get.find<PushNotificationService>().registerCurrentDevice();
    }
  }

  /// Start the "use this phone instead" verification. `null` means the
  /// account is not held by another phone and a plain [login] will succeed.
  Future<TakeoverChallenge?> requestTakeover(String login, String password) async {
    return _repo.requestTakeover(
      login: login,
      password: password,
      deviceName: await deviceName(),
    );
  }

  /// Send another code for a pending takeover challenge.
  Future<TakeoverChallenge> resendTakeover(String token) =>
      _repo.resendTakeover(token: token);

  /// Update editable profile fields and persist the refreshed user.
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? gender,
    String? dateOfBirth,
    String? currentAddress,
  }) async {
    final user = await _repo.updateProfile(
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      dateOfBirth: dateOfBirth,
      currentAddress: currentAddress,
    );
    await _persistUser(user);
  }

  /// Upload a new profile photo and update the cached user's image URL.
  Future<void> uploadAvatar(String filePath) async {
    final imageUrl = await _repo.uploadAvatar(filePath);
    final current = currentUser.value;
    if (current != null) {
      await _persistUser(current.copyWith(imageUrl: imageUrl));
    }
  }

  Future<void> _persistUser(AuthUser user) async {
    currentUser.value = user;
    await _storage.writeUser(jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    // Tear down the background tracking session (and its copy of the token)
    // before the session itself is revoked.
    if (Get.isRegistered<DriverTrackingService>()) {
      await Get.find<DriverTrackingService>().stop();
    }

    try {
      await _repo.logout(await deviceName());
    } catch (_) {
      // Best-effort server revoke; local clear below is what matters.
    }
    _api.token = null;
    currentUser.value = null;
    await _storage.clearSecure();
  }

  /// Session ended by the server (signed in on another phone, or dispatch
  /// reset the account). Nothing to revoke remotely — the token is already
  /// gone — so just tear down locally and return to the login screen.
  Future<void> forceSignOut({String messageKey = 'session_replaced'}) async {
    if (!isLoggedIn) return;

    if (Get.isRegistered<DriverTrackingService>()) {
      await Get.find<DriverTrackingService>().stop();
    }

    _api.token = null;
    currentUser.value = null;
    await _storage.clearSecure();

    if (Get.currentRoute != Routes.login) {
      Get.offAllNamed(Routes.login);
    }
    AppSnackbar.info(messageKey.tr);
  }

  Future<void> _persist(String token, AuthUser user) async {
    _api.token = token;
    currentUser.value = user;
    await _storage.writeToken(token);
    await _storage.writeUser(jsonEncode(user.toJson()));
  }
}
