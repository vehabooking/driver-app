import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/arrival_rule_note.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/pickup_issue_sheet.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/stale_trip_notice.dart';
import '../../core/widgets/step_action_button.dart';
import '../../core/widgets/swipe_to_confirm.dart';
import '../../core/widgets/trip_step_tracker.dart';
import '../../data/models/booking_detail.dart';
import '../../data/models/place.dart';
import 'booking_detail_controller.dart';
import 'dispatch_review_sheet.dart';

class BookingDetailView extends GetView<BookingDetailController> {
  const BookingDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 74,
        titleSpacing: 0,
        leadingWidth: 64,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'booking_detail'.tr,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 21,
                letterSpacing: -0.15,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'booking_detail_subtitle'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const LoadingView();
        if (controller.error.value != null) {
          return ErrorView(
            message: controller.error.value!,
            onRetry: controller.load,
          );
        }
        final b = controller.booking.value;
        if (b == null) return _EmptyDetailState(onRetry: controller.load);
        return _Detail(b: b, controller: controller);
      }),
      bottomNavigationBar: Obx(() {
        final b = controller.booking.value;
        // Do not show a disabled footer for future/blocked trips. The server is
        // authoritative: the footer appears when it supplies an action.
        if (b == null || !b.can) {
          return const SizedBox.shrink();
        }
        return _StickyFooter(b: b, controller: controller);
      }),
    );
  }
}

/// Sticky footer: a glanceable horizontal step tracker over the action control.
class _StickyFooter extends StatelessWidget {
  const _StickyFooter({required this.b, required this.controller});

  final BookingDetail b;
  final BookingDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, -8),
                ),
              ],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          AppSpacing.sm + 2,
          AppSpacing.pageH,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TripStepTracker(
              stage: b.stage,
              driverTripStatus: b.driverTripStatus,
              compact: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const ArrivalRuleNote(),
            const SizedBox(height: AppSpacing.md),
            if (b.isStartOverdue) ...[
              _StartOverdueNotice(b: b),
              const SizedBox(height: AppSpacing.sm),
            ],
            // A trip left running long past its departure. The start-overdue
            // notices above only cover trips never started, so without this
            // an abandoned in-progress trip explains itself to nobody.
            if (b.isStaleInProgress) ...[
              const StaleTripNotice(),
              const SizedBox(height: AppSpacing.sm),
            ],
            _ActionBar(b: b, controller: controller),
            if (b.canReportPickupIssue) ...[
              const SizedBox(height: 2),
              Obx(
                () => TextButton(
                  onPressed: controller.isActing.value
                      ? null
                      : () => showPickupIssueSheet(
                          context: context,
                          onSubmit: controller.reportPickupIssue,
                          reasonOptions: b.pickupIssueReasonOptions,
                          noteMaxLength: b.pickupIssueNoteMaxLength,
                        ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('pickup_issue_link'.tr),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.b, required this.controller});

  final BookingDetail b;
  final BookingDetailController controller;

  bool get _hasPhone =>
      b.customerPhone != null &&
      b.customerPhone!.isNotEmpty &&
      b.customerPhone != 'N/A';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = _detailRows(theme);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          AppSpacing.md,
          AppSpacing.pageH,
          AppSpacing.lg,
        ),
        children: [
          // A finished trip is the first thing the driver should see — the
          // small chip inside the info card is easy to miss when scrolling.
          if (_outcome != null) ...[
            _outcomeBanner(theme, _outcome!),
            const SizedBox(height: AppSpacing.sm + 2),
          ],
          _destinationStrip(theme),
          const SizedBox(height: AppSpacing.sm + 2),
          _bookingInfoCard(theme),
          const SizedBox(height: AppSpacing.sm + 2),

          if (_hasAssignedVehicle) ...[
            _exactVehicleCard(theme),
            const SizedBox(height: AppSpacing.sm + 2),
          ],

          _customerCard(theme),
          const SizedBox(height: AppSpacing.sm + 2),

          if (b.hasOperatorContact) ...[
            _operatorCard(theme),
            const SizedBox(height: AppSpacing.sm + 2),
          ],

          // ── Pickup issue summary (terminal) ──
          if (b.stage == 'pickup_issue') ...[
            _PickupIssueSummary(reason: b.pickupIssueReason),
            const SizedBox(height: AppSpacing.sm + 2),
          ],

          // The API response represents one assignment and one exact booking leg.
          // Never reconstruct another leg by reversing this leg's route.
          _tripRouteCard(
            theme,
            title: b.isRoundTrip
                ? (b.isReturnLeg ? 'return_trip'.tr : 'outbound_trip'.tr)
                : 'route'.tr,
            legLabel: b.isRoundTrip
                ? (b.isReturnLeg
                      ? 'trip_leg_return'.tr
                      : 'trip_leg_outbound'.tr)
                : 'departure'.tr,
            when: b.displayDepartureDatetime,
            estimatedDropTime: _estimatedDropTime(b.displayDepartureDatetime),
            pickup: b.pickup,
            dropoff: b.dropoff,
            isCurrentLeg: true,
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // ── Extra details (only when present) ──
          if (details.isNotEmpty)
            _SectionCard(
              title: 'trip_details'.tr,
              child: Column(children: details),
            ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  bool get _hasEmail =>
      b.customerEmail != null &&
      b.customerEmail!.isNotEmpty &&
      b.customerEmail != 'N/A';

  bool get _hasAssignedVehicle =>
      b.assignedVehicleLabel != null ||
      (b.vehicleColor != null && b.vehicleColor!.isNotEmpty) ||
      b.vehicleSeats != null;

  String get _serviceLabel => b.serviceType?.capitalizeFirst ?? '—';

  String get _tripTypeLabel =>
      b.hasReturn ? 'round_trip_badge'.tr : 'one_way'.tr;

  /// How this trip ended, or null while it is still running.
  ({IconData icon, Color color, String title, bool animated})? get _outcome {
    if (b.pickupIssueReason != null || b.stage == 'pickup_issue') {
      return (
        icon: IconsaxPlusLinear.info_circle,
        color: AppColors.pickupIssue,
        title: 'outcome_pickup_issue'.tr,
        animated: false,
      );
    }

    if (b.status == 'cancelled' || b.stage == 'cancelled') {
      return (
        icon: IconsaxPlusLinear.close_circle,
        color: AppColors.cancelled,
        title: 'outcome_cancelled'.tr,
        animated: false,
      );
    }

    if (b.status == 'completed' ||
        b.stage == 'completed' ||
        b.driverTripStatus == 'drop_passenger') {
      return (
        icon: IconsaxPlusLinear.tick_circle,
        color: AppColors.completed,
        title: 'outcome_completed'.tr,
        animated: true,
      );
    }

    return null;
  }

  Widget _outcomeBanner(
    ThemeData theme,
    ({IconData icon, Color color, String title, bool animated}) outcome,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (outcome.animated)
            Lottie.asset(
              'assets/animations/check.json',
              width: 128,
              height: 128,
              fit: BoxFit.contain,
            )
          else
            Icon(outcome.icon, size: 76, color: outcome.color),
          // The composition is padded inside its own canvas, so pull the label
          // up rather than leaving a gap the layout cannot see.
          Transform.translate(
            offset: Offset(0, outcome.animated ? -26 : 4),
            child: Text(
              outcome.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: outcome.color,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingInfoCard(ThemeData theme) {
    return _SectionCard(
      title: 'booking_info'.tr,
      titleGap: AppSpacing.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _summaryPill(
                      theme,
                      icon: IconsaxPlusLinear.ticket,
                      value: '#${b.code ?? '—'}',
                    ),
                    _summaryPill(
                      theme,
                      icon: IconsaxPlusLinear.routing_2,
                      value: _serviceLabel,
                    ),
                    _summaryPill(
                      theme,
                      icon: IconsaxPlusLinear.routing_2,
                      value: _tripTypeLabel,
                    ),
                  ],
                ),
              ),
              if (_outcome == null) ...[
                const SizedBox(width: AppSpacing.sm),
                _detailStatusBadge(theme),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _compactInfoRow(
            theme,
            icon: IconsaxPlusLinear.profile_2user,
            label: 'passengers'.tr,
            value: '${b.passengerCount ?? 1}',
          ),
          if (b.vehicleBooked != null && b.vehicleBooked!.isNotEmpty) ...[
            const _DottedRowSeparator(),
            _compactInfoRow(
              theme,
              icon: IconsaxPlusBold.car,
              label: 'vehicle_booked'.tr,
              value: b.vehicleBooked!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailStatusBadge(ThemeData theme) {
    final color = AppColors.forStage(b.stage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'stage_${b.stage}'.tr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0,
          height: 1,
        ),
      ),
    );
  }

  Widget _destinationStrip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                IconsaxPlusLinear.routing_2,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'route'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _destinationPoint(
                  theme,
                  label: 'origin'.tr,
                  value: _routeOriginLabel,
                  alignEnd: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  top: 18,
                ),
                child: Icon(
                  IconsaxPlusLinear.arrow_right_3,
                  size: 16,
                  color: AppColors.secondary.withValues(alpha: 0.42),
                ),
              ),
              Expanded(
                child: _destinationPoint(
                  theme,
                  label: 'destination'.tr,
                  value: _routeDestinationLabel,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _routeOriginLabel {
    final value = b.routeOrigin;
    return value != null && value.isNotEmpty ? value : b.pickup.label;
  }

  String get _routeDestinationLabel {
    final value = b.routeDestination;
    return value != null && value.isNotEmpty ? value : b.dropoff.label;
  }

  Widget _destinationPoint(
    ThemeData theme, {
    required String label,
    required String value,
    required bool alignEnd,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
            fontSize: 8.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1.16,
          ),
        ),
      ],
    );
  }

  Widget _customerCard(ThemeData theme) {
    return _SectionCard(
      title: 'customer_info'.tr,
      titleGap: AppSpacing.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.customerName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (_hasPhone) ...[
                const SizedBox(width: AppSpacing.sm),
                _callButton(),
              ],
            ],
          ),
          if (_hasPhone) ...[
            const _DottedRowSeparator(),
            _compactInfoRow(
              theme,
              icon: IconsaxPlusLinear.call,
              label: 'phone'.tr,
              value: b.customerPhone!,
            ),
          ],
          if (_hasEmail) ...[
            const _DottedRowSeparator(),
            _compactInfoRow(
              theme,
              icon: IconsaxPlusLinear.sms,
              label: 'email'.tr,
              value: b.customerEmail!,
            ),
          ],
          if (b.nationality != null && b.nationality!.isNotEmpty) ...[
            const _DottedRowSeparator(),
            _compactInfoRow(
              theme,
              icon: IconsaxPlusLinear.global,
              label: 'nationality'.tr,
              value: b.nationality!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _exactVehicleCard(ThemeData theme) {
    final assigned = b.assignedVehicleLabel ?? '—';
    final specsParts = <String>[
      if (b.vehicleColor != null && b.vehicleColor!.isNotEmpty) b.vehicleColor!,
      if (b.vehicleSeats != null)
        '${b.vehicleSeats} ${'seats'.tr.toLowerCase()}',
    ];
    final specs = specsParts.join(' · ');

    return _SectionCard(
      title: 'exact_vehicle_info'.tr,
      titleGap: AppSpacing.sm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              IconsaxPlusBold.car,
              size: 21,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assigned,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
                if (specs.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    specs,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 11,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(
    ThemeData theme, {
    required IconData icon,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInfoRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }

  String? _estimatedDropTime(String departure) {
    if (departure == b.displayDepartureDatetime &&
        b.arrivalDatetime != null &&
        b.arrivalDatetime!.isNotEmpty) {
      final value = Formatters.time(b.arrivalDatetime);
      if (value != '—') return value;
    }

    final duration = b.duration;
    if (duration == null || duration <= 0) return null;

    final departureAt = DateTime.tryParse(departure);
    if (departureAt == null) return null;

    final estimate = departureAt.add(Duration(minutes: duration));
    final value = Formatters.time(estimate.toIso8601String());
    return value == '—' ? null : value;
  }

  /// Round call button — dials the passenger.
  Widget _callButton() => Material(
    color: AppColors.primary.withValues(alpha: 0.12),
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: controller.callCustomer,
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(IconsaxPlusBold.call, size: 18, color: AppColors.primary),
      ),
    ),
  );

  Widget _tripRouteCard(
    ThemeData theme, {
    required String title,
    required String legLabel,
    required String when,
    String? estimatedDropTime,
    required Place pickup,
    required Place dropoff,
    required bool isCurrentLeg,
    String? footer,
  }) {
    final navigateToDropoff = _navigatesToDropoff;
    final canViewRoute =
        isCurrentLeg &&
        !b.isClosed &&
        pickup.hasCoordinates &&
        dropoff.hasCoordinates;

    return _SectionCard(
      title: title,
      titleGap: AppSpacing.xs + 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _departureRow(
            theme,
            legLabel: legLabel,
            when: when,
            estimatedDropTime: estimatedDropTime,
          ),
          const _RouteCardSeparator(),
          _routeStop(theme, isOrigin: true, place: pickup),
          _routeStop(theme, isOrigin: false, place: dropoff),
          if (canViewRoute) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            _routeMapButton(
              label: navigateToDropoff
                  ? 'view_dropoff_route'.tr
                  : 'view_pickup_route'.tr,
              onTap: () {
                controller.openMap();
              },
            ),
          ],
          if (footer != null && footer.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              footer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _navigatesToDropoff =>
      b.stage == 'meet_passenger' || b.stage == 'drop_passenger';

  Widget _routeMapButton({required String label, required VoidCallback onTap}) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      IconsaxPlusLinear.map,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    IconsaxPlusLinear.arrow_right_3,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _departureRow(
    ThemeData theme, {
    required String legLabel,
    required String when,
    String? estimatedDropTime,
  }) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            IconsaxPlusBold.calendar,
            size: 14,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 1),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                legLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                Formatters.dateTime(when),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        // Estimated drop-off time (departure + route duration).
        if (estimatedDropTime != null && estimatedDropTime.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'est_drop'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                estimatedDropTime,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 13,
                  letterSpacing: 0,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  /// A pickup/drop-off stop in the route mini-timeline: marker + name + address.
  Widget _routeStop(
    ThemeData theme, {
    required bool isOrigin,
    required Place place,
  }) {
    final showConnector = isOrigin;
    final address =
        (place.address != null &&
            place.address!.isNotEmpty &&
            place.address != place.locationName)
        ? place.address
        : null;
    final nearby =
        (place.nearbyLocation != null && place.nearbyLocation!.isNotEmpty)
        ? place.nearbyLocation
        : null;
    final marker = _routeMarker(isOrigin: isOrigin);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Padding(padding: const EdgeInsets.only(top: 3), child: marker),
              if (showConnector) const _RouteVerticalConnector(),
            ],
          ),
          const SizedBox(width: AppSpacing.sm + 3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: showConnector ? AppSpacing.sm + 2 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (isOrigin ? 'pickup'.tr : 'dropoff'.tr).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.45,
                      fontSize: 8.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                      fontSize: 14,
                      height: 1.15,
                    ),
                  ),
                  if (address != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                  if (nearby != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            IconsaxPlusLinear.location,
                            size: 13,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${'nearby'.tr}: $nearby',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeMarker({required bool isOrigin}) {
    if (!isOrigin) {
      return const SizedBox(
        width: 18,
        height: 21,
        child: Icon(
          Icons.location_on_rounded,
          size: 21,
          color: AppColors.cancelled,
        ),
      );
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
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

  Widget _operatorCard(ThemeData theme) {
    final operator = b.operator!;

    return _SectionCard(
      title: 'operator_info'.tr,
      titleGap: AppSpacing.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(
                  IconsaxPlusLinear.building,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operator.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.secondary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'operator'.tr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (operator.hasPhone) ...[
                const SizedBox(width: AppSpacing.sm),
                Material(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: controller.callOperator,
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(
                        IconsaxPlusBold.call,
                        size: 17,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (operator.phone != null || operator.email != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (operator.phone != null)
                  _contactPill(
                    theme,
                    icon: IconsaxPlusLinear.call,
                    value: operator.phone!,
                    onTap: operator.hasPhone ? controller.callOperator : null,
                  ),
                if (operator.email != null)
                  _contactPill(
                    theme,
                    icon: IconsaxPlusLinear.sms,
                    value: operator.email!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _contactPill(
    ThemeData theme, {
    required IconData icon,
    required String value,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Extra trip rows (flight / notes), divider-separated.
  List<Widget> _detailRows(ThemeData theme) {
    final rows = <Widget>[];
    void add(IconData icon, String label, String value) {
      if (rows.isNotEmpty) rows.add(const Divider(height: 1));
      rows.add(InfoRow(icon: icon, label: label, value: value));
    }

    if (b.isAirport && b.flightNumber != null) {
      add(
        IconsaxPlusLinear.airplane,
        'flight'.tr,
        [
          b.flightNumber,
          b.airline,
          b.terminal,
        ].where((e) => e != null && e.isNotEmpty).join(' · '),
      );
    }
    if (b.notes != null && b.notes!.isNotEmpty) {
      add(IconsaxPlusLinear.document_text, 'notes'.tr, b.notes!);
    }
    return rows;
  }
}

/// Soft card wrapper with an optional section title.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.title,
    this.titleGap = AppSpacing.md,
  });

  final Widget child;
  final String? title;
  final double titleGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.55,
                fontSize: 9.5,
                height: 1,
              ),
            ),
            SizedBox(height: titleGap),
          ],
          child,
        ],
      ),
    );
  }
}

class _DottedRowSeparator extends StatelessWidget {
  const _DottedRowSeparator();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.58);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dotCount = (constraints.maxWidth / 8).floor().clamp(16, 64);

          return Row(
            children: List.generate(dotCount, (index) {
              return Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2.1,
                    height: 2.1,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _RouteCardSeparator extends StatelessWidget {
  const _RouteCardSeparator();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.58);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dotCount = (constraints.maxWidth / 8).floor().clamp(16, 64);

          return Row(
            children: List.generate(dotCount, (index) {
              return Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2.1,
                    height: 2.1,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _RouteVerticalConnector extends StatelessWidget {
  const _RouteVerticalConnector();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        children: List.generate(4, (index) {
          return Container(
            width: 1.5,
            height: 5,
            margin: EdgeInsets.only(bottom: index == 3 ? 0 : 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}

class _EmptyDetailState extends StatelessWidget {
  const _EmptyDetailState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              IconsaxPlusLinear.document,
              size: 34,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'error_generic'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(IconsaxPlusLinear.refresh, size: 16),
              label: Text('retry'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom action dock: one glanceable stage CTA. Tap for routine steps;
/// swipe for the final, irreversible drop.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.b, required this.controller});

  final BookingDetail b;
  final BookingDetailController controller;

  @override
  Widget build(BuildContext context) {
    if (b.allows('start') && b.isStartTooOld) {
      return _staleStartAction(context);
    }

    return Obx(() {
      // Final step is a deliberate swipe.
      if (b.allows('complete')) {
        return SwipeToConfirm(
          label: 'swipe_to_drop'.tr,
          loading: controller.isActing.value,
          onConfirmed: controller.complete,
        );
      }

      if (b.allows('resolve_completed')) {
        return StepActionButton(
          label: 'resolve_trip'.tr,
          icon: IconsaxPlusLinear.tick_circle,
          loading: controller.isActing.value,
          onPressed: () async {
            if (await confirmLateTripCompletion()) {
              await controller.resolveLateCompletion();
            }
          },
        );
      }

      final action = b.allowedActions.isNotEmpty
          ? b.allowedActions.first
          : null;
      if (action == null) return const SizedBox.shrink();

      final (String label, IconData icon) = switch (action) {
        'start' => (
          b.isStartOverdue ? 'start_trip_now'.tr : 'start_now'.tr,
          IconsaxPlusLinear.play,
        ),
        'arrived' => ('mark_arrived'.tr, IconsaxPlusLinear.location_tick),
        'meet_passenger' => (
          'meet_passenger'.tr,
          IconsaxPlusLinear.profile_tick,
        ),
        _ => ('start_now'.tr, IconsaxPlusLinear.play),
      };

      return StepActionButton(
        label: label,
        icon: icon,
        loading: controller.isActing.value,
        // Confirm first: advancing a step cannot be undone from the app.
        onPressed: () async {
          if (await confirmStepAction(action)) {
            controller.runAction(action);
          }
        },
      );
    });
  }

  Widget _staleStartAction(BuildContext context) {
    final theme = Theme.of(context);
    const color = AppColors.cancelled;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDispatchReviewSheet(context),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconsaxPlusLinear.headphone,
                size: 15,
                color: color.withValues(alpha: 0.82),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'contact_dispatch_to_review'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDispatchReviewSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DispatchReviewSheet(
        operator: b.operator,
        onCall: controller.callOperator,
        onEmail: controller.emailOperator,
      ),
    );
  }
}

class _StartOverdueNotice extends StatelessWidget {
  const _StartOverdueNotice({required this.b});

  final BookingDetail b;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTooOld = b.isStartTooOld;
    final isVeryOverdue = b.isStartVeryOverdue;
    final color = isTooOld
        ? AppColors.cancelled
        : isVeryOverdue
        ? AppColors.assigned
        : AppColors.assigned;
    final key = isTooOld
        ? 'dispatch_must_review_detail'
        : isVeryOverdue
        ? 'start_very_overdue_detail'
        : 'start_overdue_detail';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.12)),
            ),
            child: Icon(
              isTooOld
                  ? IconsaxPlusLinear.info_circle
                  : IconsaxPlusLinear.timer_1,
              size: 15,
              color: color.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              key.tr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.94),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Terminal summary on the detail screen once the driver reported they couldn't
/// meet the passenger.
class _PickupIssueSummary extends StatelessWidget {
  const _PickupIssueSummary({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.pickupIssue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(
            IconsaxPlusLinear.info_circle,
            color: AppColors.pickupIssue,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'report_pickup_issue_title'.tr,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (reason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    pickupIssueReasonLabel(reason),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
