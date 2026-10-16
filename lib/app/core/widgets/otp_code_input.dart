import 'dart:async';

import 'package:flutter/foundation.dart';
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
///
/// On Android, switching away to read the SMS dismisses the number pad, but
/// the field often keeps focus. A plain [FocusNode.requestFocus] is then a
/// no-op, so the boxes still look active and the keyboard stays hidden. This
/// widget rebuilds the input connection when the app comes back, and again if
/// the boxes are tapped while the pad is down. iOS already restores the pad,
/// so that path is left alone.
class OtpCodeInput extends StatefulWidget {
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
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput>
    with WidgetsBindingObserver {
  Timer? _reopenTimer;
  bool _focusedBeforeBackground = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_isAndroid) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _reopenTimer?.cancel();
    if (_isAndroid) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAndroid) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (widget.focusNode.hasFocus) _focusedBeforeBackground = true;
      return;
    }
    if (state != AppLifecycleState.resumed || !_focusedBeforeBackground) {
      return;
    }
    _focusedBeforeBackground = false;
    _scheduleReopen();
  }

  void _scheduleReopen() {
    _reopenTimer?.cancel();
    // The activity is not ready to attach an IME in the same frame it resumes.
    _reopenTimer = Timer(const Duration(milliseconds: 280), _reopenKeyboard);
  }

  void _onBoxesTap() {
    if (!widget.enabled) return;
    if (!_isAndroid) {
      widget.focusNode.requestFocus();
      return;
    }
    _reopenTimer?.cancel();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (widget.focusNode.hasFocus && keyboardOpen) return;
    if (widget.focusNode.hasFocus) {
      _reopenKeyboard();
      return;
    }
    widget.focusNode.requestFocus();
    _showImeNextFrame();
  }

  /// Drop the stale connection the OS closed, then focus again so the pad opens.
  void _reopenKeyboard() {
    if (!mounted || !widget.enabled) return;
    final node = widget.focusNode;
    node.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled) return;
      node.requestFocus();
      _showImeNextFrame();
    });
  }

  void _showImeNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled || !widget.focusNode.hasFocus) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = widget.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: Text(
            widget.label ?? 'verification_code'.tr,
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
          onTap: enabled ? _onBoxesTap : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 1,
                height: 1,
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: OtpCodeInput.length,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(OtpCodeInput.length),
                  ],
                  onFieldSubmitted: (_) => widget.onSubmitted(),
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
                      ((constraints.maxWidth -
                                  (AppSpacing.sm * (OtpCodeInput.length - 1))) /
                              OtpCodeInput.length)
                          .clamp(40.0, 48.0);

                  return Obx(() {
                    final value = widget.code.value;
                    final errorText = widget.errorText;
                    final hasError = errorText != null && errorText.isNotEmpty;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(OtpCodeInput.length, (index) {
                        final digit = index < value.length ? value[index] : '';
                        final isActive =
                            index == value.length &&
                            value.length < OtpCodeInput.length;
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
        if (widget.errorText != null && widget.errorText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Text(
              widget.errorText!,
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
