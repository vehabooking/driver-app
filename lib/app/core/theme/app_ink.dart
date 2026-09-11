import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Foreground ("ink") colors that follow the active brightness.
///
/// The brand navy is the app's text color in light mode, but on a dark surface
/// it is effectively invisible. Anything that paints text or an icon should
/// read its color from here instead of using [AppColors.secondary] directly —
/// that token stays for brand fills, borders and shadows, where a fixed navy
/// is correct in both themes.
extension AppInk on ThemeData {
  /// Primary body text.
  Color get ink =>
      brightness == Brightness.dark ? colorScheme.onSurface : AppColors.secondary;

  /// Secondary text, at [alpha] of the primary ink. Dark mode needs a higher
  /// floor: light text on a dark ground loses legibility faster as it fades.
  Color inkMuted([double alpha = 0.7]) => brightness == Brightness.dark
      ? colorScheme.onSurface.withValues(alpha: (alpha + 0.12).clamp(0.0, 1.0))
      : AppColors.secondary.withValues(alpha: alpha);

  /// The page background behind cards.
  Color get canvas =>
      brightness == Brightness.dark ? colorScheme.surface : AppColors.canvas;
}
