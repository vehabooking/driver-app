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
import 'forgot_password_controller.dart';

class ForgotPasswordView extends GetView<ForgotPasswordController> {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? scheme.surface : AppColors.canvas,
        body: Stack(
          children: [
            SafeArea(
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
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Obx(
                              () =>
                                  controller.step.value ==
                                      ForgotPasswordStep.reset
                                  ? const SizedBox.square(dimension: 46)
                                  : AppBackButton(onPressed: controller.goBack),
                            ),
                          ),
                          SizedBox(height: topGap),
                          _brand(),
                          const SizedBox(height: AppSpacing.xl),
                          Obx(() => _headline(theme, scheme)),
                          const SizedBox(height: AppSpacing.xl),
                          Obx(() => _stepForm(theme, scheme)),
                          const SizedBox(height: AppSpacing.xxxl),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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

  Widget _headline(ThemeData theme, ColorScheme scheme) {
    final step = controller.step.value;
    final title = switch (step) {
      ForgotPasswordStep.request => 'forgot_password_title'.tr,
      ForgotPasswordStep.verify => 'verify_code_title'.tr,
      ForgotPasswordStep.reset => 'set_new_password_title'.tr,
    };
    final subtitle = switch (step) {
      ForgotPasswordStep.request => 'forgot_password_subtitle'.tr,
      ForgotPasswordStep.verify => 'verify_code_subtitle'.tr,
      ForgotPasswordStep.reset => 'set_new_password_subtitle'.tr,
    };

    return Column(
      children: [
        Text(
          title,
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
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        if (step == ForgotPasswordStep.verify &&
            controller.maskedDestination.value.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _maskedDestinationChip(theme, scheme),
        ],
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08);
  }

  Widget _maskedDestinationChip(ThemeData theme, ColorScheme scheme) {
    final isEmail =
        controller.identifierMode.value == ResetIdentifierMode.email;

    return Container(
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
            isEmail ? Icons.email_outlined : IconsaxPlusLinear.call,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              'code_sent_to'.trParams({
                'destination': controller.maskedDestination.value,
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
  }

  Widget _stepForm(ThemeData theme, ColorScheme scheme) {
    switch (controller.step.value) {
      case ForgotPasswordStep.request:
        return Form(
          key: controller.requestFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _identifierModeSelector(theme, scheme),
              const SizedBox(height: AppSpacing.lg),
              _field(
                theme,
                label: 'reset_identifier_label'.tr,
                child: Obx(() {
                  final isEmail =
                      controller.identifierMode.value ==
                      ResetIdentifierMode.email;

                  return TextFormField(
                    controller: controller.identifierCtrl,
                    keyboardType: isEmail
                        ? TextInputType.emailAddress
                        : TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: [
                      isEmail
                          ? AutofillHints.email
                          : AutofillHints.telephoneNumber,
                    ],
                    onFieldSubmitted: (_) => controller.requestCode(),
                    decoration: InputDecoration(
                      hintText: isEmail
                          ? 'reset_email_hint'.tr
                          : 'reset_phone_hint'.tr,
                      prefixIcon: Icon(
                        isEmail ? Icons.email_outlined : IconsaxPlusLinear.call,
                        size: 20,
                      ),
                    ),
                    validator: (value) {
                      final identifier = value?.trim() ?? '';

                      if (identifier.isEmpty) {
                        return 'login_field_required'.tr;
                      }

                      if (isEmail && !GetUtils.isEmail(identifier)) {
                        return 'email_invalid'.tr;
                      }

                      if (!isEmail &&
                          identifier.replaceAll(RegExp(r'\D+'), '').length <
                              6) {
                        return 'phone_invalid'.tr;
                      }

                      return null;
                    },
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              _submitButton(
                theme,
                'send_code'.tr,
                controller.requestCode,
                isEnabled: () => controller.canRequestCode.value,
              ),
            ],
          ),
        );
      case ForgotPasswordStep.verify:
        return Form(
          key: controller.verifyFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OtpCodeInput(
                controller: controller.otpCtrl,
                focusNode: controller.otpFocusNode,
                code: controller.otpCode,
                onSubmitted: controller.verifyCode,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'did_not_receive_code'.tr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: controller.resendCode,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('resend_code'.tr),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _submitButton(
                theme,
                'verify_code'.tr,
                controller.verifyCode,
                isEnabled: () => controller.canVerifyCode.value,
              ),
            ],
          ),
        );
      case ForgotPasswordStep.reset:
        return Form(
          key: controller.resetFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                theme,
                label: 'new_password'.tr,
                child: Obx(
                  () => TextFormField(
                    controller: controller.passwordCtrl,
                    obscureText: controller.obscurePassword.value,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'password_hint'.tr,
                      errorText: controller.passwordError.value,
                      prefixIcon: const Icon(IconsaxPlusLinear.lock, size: 20),
                      suffixIcon: IconButton(
                        onPressed: controller.togglePassword,
                        icon: Icon(
                          controller.obscurePassword.value
                              ? IconsaxPlusLinear.eye_slash
                              : IconsaxPlusLinear.eye,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final password = value ?? '';

                      if (password.isEmpty) {
                        return 'password_required'.tr;
                      }

                      if (password.length <
                          controller.minPasswordLength.value) {
                        return 'password_min_length'.trParams({
                          'count': controller.minPasswordLength.value
                              .toString(),
                        });
                      }

                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                theme,
                label: 'confirm_password'.tr,
                child: Obx(
                  () => TextFormField(
                    controller: controller.confirmPasswordCtrl,
                    obscureText: controller.obscureConfirmPassword.value,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => controller.savePassword(),
                    decoration: InputDecoration(
                      hintText: 'confirm_password_hint'.tr,
                      errorText: controller.confirmPasswordError.value,
                      prefixIcon: const Icon(IconsaxPlusLinear.lock, size: 20),
                      suffixIcon: IconButton(
                        onPressed: controller.toggleConfirmPassword,
                        icon: Icon(
                          controller.obscureConfirmPassword.value
                              ? IconsaxPlusLinear.eye_slash
                              : IconsaxPlusLinear.eye,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return 'password_required'.tr;
                      if (value != controller.passwordCtrl.text) {
                        return 'passwords_do_not_match'.tr;
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _submitButton(
                theme,
                'save_new_password'.tr,
                controller.savePassword,
                isEnabled: () => controller.canSavePassword.value,
              ),
            ],
          ),
        );
    }
  }

  Widget _submitButton(
    ThemeData theme,
    String label,
    Future<void> Function() onPressed, {
    bool Function()? isEnabled,
  }) => Obx(() {
    final enabled = !controller.isLoading.value && (isEnabled?.call() ?? true);

    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.34),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      onPressed: enabled ? onPressed : null,
      child: controller.isLoading.value
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
                Text(label),
                const SizedBox(width: AppSpacing.sm),
                const Icon(IconsaxPlusLinear.arrow_right_3, size: 20),
              ],
            ),
    );
  });

  Widget _identifierModeSelector(ThemeData theme, ColorScheme scheme) =>
      Obx(() {
        final selected = controller.identifierMode.value;

        return Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Row(
            children: [
              _identifierModeOption(
                theme,
                label: 'reset_via_phone'.tr,
                icon: IconsaxPlusLinear.call,
                mode: ResetIdentifierMode.phone,
                selected: selected,
              ),
              const SizedBox(width: AppSpacing.xs),
              _identifierModeOption(
                theme,
                label: 'reset_via_email'.tr,
                icon: Icons.email_outlined,
                mode: ResetIdentifierMode.email,
                selected: selected,
              ),
            ],
          ),
        );
      });

  Widget _identifierModeOption(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required ResetIdentifierMode mode,
    required ResetIdentifierMode selected,
  }) {
    final isSelected = mode == selected;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.28)
                : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: () => controller.setIdentifierMode(mode),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? AppColors.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    ThemeData theme, {
    required String label,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.86),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.96),
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.72,
                ),
                letterSpacing: 0.2,
              ),
              prefixIconColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return AppColors.primary;
                }

                return AppColors.secondary.withValues(alpha: 0.62);
              }),
              suffixIconColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return AppColors.primary;
                }

                return AppColors.secondary.withValues(alpha: 0.62);
              }),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.46,
                  ),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.6,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                borderSide: BorderSide(color: theme.colorScheme.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                borderSide: BorderSide(color: theme.colorScheme.error),
              ),
            ),
          ),
          child: child,
        ),
      ),
    ],
  );
}
