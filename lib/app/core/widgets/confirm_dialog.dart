import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Asks the driver to confirm before an action runs.
///
/// Returns `true` only when the driver explicitly confirms. Dismissing the
/// dialog - by the cancel button, the back gesture or a barrier tap - returns
/// `false`, so callers can treat anything other than `true` as "do nothing".
///
/// Used for the trip step actions, where a mis-tap would otherwise advance the
/// trip with no way back.
Future<bool> showConfirmDialog({
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  bool centered = false,
}) async {
  final context = Get.context;
  if (context == null) return false;

  final theme = Theme.of(context);
  final accent = destructive ? AppColors.cancelled : AppColors.primary;

  final result = await showDialog<bool>(
    context: context,
    // The driver must choose; a stray tap outside should not count as consent.
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      title: Text(
        title,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.onSurface
              : AppColors.secondary,
        ),
      ),
      content: Text(
        message,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.35,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(cancelLabel ?? 'no'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(confirmLabel ?? 'yes'.tr),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Confirmation prompt for a trip step action (`start`, `arrived`,
/// `meet_passenger`).
///
/// Returns `true` when the driver confirms. Unknown actions return `true`
/// unprompted rather than silently blocking the trip - a step we have no copy
/// for should still work.
///
/// The final `complete` step is deliberately absent: it uses a swipe control,
/// which is already an explicit confirmation.
Future<bool> confirmStepAction(String action) {
  final (String title, String message) = switch (action) {
    'start' => ('confirm_start_title'.tr, 'confirm_start_message'.tr),
    'arrived' => ('confirm_arrived_title'.tr, 'confirm_arrived_message'.tr),
    'meet_passenger' => ('confirm_meet_title'.tr, 'confirm_meet_message'.tr),
    _ => ('', ''),
  };

  if (title.isEmpty) return Future.value(true);

  return showConfirmDialog(title: title, message: message);
}

/// Confirmation shown before ending the authenticated driver session.
Future<bool> confirmSignOut() => showConfirmDialog(
  title: 'confirm_sign_out_title'.tr,
  message: 'confirm_sign_out_message'.tr,
  confirmLabel: 'sign_out'.tr,
  cancelLabel: 'cancel'.tr,
  destructive: true,
  centered: true,
);

/// Guarded recovery for a trip that was completed in reality but left open in
/// the app. The separate wording prevents drivers from using it as a shortcut
/// through a current trip.
Future<bool> confirmLateTripCompletion() => showConfirmDialog(
  title: 'confirm_late_completion_title'.tr,
  message: 'confirm_late_completion_message'.tr,
  confirmLabel: 'complete_old_trip'.tr,
  cancelLabel: 'not_now'.tr,
);
