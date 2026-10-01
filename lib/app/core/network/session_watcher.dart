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
/// While the app stays open we also re-check on a timer, since a silent push
/// can be dropped (iOS throttles them) and an idle screen makes no requests.
class SessionWatcher extends GetxService with WidgetsBindingObserver {
  /// Ignore rapid foreground/background flips (permission sheets, the camera).
  static const Duration _minInterval = Duration(seconds: 20);

  /// Foreground re-check cadence for a phone left open on one screen.
  static const Duration _pollInterval = Duration(minutes: 1);

  DateTime? _lastCheck;
  bool _checking = false;
  Timer? _poll;

  SessionWatcher start() {
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    return this;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(check());
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(check()));
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
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
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
