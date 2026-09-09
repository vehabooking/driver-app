import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/storage/storage_service.dart';
import '../../core/utils/device_identity.dart';
import '../../core/utils/app_snackbar.dart';
import '../repositories/notification_repository.dart';
import 'auth_service.dart';

class PushNotificationService extends GetxService {
  PushNotificationService(this._repo, this._api, this._storage);

  final NotificationRepository _repo;
  final ApiClient _api;
  final StorageService _storage;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  bool _ready = false;

  Future<PushNotificationService> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (_) {
      _ready = false;
      return this;
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (_) => unawaited(registerCurrentDevice()),
    );

    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForeground,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openFromMessage,
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFromMessage(initialMessage);
      });
    }

    await registerCurrentDevice();

    return this;
  }

  Future<void> registerCurrentDevice() async {
    if (!_ready || _api.token == null || _api.token!.isEmpty) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final deviceName = await DeviceIdentity(_storage).name();

    try {
      await _repo.registerDevice(
        udid: deviceName,
        name: deviceName,
        fcmToken: token,
      );
    } catch (_) {
      // Push registration is best-effort and must not block app use.
    }
  }

  Future<int> unreadCount() async {
    try {
      return await _repo.unreadCount();
    } catch (_) {
      return 0;
    }
  }

  /// Data-only push sent when this phone's session was ended elsewhere
  /// (the driver signed in on another phone, or dispatch reset the account).
  /// Acting on it here means the driver is bounced to the login screen at
  /// once, instead of sitting on stale data until the next request 401s.
  bool _handleSessionRevoked(RemoteMessage message) {
    if (message.data['type']?.toString() != 'session.revoked') return false;

    if (Get.isRegistered<AuthService>()) {
      unawaited(Get.find<AuthService>().forceSignOut());
    }
    return true;
  }

  void _handleForeground(RemoteMessage message) {
    if (_handleSessionRevoked(message)) return;

    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['message'];

    if (title == null && body == null) {
      return;
    }

    AppSnackbar.info([title, body].whereType<String>().join('\n'));
  }

  void _openFromMessage(RemoteMessage message) {
    if (_handleSessionRevoked(message)) return;

    // Promo broadcasts (e.g. "new booking — contact your manager") carry no
    // booking to open; tapping just brings the app up.
    final screen = message.data['screen']?.toString();
    if (screen == 'none') {
      return;
    }
    if (screen == 'home') {
      Get.offAllNamed(Routes.home);
      return;
    }
    if (screen == 'notifications') {
      Get.toNamed(Routes.notifications);
      return;
    }

    final uuid = message.data['booking_uuid']?.toString();
    if (uuid == null || uuid.isEmpty) {
      Get.toNamed(Routes.notifications);
      return;
    }

    final assignmentId = int.tryParse(
      message.data['assignment_id']?.toString() ?? '',
    );

    Get.toNamed(
      Routes.bookingDetail,
      arguments: {'uuid': uuid, 'assignment_id': ?assignmentId},
    );
  }


  @override
  void onClose() {
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    _openedSubscription?.cancel();
    super.onClose();
  }
}
