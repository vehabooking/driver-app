import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/collect_payment_pill.dart';
import '../../../core/widgets/trip_step_tracker.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/booking_list_item.dart';

/// Tappable summary card for one driver trip leg.
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.onTap});

  final BookingListItem booking;
  final VoidCallback onTap;

  bool get _showSteps =>
      booking.stage != 'cancelled' && booking.stage != 'pickup_issue';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: isDark ? 0 : 0.045),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: isDark ? 0 : 0.085),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(theme),
                const SizedBox(height: AppSpacing.md),
                _mainGrid(theme),
                const SizedBox(height: AppSpacing.sm),
                _vehicleLine(theme),
                if (_showSteps) ...[
                  const SizedBox(height: AppSpacing.md),
                  TripStepTracker(
                    stage: booking.stage,
                    driverTripStatus: booking.driverTripStatus,
                  ),
                ],
                if (booking.nextAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _nextActionHint(theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            booking.code ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ),
        if (booking.requiresPaymentCollection) ...[
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: CollectPaymentPill(payment: booking.payment)),
        ],
        const SizedBox(width: AppSpacing.sm),
        _statusBadge(theme),
      ],
    );
  }

  Widget _statusBadge(ThemeData theme) {
    final color = AppColors.forStage(booking.stage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _stageLabel(),
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

  String _stageLabel() {
    return switch (booking.stage) {
      'assigned' => 'tab_assigned'.tr,
      'start' => 'start_now'.tr,
      'arrived_location' => 'step_short_arrived'.tr,
      'meet_passenger' => 'step_short_meet'.tr,
      'completed' || 'drop_passenger' => 'tab_completed'.tr,
      'pickup_issue' => 'pickup_issue_link'.tr,
      'cancelled' => 'cancelled'.tr,
      _ => booking.stage.capitalizeFirst ?? booking.stage,
    };
  }

  Widget _mainGrid(ThemeData theme) {
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
                  vertical: 7,
                ),
                child: Container(
                  width: 1,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.34,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Expanded(flex: compact ? 8 : 9, child: _detailsPanel(theme)),
            ],
          ),
        );
      },
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
            title: booking.driverRouteOriginLabel,
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
          child: _routePoint(
            theme,
            label: 'destination'.tr,
            title: booking.driverRouteDestinationLabel,
          ),
        ),
      ],
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

  Widget _routeDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

  Widget _routePoint(
    ThemeData theme, {
    required String label,
    required String title,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w700,
            fontSize: 8,
            letterSpacing: 0.35,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
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
      ],
    );
  }

  Widget _detailsPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _tripMeta(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.secondary.withValues(alpha: 0.84),
            fontWeight: FontWeight.w500,
            fontSize: 11,
            letterSpacing: 0,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        _dateLine(theme, _legLabel(), booking.displayDepartureDatetime),
        if (booking.isRoundTrip && _linkedWhen().isNotEmpty) ...[
          const SizedBox(height: 5),
          _dateLine(theme, _linkedLegLabel(), _linkedWhen(), muted: true),
        ],
        const SizedBox(height: 9),
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
          booking.customerName ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.secondary.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0,
            height: 1.15,
          ),
        ),
        if (booking.hasPhone) ...[
          const SizedBox(height: 2),
          Text(
            booking.customerPhone!,
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

  String _tripMeta() {
    final parts = [
      booking.isRoundTrip ? 'round_trip_badge'.tr : 'one_way'.tr,
      if (booking.passengerCount != null)
        '${booking.passengerCount} ${'pax_label'.tr}',
      if (booking.serviceType != null && booking.serviceType!.isNotEmpty)
        booking.serviceType!.capitalizeFirst ?? booking.serviceType!,
    ];

    return parts.join('  ·  ');
  }

  Widget _dateLine(
    ThemeData theme,
    String label,
    String value, {
    bool muted = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w700,
            fontSize: 8,
            letterSpacing: 0.3,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          Formatters.dateTime(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: theme.textTheme.labelLarge?.copyWith(
            color: muted ? theme.colorScheme.outline : AppColors.secondary,
            fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
            fontSize: muted ? 10.5 : 11.5,
            letterSpacing: 0,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  String _legLabel() {
    return booking.isReturnLeg
        ? 'trip_leg_return'.tr.toUpperCase()
        : 'trip_leg_outbound'.tr.toUpperCase();
  }

  String _linkedLegLabel() {
    return booking.isReturnLeg
        ? 'trip_leg_outbound'.tr.toUpperCase()
        : 'trip_leg_return'.tr.toUpperCase();
  }

  String _linkedWhen() => booking.linkedLegDatetime ?? '';

  Widget _vehicleLine(ThemeData theme) {
    final title = booking.vehicleBooked?.isNotEmpty == true
        ? booking.vehicleBooked!
        : 'vehicle_booked'.tr;
    final details = [
      if (booking.assignedVehicleLabel?.isNotEmpty == true)
        booking.assignedVehicleLabel!,
      if (booking.vehicleColor?.isNotEmpty == true) booking.vehicleColor!,
      if (booking.vehicleSeats != null)
        '${booking.vehicleSeats} ${'seats'.tr.toLowerCase()}',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(IconsaxPlusLinear.car, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0,
              ),
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                details.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nextActionHint(ThemeData theme) {
    final action = booking.nextAction;
    final (String label, IconData icon) = switch (action) {
      'start' => ('start_now'.tr, IconsaxPlusLinear.play),
      'arrived' => ('mark_arrived'.tr, IconsaxPlusLinear.location_tick),
      'resolve_completed' => ('resolve_trip'.tr, IconsaxPlusLinear.tick_circle),
      'meet_passenger' => ('meet_passenger'.tr, IconsaxPlusLinear.profile_tick),
      'complete' => ('drop_passenger'.tr, IconsaxPlusLinear.arrow_right_3),
      _ => ('open_trip'.tr, IconsaxPlusLinear.arrow_right_3),
    };
    final color = AppColors.forStage(booking.stage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0,
              ),
            ),
          ),
          Icon(IconsaxPlusLinear.arrow_right_3, size: 14, color: color),
        ],
      ),
    );
  }
}
