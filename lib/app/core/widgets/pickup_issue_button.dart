import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'pickup_issue_sheet.dart';

/// The escape hatch under a trip's primary action: the passenger is not here,
/// the address is wrong, nobody answers.
///
/// One widget for every screen that offers it — the map (where the driver is
/// when it happens) and the booking detail (the fallback when a booking has no
/// coordinates and the map cannot open).
class PickupIssueButton extends StatelessWidget {
  const PickupIssueButton({
    super.key,
    required this.onSubmit,
    this.reasonOptions = const [],
    this.noteMaxLength = 500,
    this.enabled = true,
  });

  /// Reports the issue. Receives the chosen reason and the optional note.
  final Future<void> Function(String reason, String? note) onSubmit;

  final List<String> reasonOptions;
  final int noteMaxLength;

  /// False while another action is in flight, so the trip cannot be advanced
  /// and abandoned at the same time.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton.icon(
      onPressed: enabled
          ? () => showPickupIssueSheet(
              context: context,
              onSubmit: onSubmit,
              reasonOptions: reasonOptions,
              noteMaxLength: noteMaxLength,
            )
          : null,
      icon: const Icon(IconsaxPlusLinear.search_status, size: 17),
      label: Text('pickup_issue_link'.tr),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 4,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
