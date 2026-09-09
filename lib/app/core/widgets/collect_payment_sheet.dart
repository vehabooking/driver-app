import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/booking_payment.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// What the driver confirmed on the drop dialog: the payment method they
/// picked, or null for cash (which is also what the server defaults to).
///
/// The dialog returns null instead when the driver cancels, so `null` result
/// means "nothing ran".
class CollectPaymentResult {
  const CollectPaymentResult({this.paymentMethodId});

  final int? paymentMethodId;
}

/// Runs the work behind the confirm button - record the payment, then complete
/// the trip. Returns null on success (the dialog closes), or a message to show
/// on the still-open dialog.
typedef CollectPaymentConfirm = Future<String?> Function(int? paymentMethodId);

/// The drop confirmation for an **onboard** booking: the same single dialog a
/// plain trip gets, plus the money the driver has to take before the passenger
/// leaves - amount, dispatch note and the payment method.
///
/// Confirming runs [onConfirm] (collect-payment, then complete) behind a
/// spinner; a failure keeps the dialog open with the message so the driver can
/// retry instead of losing the trip in a half-done state.
Future<CollectPaymentResult?> showCollectPaymentDialog({
  required String amountLabel,
  required Future<List<PaymentMethod>> Function() loadMethods,
  required CollectPaymentConfirm onConfirm,
  String? note,
  BuildContext? context,
}) async {
  final host = context ?? Get.context;
  if (host == null) return null;

  return showDialog<CollectPaymentResult>(
    context: host,
    // The driver must choose; a stray tap outside should not skip the money.
    barrierDismissible: false,
    builder: (_) => _CollectPaymentDialog(
      amountLabel: amountLabel,
      note: note,
      loadMethods: loadMethods,
      onConfirm: onConfirm,
    ),
  );
}

class _CollectPaymentDialog extends StatefulWidget {
  const _CollectPaymentDialog({
    required this.amountLabel,
    required this.loadMethods,
    required this.onConfirm,
    this.note,
  });

  final String amountLabel;

  /// Dispatch instruction, when there is one - it can change what the driver
  /// is supposed to take, so it belongs on the confirmation itself.
  final String? note;

  final Future<List<PaymentMethod>> Function() loadMethods;
  final CollectPaymentConfirm onConfirm;

  @override
  State<_CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<_CollectPaymentDialog> {
  static const _accent = AppColors.primary;
  static const _ink = AppColors.secondary;

  List<PaymentMethod> _methods = const [];
  int? _selectedId;
  bool _loadingMethods = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    try {
      final methods = await widget.loadMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _selectedId = _defaultMethodId(methods);
        _loadingMethods = false;
      });
    } catch (_) {
      // A failed lookup must never block the driver: with no id the server
      // records cash, which is what onboard collection almost always is.
      if (!mounted) return;
      setState(() {
        _methods = const [];
        _selectedId = null;
        _loadingMethods = false;
      });
    }
  }

  /// Cash by `code`, else by name, else whatever came first.
  int? _defaultMethodId(List<PaymentMethod> methods) {
    for (final method in methods) {
      if (method.isCash) return method.id;
    }
    return methods.isEmpty ? null : methods.first.id;
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await widget.onConfirm(_selectedId);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(CollectPaymentResult(paymentMethodId: _selectedId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : _ink;
    final note = widget.note?.trim();

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),

      // Everything is centred: a money confirmation reads as one column, and
      // mixing left-aligned copy with a centred figure looked unfinished.
      title: Text(
        'confirm_complete_title'.tr,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: ink,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _label(theme, 'collect_payment_alert'.tr),
            const SizedBox(height: 2),
            Text(
              widget.amountLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: ink,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                height: 1.05,
              ),
            ),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
            if (!_loadingMethods && _methods.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              _label(theme, 'payment_method'.tr),
              const SizedBox(height: AppSpacing.sm),
              _methodPicker(theme),
            ],
            if (_loadingMethods) ...[
              const SizedBox(height: AppSpacing.lg),
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.cancelled,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),

      // Equal-width buttons on one row, so neither reads as an afterthought.
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text('cancel'.tr),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _confirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accent.withValues(alpha: 0.55),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text('confirm'.tr),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Small muted caption above a value or a control.
  Widget _label(ThemeData theme, String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
  );

  /// Method chips, centred. Hidden entirely when the lookup came back empty
  /// or failed - the driver still confirms and the server records cash.
  Widget _methodPicker(ThemeData theme) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final method in _methods)
          ChoiceChip(
            label: Text(method.name),
            selected: _selectedId == method.id,
            onSelected: _busy
                ? null
                : (_) => setState(() => _selectedId = method.id),
            showCheckmark: false,
            backgroundColor: Colors.transparent,
            selectedColor: _accent.withValues(alpha: 0.12),
            side: BorderSide(
              color: _selectedId == method.id
                  ? _accent
                  : theme.colorScheme.outlineVariant,
            ),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _selectedId == method.id
                  ? _accent
                  : theme.colorScheme.onSurfaceVariant,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
