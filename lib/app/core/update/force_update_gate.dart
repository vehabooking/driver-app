import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:upgrader/upgrader.dart';

import '../theme/app_spacing.dart';

/// Blocks the whole app whenever the App Store / Play Store listing carries a
/// newer version than the one installed — no backend involved.
///
/// It sits in `GetMaterialApp.builder`, above the navigator, on purpose: a
/// dialog pushed as a route would be wiped by `Get.offAllNamed` (splash, trip
/// completion) and never come back that session. Up here, route changes can't
/// remove it. The app underneath stays mounted so nothing is lost behind it.
///
/// Re-checks the store every time the app comes back to the foreground, so a
/// driver who opens the store and returns without updating is blocked again.
class ForceUpdateGate extends StatefulWidget {
  const ForceUpdateGate({super.key, required this.child});

  final Widget? child;

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  // Drivers are in Cambodia, but many phones report a US region. Pin the store
  // lookup to KH so it finds the listing whatever the device region says.
  final _upgrader = Upgrader(countryCode: 'KH');

  @override
  void initState() {
    super.initState();
    // A debug build is usually older than the store until it ships — don't
    // lock the developer out of their own app.
    if (!kDebugMode) _upgrader.initialize();
  }

  @override
  void dispose() {
    _upgrader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.child ?? const SizedBox.shrink();
    if (kDebugMode) return app;

    return StreamBuilder<UpgraderState>(
      stream: _upgrader.stateStream,
      builder: (context, _) {
        // Store unreachable (offline, lookup failed) → versionInfo stays null
        // and the driver keeps working. Never block on a failed check.
        final mustUpdate =
            _upgrader.state.versionInfo != null &&
            _upgrader.isUpdateAvailable();

        return Stack(
          children: [
            app,
            if (mustUpdate)
              Positioned.fill(
                child: _UpdateRequiredView(
                  installedVersion: _upgrader.currentInstalledVersion,
                  storeVersion: _upgrader.currentAppStoreVersion,
                  onUpdate: _upgrader.sendUserToAppStore,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _UpdateRequiredView extends StatelessWidget {
  const _UpdateRequiredView({
    required this.installedVersion,
    required this.storeVersion,
    required this.onUpdate,
  });

  final String? installedVersion;
  final String? storeVersion;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                IconsaxPlusLinear.refresh_circle,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'update_required_title'.tr,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'update_required_message'.tr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              if (installedVersion != null && storeVersion != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'update_version_line'.trParams({
                    'current': installedVersion!,
                    'latest': storeVersion!,
                  }),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onUpdate,
                  icon: const Icon(IconsaxPlusLinear.import_1),
                  label: Text('update_now'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
