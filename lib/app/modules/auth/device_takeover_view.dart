import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/otp_code_input.dart';
import 'device_takeover_controller.dart';

/// OTP step of the "use this phone instead" flow. Mirrors the forgot-password
/// verify step so the two code screens feel like one.
class DeviceTakeoverView extends GetView<DeviceTakeoverController> {
  const DeviceTakeoverView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? scheme.surface : AppColors.canvas,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topGap = (constraints.maxHeight * 0.18).clamp(
                AppSpacing.xxxl,
                150.0,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppBackButton(onPressed: controller.goBack),
                      ),
                      SizedBox(height: topGap),
                      _brand(),
                      const SizedBox(height: AppSpacing.xl),
                      _headline(theme, scheme),
                      const SizedBox(height: AppSpacing.xl),
                      _form(theme, scheme),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _brand() => Column(
    children: [
      Image.asset(
        'assets/branding/app_icon.png',
        height: 74,
      ).animate().fadeIn(duration: 420.ms).scale(begin: const Offset(0.9, 0.9)),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'VEHA BOOKING',
        style: GoogleFonts.kantumruyPro(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.7,
          color: AppColors.secondary,
        ),
      ).animate().fadeIn(delay: 160.ms, duration: 420.ms),
    ],
  );

  Widget _headline(ThemeData theme, ColorScheme scheme) => Column(
    children: [
      Text(
        'takeover_screen_title'.tr,
        textAlign: TextAlign.center,
        style: GoogleFonts.fraunces(
          fontSize: 30,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'takeover_screen_subtitle'.tr,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      Obx(() {
        if (controller.destinationMasked.value.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: _destinationChip(theme, scheme),
        );
      }),
    ],
  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08);

  Widget _destinationChip(ThemeData theme, ColorScheme scheme) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          controller.viaEmail.value
              ? Icons.email_outlined
              : IconsaxPlusLinear.call,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'code_sent_to'.trParams({
              'destination': controller.destinationMasked.value,
            }),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _form(ThemeData theme, ColorScheme scheme) => Form(
    key: controller.formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => OtpCodeInput(
            controller: controller.otpCtrl,
            focusNode: controller.otpFocusNode,
            code: controller.otpCode,
            onSubmitted: controller.verify,
            errorText: controller.otpError.value,
            enabled: !controller.isLoading.value,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Obx(() => _expiryLine(theme, scheme)),
        const SizedBox(height: AppSpacing.xs),
        Obx(() => _resendRow(theme, scheme)),
        const SizedBox(height: AppSpacing.lg),
        _submitButton(theme),
      ],
    ),
  );

  Widget _expiryLine(ThemeData theme, ColorScheme scheme) {
    final expired = controller.isExpired;
    final color = expired ? scheme.error : scheme.onSurfaceVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(IconsaxPlusLinear.timer_1, size: 15, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          expired
              ? 'code_expired'.tr
              : 'code_expires_in'.trParams({
                  'time': controller.expiresLabel,
                }),
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: expired ? FontWeight.w700 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _resendRow(ThemeData theme, ColorScheme scheme) {
    final cooldown = controller.cooldownRemaining.value;
    final resending = controller.isResending.value;
    final canResend = controller.canResend;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'did_not_receive_code'.tr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: canResend ? controller.resend : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: resending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  cooldown > 0
                      ? 'resend_in'.trParams({'seconds': cooldown.toString()})
                      : 'resend_code'.tr,
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _submitButton(ThemeData theme) => Obx(() {
    final loading = controller.isLoading.value;
    final enabled = !loading && controller.canVerify.value;

    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.34),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      onPressed: enabled ? controller.verify : null,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'takeover_verify'.tr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(IconsaxPlusLinear.arrow_right_3, size: 20),
              ],
            ),
    );
  });
}
