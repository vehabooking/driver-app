import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/veha_logo_draw.dart';
import 'splash_controller.dart';
import '../../core/config/app_config.dart';

/// First screen on every launch — a quiet brand mark pulses while
/// [SplashController] resolves the driver's next screen.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // White matches the native launch screen for a seamless handoff.
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(0, -0.08),
              child: const VehaLogoMark(height: 112)
                  .animate(
                    onPlay: (animation) => animation.repeat(reverse: true),
                  )
                  .fade(
                    begin: 0.38,
                    end: 1,
                    duration: 900.ms,
                    curve: Curves.easeInOut,
                  )
                  .scaleXY(
                    begin: 0.965,
                    end: 1,
                    duration: 900.ms,
                    curve: Curves.easeInOut,
                  ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Veha Booking Driver',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'version_label'.trParams({'version': AppConfig.appVersion}),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A949F),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
