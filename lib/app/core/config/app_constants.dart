/// Static keys and small constants used across the app.
class AppConstants {
  const AppConstants._();

  // Secure storage keys (sensitive).
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';

  // GetStorage keys (non-sensitive).
  static const String localeKey = 'locale';
  static const String themeModeKey = 'theme_mode';

  // A stable per-install device name sent with login/logout.
  static const String deviceNameKey = 'device_name';

  // First-run welcome/onboarding seen flag.
  static const String onboardingSeenKey = 'onboarding_seen';

  // Pending forgot-password flow.
  static const String passwordResetIdentifierKey = 'password_reset_identifier';
  static const String passwordResetOtpTokenKey = 'password_reset_otp_token';
  static const String passwordResetOtpExpiresAtKey =
      'password_reset_otp_expires_at';

  // Device takeover OTP: fallbacks when the backend omits the timings.
  static const int takeoverOtpDefaultExpirySeconds = 300;
  static const int takeoverResendCooldownSeconds = 60;

  // Default list page size (backend honours `limit`).
  static const int pageSize = 20;

  // Profile photos are normalized before upload. Keep this comfortably below
  // the backend's 5 MiB validation limit so multipart overhead and platform
  // differences cannot push a valid selection over the server limit.
  static const int avatarMaxDimension = 1280;
  static const int avatarTargetBytes = 1536 * 1024; // 1.5 MiB.
  static const int avatarMaxUploadBytes = 2 * 1024 * 1024; // 2 MiB.
}
