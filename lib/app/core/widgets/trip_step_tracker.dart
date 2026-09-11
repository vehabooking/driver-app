import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_ink.dart';

/// Horizontal 4-step trip tracker: Start -> Arrived -> Meet -> Drop.
///
/// Reached steps show a filled teal disc; steps still ahead are drawn as a
/// bare icon with no ring. Dashed connectors join them.
///
/// Shared by the dashboard NOW card, the bookings list card and the trip
/// detail footer. Those three used to carry private copies of this, which is
/// why a single styling change had to be made three times.
class TripStepTracker extends StatelessWidget {
  const TripStepTracker({
    super.key,
    required this.stage,
    this.driverTripStatus,
    this.compact = false,
  });

  /// Booking stage as reported by the API.
  final String stage;

  /// Driver-reported trip status when the caller has one. Takes precedence
  /// over [stage] when resolving which step is current.
  final String? driverTripStatus;

  /// Slightly smaller markers, used by the trip detail footer.
  final bool compact;

  static const _steps = [
    (label: 'step_short_start', icon: IconsaxPlusBold.car),
    (label: 'step_short_arrived', icon: IconsaxPlusLinear.flag),
    (label: 'step_short_meet', icon: IconsaxPlusLinear.profile),
    (label: 'step_short_drop', icon: IconsaxPlusLinear.location),
  ];

  String get _effectiveStage => driverTripStatus ?? stage;

  int get _stepIndex => switch (_effectiveStage) {
    'start' => 0,
    'arrived_location' => 1,
    'meet_passenger' => 2,
    'drop_passenger' || 'completed' => 3,
    _ => -1,
  };

  bool get _isCompleted =>
      stage == 'completed' || _effectiveStage == 'drop_passenger';

  @override
  Widget build(BuildContext context) {
    final markerSize = compact ? 30.0 : 32.0;
    final iconSize = compact ? 17.0 : 18.0;
    final connectorTop = compact ? 14.0 : 15.0;

    final activeIndex = _stepIndex;
    final completed = _isCompleted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: _Step(
              label: _steps[i].label.tr,
              icon: _steps[i].icon,
              active: !completed && i == activeIndex,
              done: completed || i < activeIndex,
              markerSize: markerSize,
              iconSize: iconSize,
            ),
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: _Connector(
                done: completed || i < activeIndex,
                top: connectorTop,
              ),
            ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.icon,
    required this.active,
    required this.done,
    required this.markerSize,
    required this.iconSize,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool done;
  final double markerSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = active || done;

    // Reached steps keep the filled teal disc - it is what marks "you are
    // here". Steps still ahead are a bare icon: no ring, no fill. The marker
    // box is sized the same either way so the connectors stay aligned.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markerSize,
          height: markerSize,
          alignment: Alignment.center,
          decoration: isPrimary
              ? const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                )
              : null,
          child: Icon(
            done ? IconsaxPlusLinear.tick_circle : icon,
            size: iconSize,
            color: isPrimary ? Colors.white : theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isPrimary ? AppColors.primary : theme.ink,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.done, required this.top});

  final bool done;
  final double top;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.primary.withValues(alpha: 0.70)
        : const Color(0xFFC8D3D1);

    return Padding(
      padding: EdgeInsets.only(top: top),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashCount = (constraints.maxWidth / 8).floor().clamp(2, 16);

          return Row(
            children: List.generate(dashCount, (index) {
              return Expanded(
                child: Container(
                  height: 2,
                  margin: EdgeInsets.only(
                    right: index == dashCount - 1 ? 0 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
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
