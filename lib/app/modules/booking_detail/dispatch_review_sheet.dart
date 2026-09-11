import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/booking_detail.dart';
import '../../core/theme/app_ink.dart';

class DispatchReviewSheet extends StatelessWidget {
  const DispatchReviewSheet({
    super.key,
    required this.operator,
    required this.onCall,
    required this.onEmail,
  });

  final OperatorContact? operator;
  final VoidCallback onCall;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final contentBottomPadding = safeBottom > 0 ? safeBottom * 0.35 : 0.0;
    final contact = operator ?? const OperatorContact();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.16),
              blurRadius: 30,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.sm,
              AppSpacing.pageH,
              contentBottomPadding + AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cancelled.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Icon(
                        IconsaxPlusLinear.building,
                        size: 21,
                        color: AppColors.cancelled.withValues(alpha: 0.86),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name?.isNotEmpty == true
                                ? contact.name!
                                : 'operator_info'.tr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'dispatch_review_needed'.tr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _DispatchInfoRow(
                  icon: IconsaxPlusLinear.call,
                  label: 'phone'.tr,
                  value: contact.hasPhone
                      ? contact.phone!
                      : 'dispatch_phone_unavailable'.tr,
                  enabled: contact.hasPhone,
                  onTap: contact.hasPhone ? onCall : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DispatchInfoRow(
                  icon: IconsaxPlusLinear.sms,
                  label: 'email'.tr,
                  value: contact.hasEmail
                      ? contact.email!
                      : 'dispatch_email_unavailable'.tr,
                  enabled: contact.hasEmail,
                  onTap: contact.hasEmail ? onEmail : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DispatchInfoRow(
                  icon: IconsaxPlusLinear.location,
                  label: 'address'.tr,
                  value: contact.hasAddress
                      ? contact.address!
                      : 'dispatch_address_unavailable'.tr,
                  enabled: contact.hasAddress,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: contact.hasPhone ? onCall : null,
                        icon: const Icon(IconsaxPlusLinear.call, size: 16),
                        label: Text('call'.tr),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          foregroundColor: AppColors.cancelled,
                          disabledForegroundColor: theme.colorScheme.outline,
                          side: BorderSide(
                            color:
                                (contact.hasPhone
                                        ? AppColors.cancelled
                                        : theme.colorScheme.outline)
                                    .withValues(alpha: 0.20),
                          ),
                          textStyle: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: contact.hasEmail ? onEmail : null,
                        icon: const Icon(IconsaxPlusLinear.sms, size: 16),
                        label: Text('email'.tr),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          textStyle: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DispatchInfoRow extends StatelessWidget {
  const _DispatchInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled ? AppColors.secondary : theme.colorScheme.outline;

    return Material(
      color: enabled
          ? AppColors.primary.withValues(alpha: 0.045)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 17,
                color: enabled
                    ? AppColors.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.72),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w700,
                        fontSize: 8.5,
                        letterSpacing: 0.35,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  IconsaxPlusLinear.arrow_right_3,
                  size: 15,
                  color: theme.colorScheme.outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
