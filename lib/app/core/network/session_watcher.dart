import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../data/repositories/notification_repository.dart';
import '../../data/services/auth_service.dart';

/// Re-checks the session whenever the app comes back to the foreground.
///
/// A revoked session is normally noticed one of two ways: the silent
/// `session.revoked` push, or a 401 on the next request (handled globally by
/// [ApiClient.onUnauthorized]). Neither fires for a phone that was simply left
/// open — the driver would return to a screen full of stale data. So on resume
/// we make one cheap authenticated call; a 401 takes the usual sign-out path.
class SessionWatcher extends GetxService with WidgetsBindingObserver {
  /// Ignore rapid foreground/background flips (permission sheets, the camera).
  static const Duration _minInterval = Duration(seconds: 20);

  DateTime? _lastCheck;
  bool _checking = false;

  SessionWatcher start() {
    WidgetsBinding.instance.addObserver(this);
    return this;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(check());
    }
  }

  Future<void> check() async {
    if (_checking) return;

    final auth = Get.isRegistered<AuthService>()
        ? Get.find<AuthService>()
        : null;
    if (auth == null || !auth.isLoggedIn) return;

    final last = _lastCheck;
    if (last != null && DateTime.now().difference(last) < _minInterval) return;

    _checking = true;
    try {
      // Smallest authenticated endpoint we have; a revoked token answers 401
      // and ApiClient's response modifier signs the driver out.
      await Get.find<NotificationRepository>().unreadCount();
      _lastCheck = DateTime.now();
    } catch (_) {
      // Offline or a server hiccup must not sign anyone out — only a 401 does,
      // and that is handled centrally.
    } finally {
      _checking = false;
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
