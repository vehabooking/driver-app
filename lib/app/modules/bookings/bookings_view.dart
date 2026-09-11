import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/booking_list_item.dart';
import 'bookings_controller.dart';
import 'widgets/booking_card.dart';
import '../../core/theme/app_ink.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BookingsView extends GetView<BookingsController> {
  const BookingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.lg,
                AppSpacing.pageH,
                AppSpacing.md,
              ),
              child: _BookingsHeader(controller: controller),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                0,
                AppSpacing.pageH,
                AppSpacing.sm,
              ),
              child: _SegmentedTabs(controller: controller),
            ),
            Expanded(
              child: Obx(() {
                if (controller.error.value != null) {
                  return ErrorView(
                    message: controller.error.value!,
                    onRetry: controller.fetch,
                  );
                }

                if (controller.items.isEmpty) {
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: controller.fetch,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.14,
                        ),
                        EmptyView(
                          title: 'no_bookings'.tr,
                          hint: 'no_bookings_hint'.tr,
                          icon: IconsaxPlusLinear.calendar_remove,
                        ),
                      ],
                    ),
                  );
                }

                // While loading, the real cards are rendered from placeholder
                // rows and traced by Skeletonizer - so the skeleton can never
                // drift from the card's actual layout.
                final loading = controller.isLoading.value;

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: controller.fetch,
                  child: Skeletonizer(
                    enabled: loading,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageH,
                        AppSpacing.sm,
                        AppSpacing.pageH,
                        AppSpacing.navClearance,
                      ),
                      children: loading
                          ? _placeholderRows()
                          : _buildRows(context),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Cards built from dummy data, for Skeletonizer to trace while loading.
  List<Widget> _placeholderRows() => List.generate(
    3,
    (_) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: BookingCard(booking: BookingListItem.placeholder(), onTap: () {}),
    ),
  );

  /// Flatten grouped sections into header + card rows.
  List<Widget> _buildRows(BuildContext context) {
    final sections = _groupByDay(
      controller.items.toList(),
      controller.groupByDay,
    );
    final rows = <Widget>[];
    for (final s in sections) {
      if (s.label != null) rows.add(_SectionHeader(label: s.label!));
      for (final b in s.items) {
        rows.add(
          BookingCard(
            booking: b,
            onTap: () => Get.toNamed(
              Routes.bookingDetail,
              arguments: {
                'uuid': b.uuid,
                if (b.assignmentId != null) 'assignment_id': b.assignmentId,
              },
            )?.then((_) => controller.fetch(silent: true)),
          ),
        );
      }
    }
    return rows;
  }
}

class _BookingsHeader extends StatelessWidget {
  const _BookingsHeader({required this.controller});

  final BookingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'bookings_title'.tr,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Obx(() {
                final active = controller.activeIndex.value;
                final copy = switch (active) {
                  0 => 'bookings_subtitle_assigned'.tr,
                  1 => 'bookings_subtitle_active'.tr,
                  _ => 'bookings_subtitle_completed'.tr,
                };
                return Text(
                  copy,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

/// One day-bucket of trips. A null [label] renders as a flat (un-grouped) list.
class _Section {
  const _Section(this.label, this.items);
  final String? label;
  final List<BookingListItem> items;
}

/// Group scheduled trips into Today / Tomorrow / Later. Overdue trips fall
/// into Today so they surface at the top.
List<_Section> _groupByDay(List<BookingListItem> items, bool group) {
  if (!group) return [_Section(null, items)];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  final todayItems = <BookingListItem>[];
  final tomorrowItems = <BookingListItem>[];
  final laterItems = <BookingListItem>[];

  for (final b in items) {
    final dt = DateTime.tryParse(b.displayDepartureDatetime)?.toLocal();
    if (dt == null) {
      laterItems.add(b);
      continue;
    }
    final d = DateTime(dt.year, dt.month, dt.day);
    if (!d.isAfter(today)) {
      todayItems.add(b); // today or overdue
    } else if (d == tomorrow) {
      tomorrowItems.add(b);
    } else {
      laterItems.add(b);
    }
  }

  return [
    if (todayItems.isNotEmpty) _Section('section_today'.tr, todayItems),
    if (tomorrowItems.isNotEmpty)
      _Section('section_tomorrow'.tr, tomorrowItems),
    if (laterItems.isNotEmpty) _Section('section_later'.tr, laterItems),
  ];
}

/// Compact segmented control with individual chips and live count badges.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.controller});

  final BookingsController controller;

  static const _labels = ['tab_assigned', 'tab_active', 'tab_completed'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final active = controller.activeIndex.value;
      final c = controller.counts.value;
      final countFor = [c.assigned, c.active, c.completed];

      return Container(
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: List.generate(3, (i) {
            final selected = i == active;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.tabController.animateTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusXl - 4,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _labels[i].tr,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: selected
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (countFor[i] > 0) ...[
                        const SizedBox(width: 5),
                        _Badge(count: countFor[i], selected: selected),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      );
    });
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.22)
            : AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }
}

/// Uppercase day-group header with a trailing divider line.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11.5,
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Divider(color: theme.colorScheme.outlineVariant, height: 1),
          ),
        ],
      ),
    );
  }
}
