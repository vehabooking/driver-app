/// Spacing + radius scale. One source of truth for layout rhythm.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal inset for page-level content (scroll views, sheets).
  /// Deliberately tighter than [lg] so cards get more usable width on
  /// phone screens. Card *interior* padding still uses [lg].
  static const double pageH = 12;

  /// Bottom padding for scroll views so content clears the floating glass nav.
  static const double navClearance = 108;

  // Corner radii.
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
}
