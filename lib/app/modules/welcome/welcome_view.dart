import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/i18n/app_translations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'welcome_controller.dart';
import '../../core/theme/app_ink.dart';

/// First-run welcome screen. Uses the designed travel artwork as the stage and
/// keeps the interactive layer intentionally small: language, brand, headline,
/// and the continue action.
class WelcomeView extends GetView<WelcomeController> {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final topOffset = size.height < 760 ? AppSpacing.md : AppSpacing.xl;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvas,
        body: _WelcomeScene(
          topOffset: topOffset,
          compact: size.height < 760,
          langToggle: _langToggle(context),
          controller: controller,
        ),
      ),
    );
  }

  Widget _langToggle(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final isKm = controller.settings.isKhmer;

      Widget segment(String label, bool active, VoidCallback onTap) {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: active
                    ? Colors.white
                    : theme.inkMuted(0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            segment(
              'EN',
              !isKm,
              () => controller.setLanguage(AppTranslations.englishLocale),
            ),
            segment(
              'ខ្មែរ',
              isKm,
              () => controller.setLanguage(AppTranslations.khmerLocale),
            ),
          ],
        ),
      );
    });
  }
}

class _WelcomeScene extends StatelessWidget {
  const _WelcomeScene({
    required this.topOffset,
    required this.compact,
    required this.langToggle,
    required this.controller,
  });

  final double topOffset;
  final bool compact;
  final Widget langToggle;
  final WelcomeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/branding/welcome_screen.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: langToggle,
                ).animate().fadeIn(duration: 350.ms),
                SizedBox(height: topOffset),
                Image.asset(
                      'assets/branding/welcome_lockup.png',
                      height: compact ? 92 : 112,
                    )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.94, 0.94),
                      curve: Curves.easeOutCubic,
                    ),
                SizedBox(height: compact ? AppSpacing.sm : 14),
                _BrandTitle(compact: compact)
                    .animate()
                    .fadeIn(delay: 160.ms, duration: 450.ms)
                    .slideY(begin: 0.12),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 52,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ).animate().fadeIn(delay: 260.ms).scaleX(begin: 0.25),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Text(
                    'welcome_tagline_1'.tr,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.inkMuted(0.72),
                      fontWeight: FontWeight.w600,
                      height: 1.38,
                      letterSpacing: 0,
                    ),
                  ),
                ).animate().fadeIn(delay: 340.ms),
                const Spacer(),
                SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: controller.start,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusLg,
                            ),
                          ),
                          elevation: 10,
                          shadowColor: AppColors.primary.withValues(
                            alpha: 0.28,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('welcome_cta'.tr),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(
                                  IconsaxPlusLinear.arrow_right_3,
                                  size: 19,
                                )
                                .animate(
                                  onPlay: (controller) =>
                                      controller.repeat(reverse: true),
                                )
                                .moveX(
                                  begin: -1,
                                  end: 4,
                                  duration: 700.ms,
                                  curve: Curves.easeInOut,
                                ),
                          ],
                        ),
                      ),
                    )
                    .animate(
                      onPlay: (controller) =>
                          controller.repeat(period: 3600.ms),
                    )
                    .shimmer(
                      delay: 1700.ms,
                      duration: 1000.ms,
                      color: Colors.white.withValues(alpha: 0.36),
                    )
                    .animate()
                    .fadeIn(delay: 520.ms, duration: 450.ms)
                    .slideY(begin: 0.24),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final introStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.ink,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    );
    final titleStyle = GoogleFonts.fraunces(
      fontSize: compact ? 46 : 54,
      height: 0.98,
      fontWeight: FontWeight.w700,
      color: theme.ink,
      letterSpacing: 0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'welcome_intro'.tr,
          style: introStyle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: titleStyle,
            children: [
              const TextSpan(text: 'Veha '),
              TextSpan(
                text: 'Driver',
                style: titleStyle.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
