import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../storage/storage_service.dart';

/// Stable identifier for *this phone*, sent as `device_name` on login/logout
/// and as the push `udid`.
///
/// The backend allows one signed-in phone per driver account and tells phones
/// apart by this value, so it must survive an uninstall/reinstall — otherwise
/// the same phone would be locked out by its own old session. Android ID is
/// stable per app-signing-key + user; iOS `identifierForVendor` is stable while
/// any Veha app remains installed. A per-install random name is the fallback.
class DeviceIdentity {
  DeviceIdentity(this._storage);

  final StorageService _storage;

  String? _cached;

  Future<String> name() async {
    final cached = _cached;
    if (cached != null) return cached;

    final id = await _hardwareId();
    final name = id != null && id.isNotEmpty ? id : _fallback();

    _storage.deviceName = name;
    return _cached = name;
  }

  Future<String?> _hardwareId() async {
    try {
      if (Platform.isAndroid) {
        final id = await const AndroidId().getId();
        return id == null ? null : 'android-$id';
      }
      if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        final id = info.identifierForVendor;
        return id == null ? null : 'ios-$id';
      }
    } catch (_) {
      // Fall through to the stored / random name.
    }
    return null;
  }

  String _fallback() {
    final stored = _storage.deviceName;
    if (stored != null && stored.isNotEmpty) return stored;
    return 'driver-app-${DateTime.now().millisecondsSinceEpoch}';
  }
}
