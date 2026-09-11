import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../data/models/place.dart';
import '../location/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_ink.dart';

class TripRouteMap extends StatefulWidget {
  const TripRouteMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.activeTarget,
    required this.activeLabel,
    required this.navigateToDropoff,
    required this.canNavigate,
    required this.isLocating,
    required this.onRefreshLocation,
    required this.onNavigate,
    this.driverLocation,
    this.locationMessage,
    this.distanceLabel,
  });

  final Place pickup;
  final Place dropoff;
  final Place activeTarget;
  final String activeLabel;
  final bool navigateToDropoff;
  final bool canNavigate;
  final bool isLocating;
  final DriverLocation? driverLocation;
  final String? locationMessage;
  final String? distanceLabel;
  final VoidCallback onRefreshLocation;
  final VoidCallback onNavigate;

  @override
  State<TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends State<TripRouteMap> {
  GoogleMapController? _mapController;

  @override
  void didUpdateWidget(covariant TripRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapController != null && _shouldRefit(oldWidget)) {
      unawaited(_fitCamera());
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRoute =
        widget.pickup.hasCoordinates && widget.dropoff.hasCoordinates;

    if (!hasRoute) {
      return _FallbackRoutePreview(
        pickup: widget.pickup,
        dropoff: widget.dropoff,
        activeTarget: widget.activeTarget,
        activeLabel: widget.activeLabel,
        distanceLabel: widget.distanceLabel,
        canNavigate: widget.canNavigate,
        onNavigate: widget.onNavigate,
      );
    }

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialTarget(),
                zoom: 12,
              ),
              markers: _markers(theme),
              polylines: _polylines(),
              myLocationButtonEnabled: false,
              myLocationEnabled: widget.driverLocation != null,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                unawaited(_fitCamera());
              },
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: _MapHeader(
              activeLabel: widget.activeLabel,
              activeTarget: widget.activeTarget,
              distanceLabel: _activeDistanceLabel() ?? widget.distanceLabel,
              isLocating: widget.isLocating,
              onRefreshLocation: widget.onRefreshLocation,
            ),
          ),
          if (widget.locationMessage != null && widget.driverLocation == null)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: 76,
              child: _LocationNotice(message: widget.locationMessage!),
            ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _MapFooter(
              pickup: widget.pickup,
              dropoff: widget.dropoff,
              canNavigate: widget.canNavigate,
              navigateToDropoff: widget.navigateToDropoff,
              onNavigate: widget.onNavigate,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldRefit(TripRouteMap oldWidget) {
    return oldWidget.driverLocation?.latitude !=
            widget.driverLocation?.latitude ||
        oldWidget.driverLocation?.longitude !=
            widget.driverLocation?.longitude ||
        oldWidget.pickup.latitude != widget.pickup.latitude ||
        oldWidget.pickup.longitude != widget.pickup.longitude ||
        oldWidget.dropoff.latitude != widget.dropoff.latitude ||
        oldWidget.dropoff.longitude != widget.dropoff.longitude ||
        oldWidget.activeTarget.latitude != widget.activeTarget.latitude ||
        oldWidget.activeTarget.longitude != widget.activeTarget.longitude;
  }

  LatLng _initialTarget() {
    if (widget.driverLocation != null) {
      return LatLng(
        widget.driverLocation!.latitude,
        widget.driverLocation!.longitude,
      );
    }

    if (widget.activeTarget.hasCoordinates) {
      return LatLng(
        widget.activeTarget.latitude!,
        widget.activeTarget.longitude!,
      );
    }

    return LatLng(widget.pickup.latitude!, widget.pickup.longitude!);
  }

  Set<Marker> _markers(ThemeData theme) {
    final markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickup.latitude!, widget.pickup.longitude!),
        infoWindow: InfoWindow(
          title: 'pickup'.tr,
          snippet: widget.pickup.label,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(widget.dropoff.latitude!, widget.dropoff.longitude!),
        infoWindow: InfoWindow(
          title: 'dropoff'.tr,
          snippet: widget.dropoff.label,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    final driver = widget.driverLocation;
    if (driver != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driver.latitude, driver.longitude),
          infoWindow: InfoWindow(title: 'driver_location'.tr),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _polylines() {
    final mutedRoute = Polyline(
      polylineId: const PolylineId('booking_route'),
      points: [
        LatLng(widget.pickup.latitude!, widget.pickup.longitude!),
        LatLng(widget.dropoff.latitude!, widget.dropoff.longitude!),
      ],
      color: AppColors.secondary.withValues(alpha: 0.28),
      width: 4,
      patterns: [PatternItem.dash(16), PatternItem.gap(8)],
    );

    final activeStart = widget.driverLocation == null
        ? LatLng(widget.pickup.latitude!, widget.pickup.longitude!)
        : LatLng(
            widget.driverLocation!.latitude,
            widget.driverLocation!.longitude,
          );
    final activeEnd = widget.activeTarget.hasCoordinates
        ? LatLng(widget.activeTarget.latitude!, widget.activeTarget.longitude!)
        : LatLng(widget.dropoff.latitude!, widget.dropoff.longitude!);

    final activeRoute = Polyline(
      polylineId: const PolylineId('active_route'),
      points: [activeStart, activeEnd],
      color: AppColors.primary,
      width: 6,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    return {mutedRoute, activeRoute};
  }

  Future<void> _fitCamera() async {
    final controller = _mapController;
    if (controller == null) return;

    final points = <LatLng>[
      LatLng(widget.pickup.latitude!, widget.pickup.longitude!),
      LatLng(widget.dropoff.latitude!, widget.dropoff.longitude!),
      if (widget.driverLocation != null)
        LatLng(
          widget.driverLocation!.latitude,
          widget.driverLocation!.longitude,
        ),
    ];

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 14),
        ),
      );
      return;
    }

    final bounds = _boundsFor(points);
    if (_isTinyBounds(bounds)) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 15),
        ),
      );
      return;
    }

    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 58));
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  bool _isTinyBounds(LatLngBounds bounds) {
    return (bounds.northeast.latitude - bounds.southwest.latitude).abs() <
            0.0005 &&
        (bounds.northeast.longitude - bounds.southwest.longitude).abs() <
            0.0005;
  }

  String? _activeDistanceLabel() {
    final driver = widget.driverLocation;
    if (driver == null || !widget.activeTarget.hasCoordinates) return null;

    final meters = _distanceMeters(
      driver.latitude,
      driver.longitude,
      widget.activeTarget.latitude!,
      widget.activeTarget.longitude!,
    );

    final distance = meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';

    return widget.navigateToDropoff
        ? '$distance ${'to_dropoff'.tr}'
        : '$distance ${'to_pickup'.tr}';
  }

  double _distanceMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degreesToRadians(endLat - startLat);
    final dLng = _degreesToRadians(endLng - startLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(startLat)) *
            math.cos(_degreesToRadians(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.activeLabel,
    required this.activeTarget,
    required this.isLocating,
    required this.onRefreshLocation,
    this.distanceLabel,
  });

  final String activeLabel;
  final Place activeTarget;
  final String? distanceLabel;
  final bool isLocating;
  final VoidCallback onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      IconsaxPlusBold.routing,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          activeTarget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        if (distanceLabel != null)
                          Text(
                            distanceLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLocating ? null : onRefreshLocation,
            child: SizedBox(
              width: 46,
              height: 46,
              child: isLocating
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      IconsaxPlusLinear.gps,
                      size: 20,
                      color: Theme.of(context).ink,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapFooter extends StatelessWidget {
  const _MapFooter({
    required this.pickup,
    required this.dropoff,
    required this.canNavigate,
    required this.navigateToDropoff,
    required this.onNavigate,
  });

  final Place pickup;
  final Place dropoff;
  final bool canNavigate;
  final bool navigateToDropoff;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: _CompactStop(
                icon: IconsaxPlusLinear.location,
                label: 'pickup'.tr,
                value: pickup.label,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _CompactStop(
                icon: IconsaxPlusLinear.flag,
                label: 'dropoff'.tr,
                value: dropoff.label,
              ),
            ),
            if (canNavigate) ...[
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onNavigate,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(
                      navigateToDropoff
                          ? IconsaxPlusLinear.arrow_right_3
                          : IconsaxPlusLinear.routing,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactStop extends StatelessWidget {
  const _CompactStop({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 15),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            const Icon(
              IconsaxPlusLinear.info_circle,
              color: AppColors.assigned,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackRoutePreview extends StatelessWidget {
  const _FallbackRoutePreview({
    required this.pickup,
    required this.dropoff,
    required this.activeTarget,
    required this.activeLabel,
    required this.canNavigate,
    required this.onNavigate,
    this.distanceLabel,
  });

  final Place pickup;
  final Place dropoff;
  final Place activeTarget;
  final String activeLabel;
  final String? distanceLabel;
  final bool canNavigate;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RoutePreviewPainter(
                color: AppColors.primary,
                secondaryColor: AppColors.secondary,
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: _MapHeader(
              activeLabel: activeLabel,
              activeTarget: activeTarget,
              distanceLabel: distanceLabel,
              isLocating: false,
              onRefreshLocation: () {},
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _MapFooter(
              pickup: pickup,
              dropoff: dropoff,
              canNavigate: canNavigate,
              navigateToDropoff: false,
              onNavigate: onNavigate,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  const _RoutePreviewPainter({
    required this.color,
    required this.secondaryColor,
  });

  final Color color;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    for (var x = -size.width; x < size.width * 2; x += 34) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x + size.height * 0.7, size.height),
        gridPaint,
      );
    }

    final routePaint = Paint()
      ..color = color.withValues(alpha: 0.70)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.70)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.30,
        size.width * 0.62,
        size.height * 0.84,
        size.width * 0.82,
        size.height * 0.34,
      );
    canvas.drawPath(route, routePaint);

    final markerPaint = Paint()..color = Colors.white;
    final markerBorder = Paint()
      ..color = secondaryColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final points = [
      Offset(size.width * 0.18, size.height * 0.70),
      Offset(size.width * 0.82, size.height * 0.34),
    ];
    for (final point in points) {
      canvas.drawCircle(point, 12, markerPaint);
      canvas.drawCircle(point, 12, markerBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
