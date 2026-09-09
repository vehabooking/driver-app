import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../theme/app_colors.dart';
import '../../data/models/booking_payment.dart';

/// One-glance amber marker: this trip still owes the driver cash.
///
/// Deliberately tiny - a card is not the place to explain the rule, only to
/// flag it. Renders nothing when there is nothing to collect (already paid,
/// or settled with the office).
class CollectPaymentPill extends StatelessWidget {
  const CollectPaymentPill({super.key, required this.payment});

  final BookingPayment payment;

  @override
  Widget build(BuildContext context) {
    if (!payment.requiresCollection) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final amount = payment.amountLabel;
    // Brand teal field with the figure in navy, mirroring the drop-off
    // confirmation so the pill and the dialog read as the same thing.
    const color = AppColors.primary;
    const ink = AppColors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(IconsaxPlusBold.money_recive, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              amount.isEmpty
                  ? 'collect_short'.tr
                  : '${'collect_short'.tr} $amount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface
                    : ink,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
