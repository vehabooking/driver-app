import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/i18n/app_translations.dart';
import '../../core/storage/storage_service.dart';

/// Owns user preferences: locale (EN/KM) and theme mode. Persists to storage
/// and drives GetX's live locale/theme switching.
class SettingsService extends GetxService {
  SettingsService(this._storage);

  final StorageService _storage;

  final Rx<Locale> locale = AppTranslations.englishLocale.obs;
  // Light by default; drivers can opt into dark or system in Profile.
  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;

  SettingsService init() {
    locale.value = AppTranslations.fromCode(_storage.locale);
    themeMode.value = _themeFromName(_storage.themeMode);
    return this;
  }

  bool get isKhmer => locale.value.languageCode == 'km';

  void setLocale(Locale value) {
    locale.value = value;
    _storage.locale = value.languageCode == 'km' ? 'km_KH' : 'en_US';
    Get.updateLocale(value);
  }

  void toggleLanguage() => setLocale(
    isKhmer ? AppTranslations.englishLocale : AppTranslations.khmerLocale,
  );

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    _storage.themeMode = mode.name;
    Get.changeThemeMode(mode);
  }

  ThemeMode _themeFromName(String? name) => ThemeMode.values.firstWhere(
    (e) => e.name == name,
    orElse: () => ThemeMode.light,
  );
}
