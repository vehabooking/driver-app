import 'dart:convert';

import 'package:get/get.dart';

import '../../core/location/driver_tracking_service.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../models/auth_user.dart';
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

  /// Stable per-install device name sent with login/logout.
  String deviceName() {
    var name = _storage.deviceName;
    if (name == null || name.isEmpty) {
      name = 'driver-app-${DateTime.now().millisecondsSinceEpoch}';
      _storage.deviceName = name;
    }
    return name;
  }

  Future<void> login(String login, String password) async {
    final result = await _repo.login(
      login: login,
      password: password,
      deviceName: deviceName(),
    );
    await _persist(result.token, result.user);
    if (Get.isRegistered<PushNotificationService>()) {
      await Get.find<PushNotificationService>().registerCurrentDevice();
    }
  }

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
      await _repo.logout(deviceName());
    } catch (_) {
      // Best-effort server revoke; local clear below is what matters.
    }
    _api.token = null;
    currentUser.value = null;
    await _storage.clearSecure();
  }

  Future<void> _persist(String token, AuthUser user) async {
    _api.token = token;
    currentUser.value = user;
    await _storage.writeToken(token);
    await _storage.writeUser(jsonEncode(user.toJson()));
  }
}
