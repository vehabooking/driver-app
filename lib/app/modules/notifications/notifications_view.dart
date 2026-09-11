import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/driver_notification.dart';
import 'notifications_controller.dart';
import '../../core/theme/app_ink.dart';

class NotificationsView extends GetView<NotificationsController> {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canvas = isDark ? theme.colorScheme.surface : AppColors.canvas;

    return Scaffold(
      backgroundColor: canvas,
      // The scroll viewport has to start below the status bar, or list items
      // ride up underneath it. Compensating inside the list does not work:
      // the header scrolls away and everything after it is unprotected.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.refreshList,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 220) {
                controller.loadMore();
              }
              return false;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.sm,
                AppSpacing.pageH,
                AppSpacing.navClearance,
              ),
              children: const [
                _Header(),
                SizedBox(height: AppSpacing.lg),
                _FilterTabs(),
                SizedBox(height: AppSpacing.xl),
                _NotificationsBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends GetView<NotificationsController> {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppBackButton(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'notifications_title'.tr,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            Obx(
              () => _MarkAllReadButton(
                enabled:
                    controller.unreadCount > 0 &&
                    !controller.isMarkingAll.value,
                loading: controller.isMarkingAll.value,
                onTap: controller.markAllAsRead,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MarkAllReadButton extends StatelessWidget {
  const _MarkAllReadButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.primary
        : AppColors.secondary.withValues(alpha: 0.28);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              'mark_all_read'.tr,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabs extends GetView<NotificationsController> {
  const _FilterTabs();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _FilterTab(
              label: 'all_notifications'.tr,
              selected: controller.filter.value == null,
              onTap: () => controller.setFilter(null),
            ),
            _FilterTab(
              label: 'unread'.tr,
              selected: controller.filter.value == 'unread',
              onTap: () => controller.setFilter('unread'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? AppColors.secondary
                  : theme.inkMuted(0.62),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsBody extends GetView<NotificationsController> {
  const _NotificationsBody();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.error.value != null) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.48,
          child: ErrorView(
            message: controller.error.value!,
            onRetry: controller.load,
          ),
        );
      }

      if (controller.isLoading.value) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.42,
          child: const Center(child: CircularProgressIndicator()),
        );
      }

      if (controller.notifications.isEmpty) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.48,
          child: const _EmptyNotifications(),
        );
      }

      return Column(
        children: [
          ...controller.notifications.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _NotificationTile(item: item),
            ),
          ),
          if (controller.isLoadingMore.value) ...[
            const SizedBox(height: AppSpacing.md),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      );
    });
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxxl,
        ),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.60),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                IconsaxPlusLinear.notification_bing,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'notifications_empty_title'.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.ink,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'notifications_empty_message'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.inkMuted(0.54),
                height: 1.42,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends GetView<NotificationsController> {
  const _NotificationTile({required this.item});

  final DriverNotification item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !item.isRead;
    final routeLine = item.routeLine;
    final departure = item.departureAt == null
        ? null
        : Formatters.dateTime24(item.departureAt);

    return InkWell(
      onTap: () => controller.open(item),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 2),
      child: Container(
        decoration: softCardDecoration(context).copyWith(
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.26)
                : AppColors.secondary.withValues(alpha: 0.05),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.ink,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                      height: 1.16,
                    ),
                  ),
                ),
                if (isUnread) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            if (item.bookingCode != null) ...[
              const SizedBox(height: 4),
              Text(
                '#${item.bookingCode}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
            if (routeLine != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                routeLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.28,
                ),
              ),
            ] else if (!item.canOpenTrip && item.message.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  height: 1.28,
                ),
              ),
            ],
            if (departure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${'departure'.tr}: '),
                    TextSpan(
                      text: departure,
                      style: TextStyle(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ] else if (item.createdAtHuman != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.createdAtHuman!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
