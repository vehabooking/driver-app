import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/arrival_rule_note.dart';
import '../../core/widgets/pickup_issue_sheet.dart';
import '../../core/widgets/section_label.dart';
import '../../core/widgets/stale_trip_notice.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/step_action_button.dart';
import '../../core/widgets/swipe_to_confirm.dart';
import '../../core/widgets/trip_step_tracker.dart';
import '../../data/models/booking_list_item.dart';
import '../booking_detail/dispatch_review_sheet.dart';
import 'dashboard_controller.dart';

/// Clean operational card surface: white, subtle border, restrained shadow.
BoxDecoration _softCard(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(
        alpha: isDark ? 0.44 : 0.34,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.secondary.withValues(alpha: isDark ? 0.0 : 0.055),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final canvas = isDark ? scheme.surface : AppColors.canvas;

    return Scaffold(
      backgroundColor: canvas,
      body: Obx(() {
        if (controller.isLoading.value && controller.summary.value == null) {
          return const LoadingView();
        }
        if (controller.error.value != null &&
            controller.summary.value == null) {
          return ErrorView(
            message: controller.error.value!,
            onRetry: controller.load,
          );
        }
        final upcoming = controller.summary.value?.upcoming ?? const [];

        return Container(
          decoration: BoxDecoration(color: canvas),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageH,
                  AppSpacing.lg,
                  AppSpacing.pageH,
                  AppSpacing.navClearance + AppSpacing.lg,
                ),
                children: [
                  _Hero(controller: controller),
                  const SizedBox(height: AppSpacing.xl),
                  // The one trip to act on, or its own empty template. It sits
                  // directly under the hero with no header - the card carries
                  // its own status chip, so a label above it only added noise.
                  _nextPickup(context),
                  const SizedBox(height: AppSpacing.xxl),
                  // UPCOMING — the queue, or its own empty template.
                  SectionLabel('section_upcoming'.tr),
                  const SizedBox(height: AppSpacing.lg),
                  if (upcoming.isNotEmpty) ...[
                    for (final b in upcoming) ...[
                      _UpcomingItem(booking: b, controller: controller),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ] else
                    _emptyUpcoming(),
                  const SizedBox(height: AppSpacing.xxl),
                  SectionLabel('overview'.tr),
                  const SizedBox(height: AppSpacing.lg),
                  _stats(),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _nextPickup(BuildContext context) {
    final next = controller.summary.value?.nextPickup;
    if (next == null) {
      return _emptyNow().animate().fadeIn(duration: 300.ms).slideY(begin: 0.04);
    }
    return _NextPickupCard(
      next: next,
      controller: controller,
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  /// NOW empty — status-aware (reflects why there's no active trip).
  Widget _emptyNow() {
    final hasUpcoming =
        (controller.summary.value?.upcoming.isNotEmpty) ?? false;
    final (IconData icon, String title, String hint) = switch ((
      controller.status.value,
      controller.active.value,
      hasUpcoming,
    )) {
      ('pending', _, _) => (
        IconsaxPlusBold.shield_search,
        'empty_pending_title'.tr,
        'empty_pending_hint'.tr,
      ),
      ('rejected', _, _) => (
        IconsaxPlusBold.shield_cross,
        'empty_rejected_title'.tr,
        'empty_rejected_hint'.tr,
      ),
      ('approved', false, _) => (
        IconsaxPlusBold.toggle_off_circle,
        'empty_inactive_title'.tr,
        'empty_inactive_hint'.tr,
      ),
      ('approved', true, true) => (
        IconsaxPlusBold.calendar_tick,
        'empty_assigned_title'.tr,
        'empty_assigned_hint'.tr,
      ),
      _ => (
        IconsaxPlusBold.routing,
        'empty_ready_title'.tr,
        'empty_ready_hint'.tr,
      ),
    };
    return _EmptyCard(icon: icon, title: title, hint: hint);
  }

  Color get themeColorInactive =>
      Get.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  /// UPCOMING empty — the schedule queue is clear.
  Widget _emptyUpcoming() => _EmptyCard(
    icon: IconsaxPlusBold.calendar,
    title: 'empty_upcoming_title'.tr,
    hint: 'empty_upcoming_hint'.tr,
  );

  Widget _stats() {
    final counts = controller.summary.value?.counts;
    final items = [
      ('assigned', counts?.assigned ?? 0, 'tab_assigned'),
      ('active', counts?.active ?? 0, 'tab_active'),
      ('completed', counts?.completed ?? 0, 'tab_completed'),
    ];
    // Gaps go *between* the cards only - a symmetric padding on each one would
    // inset the row's outer edges and break alignment with the section titles
    // and the cards above.
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatCard(
              stage: items[i].$1,
              count: items[i].$2,
              label: items[i].$3.tr,
              onTap: () => controller.goToBookings(items[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

/// Calm home header: date, working state, notifications, greeting.
class _Hero extends StatelessWidget {
  const _Hero({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'good_morning'
        : (hour < 17 ? 'good_afternoon' : 'good_evening');
    final display = GoogleFonts.fraunces(
      fontSize: 28,
      height: 1.05,
      letterSpacing: -0.15,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The greeting shares its row with the bell, and the status pill moves
        // down beside the driver name - otherwise both rows sit half-empty.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                '${greeting.tr},',
                style: display.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.86),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Notification bell.
            Obx(
              () => InkWell(
                onTap: controller.openNotifications,
                borderRadius: BorderRadius.circular(40),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.76),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.045),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        IconsaxPlusLinear.notification,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    if (controller.unreadNotifications.value > 0)
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.cancelled,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            controller.unreadNotifications.value > 9
                                ? '9+'
                                : controller.unreadNotifications.value
                                      .toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Obx(() {
          final name = controller.user?.displayName ?? '';

          // Baseline-aligned so the status word sits on the same line as the
          // name and its full stop, instead of floating at the name's mid
          // height. The name is ellipsised so a long one cannot push the
          // status off screen.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.primary : AppColors.secondary,
                  ),
                ),
              ),
              Text(
                '.',
                style: display.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _driverStatus(context, controller).$1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusText(controller: controller),
            ],
          );
        }),
      ],
    );
  }
}

/// Compact working-state pill (header): Active/Inactive for approved drivers,
/// with Pending/Rejected verification states taking priority.
/// Driver working-state color + label, shared by the status text and the
/// coloured full stop after the driver name.
(Color, String) _driverStatus(BuildContext context, DashboardController c) {
  return switch (c.status.value) {
    'pending' => (AppColors.assigned, 'status_pending'.tr),
    'rejected' => (AppColors.pickupIssue, 'status_rejected'.tr),
    'approved' when c.active.value => (AppColors.completed, 'status_active'.tr),
    'approved' => (Theme.of(context).colorScheme.outline, 'status_inactive'.tr),
    _ => (AppColors.assigned, 'status_pending'.tr),
  };
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final (color, label) = _driverStatus(context, controller);

      // Plain text, no chip and no dot of its own - the full stop after the
      // driver name is the status dot.
      return Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      );
    });
  }
}

/// Compact upcoming pickup row: departure · booking code · route.
class _UpcomingItem extends StatelessWidget {
  const _UpcomingItem({required this.booking, required this.controller});

  final BookingListItem booking;
  final DashboardController controller;

  /// Relative departure day: "Today" / "Tomorrow" / "21 Jun".
  String _dayLabel() {
    final diff = Formatters.daysFromToday(booking.displayDepartureDatetime);
    return switch (diff) {
      0 => 'section_today'.tr,
      1 => 'section_tomorrow'.tr,
      _ => Formatters.shortDate(booking.displayDepartureDatetime),
    };
  }

  String _legLabel() {
    final trip = booking.isRoundTrip ? 'round_trip_badge'.tr : 'one_way'.tr;
    final leg = booking.isReturnLeg
        ? 'trip_leg_return'.tr
        : 'trip_leg_outbound'.tr;

    return '$trip · $leg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.openBooking(
          booking.uuid,
          assignmentId: booking.assignmentId,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          decoration: _softCard(context),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dayLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      Formatters.time(booking.displayDepartureDatetime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.code == null ? '—' : '#${booking.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _legLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${booking.driverRouteOriginLabel} to ${booking.driverRouteDestinationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                IconsaxPlusLinear.arrow_right_3,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextPickupCard extends StatelessWidget {
  const _NextPickupCard({required this.next, required this.controller});

  final BookingListItem next;
  final DashboardController controller;

  bool get _showsDropoffRoute =>
      next.stage == 'meet_passenger' ||
      next.stage == 'drop_passenger' ||
      next.nextAction == 'complete';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showProgress =
        next.stage != 'cancelled' && next.stage != 'pickup_issue';

    return Container(
      decoration: _softCard(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: controller.openNextPickup,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardHeader(theme),
              const SizedBox(height: AppSpacing.md),
              _routeScheduleGrid(theme),
              if (next.hasDropoff) ...[
                const SizedBox(height: AppSpacing.sm),
                _routeActionButton(theme),
              ],
              if (next.isStartOverdue && !next.isStartTooOld) ...[
                const SizedBox(height: AppSpacing.sm),
                _startOverdueNotice(theme),
              ],

              if (showProgress) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: TripStepTracker(stage: next.stage),
                ),
              ],
              if (next.needsResolution) ...[
                const SizedBox(height: AppSpacing.md),
                const StaleTripNotice(),
              ],
              if (next.isStartBlocked) ...[
                const SizedBox(height: AppSpacing.md),
                _blockingTripNotice(theme),
              ],
              // The standing arrival rule, shown wherever the driver decides
              // whether to set off.
              if (!next.needsResolution && next.nextAction != null) ...[
                const SizedBox(height: AppSpacing.md),
                const ArrivalRuleNote(),
              ],
              if (next.nextAction != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _action(theme, next.nextAction!),
                if (_canReportPickupIssue) ...[
                  const SizedBox(height: 2),
                  _pickupIssueButton(context, theme),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  DateTime? get _departureAt =>
      DateTime.tryParse(next.displayDepartureDatetime)?.toLocal();

  String _departureDateLabel() {
    final departureAt = _departureAt;
    if (departureAt == null) {
      return Formatters.dateTime(next.displayDepartureDatetime);
    }

    return DateFormat('EEE, d MMM yyyy').format(departureAt);
  }

  String _departureTimeLabel() {
    final departureAt = _departureAt;
    if (departureAt == null) {
      return Formatters.time(next.displayDepartureDatetime);
    }

    return DateFormat('h:mm a').format(departureAt);
  }

  Widget _cardHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color:
                (next.needsResolution ? AppColors.assigned : AppColors.primary)
                    .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                next.needsResolution
                    ? IconsaxPlusLinear.timer_1
                    : IconsaxPlusLinear.flash_1,
                size: 12,
                color: next.needsResolution
                    ? AppColors.assigned
                    : AppColors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                (next.needsResolution
                        ? 'trip_needs_review'.tr
                        : 'needs_action'.tr)
                    .toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: next.needsResolution
                      ? AppColors.assigned
                      : AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        if (next.code != null && next.code!.isNotEmpty) ...[
          const Spacer(),
          Text(
            next.code!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }

  Widget _routeTimeline(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _routePointRow(
          theme,
          color: AppColors.primary,
          child: _routePoint(
            theme,
            label: 'origin'.tr,
            title: next.driverRouteOriginLabel,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 7, top: 4, bottom: 4),
          child: _routeConnector(theme),
        ),
        _routePointRow(
          theme,
          color: AppColors.cancelled,
          pin: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _routePoint(
                theme,
                label: 'destination'.tr,
                title: next.driverRouteDestinationLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _routeScheduleGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: compact ? 10 : 11, child: _routeTimeline(theme)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
                  vertical: 8,
                ),
                child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.38,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Expanded(flex: compact ? 8 : 9, child: _schedulePanel(theme)),
            ],
          ),
        );
      },
    );
  }

  Widget _routePointRow(
    ThemeData theme, {
    required Color color,
    bool pin = false,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: pin ? 10 : 1),
          child: pin ? _routePin(color) : _routeDot(color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: child),
      ],
    );
  }

  Widget _routeConnector(ThemeData theme) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          width: 1.5,
          height: 6,
          margin: EdgeInsets.only(bottom: index == 2 ? 0 : 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _routeDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _routePin(Color color) {
    return SizedBox(
      width: 18,
      height: 21,
      child: Icon(Icons.location_on_rounded, size: 21, color: color),
    );
  }

  Widget _routePoint(
    ThemeData theme, {
    String? label,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label.trim().isNotEmpty) ...[
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w700,
              fontSize: 8.5,
              letterSpacing: 0.35,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
        ],
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            letterSpacing: 0,
            height: 1.15,
          ),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
        if (trailing != null) ...[const SizedBox(height: 8), trailing],
      ],
    );
  }

  Widget _tripMeta(ThemeData theme) {
    final facts = [
      next.isRoundTrip ? 'round_trip_badge'.tr : 'one_way'.tr,
      if (next.passengerCount != null)
        '${next.passengerCount} ${'pax_label'.tr}',
    ];

    return Text(
      facts.join('  ·  '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: theme.textTheme.labelMedium?.copyWith(
        color: AppColors.secondary.withValues(alpha: 0.86),
        fontWeight: FontWeight.w500,
        fontSize: 11,
        height: 1.1,
        letterSpacing: 0,
      ),
    );
  }

  Widget _schedulePanel(ThemeData theme) {
    final timeLabel = _departureTimeLabel();

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _tripMeta(theme),
        const SizedBox(height: 7),
        _scheduleText(theme, value: _departureDateLabel()),
        const SizedBox(height: 5),
        _scheduleText(theme, value: timeLabel, highlighted: true),
        const SizedBox(height: 10),
        _passengerActionPanel(theme),
      ],
    );
  }

  Widget _scheduleText(
    ThemeData theme, {
    required String value,
    bool highlighted = false,
  }) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: theme.textTheme.labelLarge?.copyWith(
        color: highlighted ? AppColors.primary : AppColors.secondary,
        fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
        fontSize: highlighted ? 16 : 11,
        height: 1.1,
        letterSpacing: 0,
      ),
    );
  }

  Widget _passengerActionPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'customer_info'.tr.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w700,
            fontSize: 8,
            letterSpacing: 0.35,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          next.customerName ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.secondary.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            height: 1.15,
            letterSpacing: 0,
          ),
        ),
        if (next.hasPhone) ...[
          const SizedBox(height: 2),
          Text(
            next.customerPhone!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w400,
              fontSize: 10,
              height: 1.1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _routeActionButton(ThemeData theme) {
    final label =
        (_showsDropoffRoute ? 'view_dropoff_route' : 'view_pickup_route').tr;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.075),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('next-pickup-route-action'),
          onTap: controller.openNextPickupMap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    IconsaxPlusLinear.routing_2,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'route_action_hint'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontSize: 9.5,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    IconsaxPlusLinear.arrow_right_3,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blockingTripNotice(ThemeData theme) {
    final blockedBy = next.startBlockedBy!;
    final title = 'finish_trip_first_title'.trParams({
      'code': blockedBy.code ?? 'this trip',
    });
    final subtitleParts = <String>[
      if (blockedBy.customerName != null && blockedBy.customerName!.isNotEmpty)
        blockedBy.customerName!,
      if (blockedBy.legDepartureDatetime != null &&
          blockedBy.legDepartureDatetime!.isNotEmpty)
        Formatters.dateTime(blockedBy.legDepartureDatetime!),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.assigned.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.assigned.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              IconsaxPlusLinear.lock_1,
              size: 17,
              color: AppColors.assigned,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          TextButton(
            onPressed: controller.openBlockingTrip,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.assigned,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text('open_trip'.tr),
          ),
        ],
      ),
    );
  }

  /// The advance control: an animated next-step button for start/arrived/meet,
  /// and a deliberate swipe for the irreversible final drop. Lives on the card
  /// so the driver advances the trip without leaving Home.
  Widget _action(ThemeData theme, String action) {
    if (action == 'start' && next.isStartTooOld) {
      return _staleStartAction(theme);
    }

    if (action == 'complete') {
      return Obx(
        () => SwipeToConfirm(
          label: 'swipe_to_drop'.tr,
          loading: controller.isActing.value,
          onConfirmed: () => controller.runNextAction('complete'),
        ),
      );
    }

    if (action == 'resolve_completed') {
      return Obx(
        () => StepActionButton(
          label: 'resolve_trip'.tr,
          icon: IconsaxPlusLinear.tick_circle,
          loading: controller.isActing.value,
          onPressed: () async {
            if (await confirmLateTripCompletion()) {
              await controller.runNextAction(action);
            }
          },
        ),
      );
    }

    final (String label, IconData icon) = switch (action) {
      'start' => (
        next.isStartOverdue ? 'start_trip_now'.tr : 'start_now'.tr,
        IconsaxPlusLinear.play,
      ),
      'arrived' => ('mark_arrived'.tr, IconsaxPlusLinear.location_tick),
      'meet_passenger' => ('meet_passenger'.tr, IconsaxPlusLinear.profile_tick),
      _ => ('start_now'.tr, IconsaxPlusLinear.play),
    };

    return Obx(
      () => StepActionButton(
        label: label,
        icon: icon,
        loading: controller.isActing.value,
        // Confirm first: advancing a step cannot be undone from the app, and
        // this button sits right under the trip card where a mis-tap is easy.
        onPressed: () async {
          if (await confirmStepAction(action)) {
            await controller.runNextAction(action);
          }
        },
      ),
    );
  }

  bool get _canReportPickupIssue =>
      next.allowedActions.contains('report_pickup_issue');

  Widget _startOverdueNotice(ThemeData theme) {
    final isTooOld = next.isStartTooOld;
    final isVeryOverdue = next.isStartVeryOverdue;
    final color = isTooOld
        ? AppColors.cancelled
        : isVeryOverdue
        ? AppColors.assigned
        : AppColors.assigned;
    final key = isTooOld
        ? 'start_too_old_home'
        : isVeryOverdue
        ? 'start_very_overdue_home'
        : 'start_overdue_home';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            isTooOld
                ? IconsaxPlusLinear.info_circle
                : IconsaxPlusLinear.timer_1,
            size: 17,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              key.tr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _staleStartAction(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = (constraints.maxWidth * 0.34).clamp(108.0, 128.0);

        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.cancelled.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconsaxPlusLinear.headphone,
                  size: 16,
                  color: AppColors.cancelled.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'contact_dispatch_to_start'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.cancelled,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'start_too_old_home'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w500,
                        fontSize: 8.8,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: buttonWidth,
                child: OutlinedButton.icon(
                  onPressed: () => _showDispatchReviewSheet(context),
                  icon: const Icon(IconsaxPlusLinear.headphone, size: 13),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('contact_dispatch'.tr),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(34),
                    disabledForegroundColor: AppColors.cancelled.withValues(
                      alpha: 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    side: BorderSide(
                      color: AppColors.cancelled.withValues(alpha: 0.18),
                    ),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDispatchReviewSheet(BuildContext context) async {
    final detail = await controller.loadNextPickupDetail();
    if (!context.mounted || detail == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DispatchReviewSheet(
        operator: detail.operator,
        onCall: () => controller.callOperator(detail.operator),
        onEmail: () => controller.emailOperator(detail.operator),
      ),
    );
  }

  Widget _pickupIssueButton(BuildContext context, ThemeData theme) {
    return Obx(
      () => TextButton.icon(
        onPressed: controller.isActing.value
            ? null
            : () => showPickupIssueSheet(
                context: context,
                onSubmit: (reason, note) =>
                    controller.reportPickupIssue(reason, note: note),
                reasonOptions: next.pickupIssueReasonOptions,
                noteMaxLength: next.pickupIssueNoteMaxLength,
              ),
        icon: const Icon(IconsaxPlusLinear.search_status, size: 17),
        label: Text('pickup_issue_link'.tr),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Compact, modern empty template — a brand-haloed icon + title + hint. Used by
/// both the NOW and UPCOMING sections so each has its own purposeful empty state.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: _softCard(context),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl + AppSpacing.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bare glyph in the brand colour - no badge, no tint block.
          Icon(icon, size: 42, color: AppColors.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            hint,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.stage,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final String stage;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.forStage(stage);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: 4,
        ),
        decoration: _softCard(context),
        child: Column(
          children: [
            Text(
              '$count',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
