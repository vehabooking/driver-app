import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Six-digit one-time-code entry: a hidden text field drives six display
/// boxes, so the system keyboard (and SMS autofill) works while the UI shows
/// one digit per box.
///
/// [code] mirrors [controller]'s text; the owning controller keeps it in sync
/// so the boxes can rebuild reactively without a listener of their own.
class OtpCodeInput extends StatelessWidget {
  const OtpCodeInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.code,
    required this.onSubmitted,
    this.label,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final RxString code;
  final VoidCallback onSubmitted;

  /// Caption above the boxes. Defaults to the `verification_code` string.
  final String? label;

  /// Inline error under the boxes (e.g. a rejected code).
  final String? errorText;
  final bool enabled;

  static const int length = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: Text(
            label ?? 'verification_code'.tr,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? focusNode.requestFocus : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 1,
                height: 1,
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: length,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(length),
                  ],
                  onFieldSubmitted: (_) => onSubmitted(),
                  showCursor: false,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isCollapsed: true,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final boxSize =
                      ((constraints.maxWidth - (AppSpacing.sm * (length - 1))) /
                              length)
                          .clamp(40.0, 48.0);

                  return Obx(() {
                    final value = code.value;
                    final hasError = errorText != null && errorText!.isNotEmpty;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(length, (index) {
                        final digit = index < value.length ? value[index] : '';
                        final isActive =
                            index == value.length && value.length < length;
                        final isFilled = digit.isNotEmpty;
                        final borderColor = hasError
                            ? scheme.error
                            : isActive || isFilled
                            ? AppColors.primary
                            : scheme.outlineVariant.withValues(alpha: 0.62);

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          width: boxSize,
                          height: boxSize + AppSpacing.sm,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                            border: Border.all(
                              color: borderColor,
                              width: isActive ? 1.8 : 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(
                                  alpha: isFilled ? 0.10 : 0.05,
                                ),
                                blurRadius: isFilled ? 20 : 14,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Text(
                            digit,
                            style: GoogleFonts.fraunces(
                              fontSize: 22,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        );
                      }),
                    );
                  });
                },
              ),
            ],
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
