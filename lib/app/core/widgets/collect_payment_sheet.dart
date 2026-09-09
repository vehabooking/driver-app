import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

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
  static const _accent = AppColors.assigned;

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

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg + 2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      title: Text(
        'confirm_complete_title'.tr,
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.onSurface
              : AppColors.secondary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _alert(theme),
            if (widget.note != null && widget.note!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _note(theme, widget.note!.trim()),
            ],
            const SizedBox(height: AppSpacing.lg),
            _methodPicker(theme),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
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
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text('cancel'.tr),
        ),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          style: FilledButton.styleFrom(
            minimumSize: const Size(96, 44),
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _accent.withValues(alpha: 0.55),
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
      ],
    );
  }

  /// Amber "take the money" line with the amount as the loudest thing here.
  Widget _alert(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: _accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                IconsaxPlusBold.money_recive,
                size: 17,
                color: _accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'collect_payment_alert'.tr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (widget.amountLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.amountLabel,
              style: theme.textTheme.displaySmall?.copyWith(
                color: const Color(0xFF8A5A13),
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _note(ThemeData theme, String note) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(IconsaxPlusLinear.note_1, size: 14, color: _accent),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  /// Method chips. Absent entirely when the lookup came back empty or failed -
  /// the driver still confirms and the server records cash.
  Widget _methodPicker(ThemeData theme) {
    if (_loadingMethods) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }
    if (_methods.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'payment_method'.tr,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
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
                selectedColor: _accent.withValues(alpha: 0.16),
                side: BorderSide(
                  color: _selectedId == method.id
                      ? _accent
                      : theme.colorScheme.outlineVariant,
                ),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _selectedId == method.id
                      ? const Color(0xFF8A5A13)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ],
    );
  }
}
