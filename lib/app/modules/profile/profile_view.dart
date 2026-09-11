import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/section_label.dart';
import 'profile_controller.dart';
import '../../core/theme/app_ink.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canvas = isDark ? theme.colorScheme.surface : AppColors.canvas;

    return Scaffold(
      backgroundColor: canvas,
      body: Container(
        decoration: BoxDecoration(color: canvas),
        // Without this the scroll viewport starts at y=0 and the cards ride
        // up under the status bar as the page scrolls.
        child: SafeArea(
          bottom: false,
          child: Form(
            key: controller.formKey,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.navClearance),
              children: [
                _CoverHeader(controller: controller),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageH,
                    0,
                    AppSpacing.pageH,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Collapsible identity / edit block (card-less, centered).
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Obx(() {
                            final editing = controller.isEditing.value;
                            return AnimatedSize(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.04),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: editing
                                    ? _EditForm(
                                        key: const ValueKey('edit'),
                                        controller: controller,
                                      )
                                    : _Identity(
                                        key: const ValueKey('identity'),
                                        controller: controller,
                                      ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      SectionLabel('documents'.tr),
                      const SizedBox(height: AppSpacing.md),
                      _NavRow(
                        icon: IconsaxPlusLinear.personalcard,
                        title: 'my_documents'.tr,
                        subtitle: 'documents_subtitle'.tr,
                        onTap: controller.openDocuments,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      SectionLabel('support'.tr),
                      const SizedBox(height: AppSpacing.md),
                      _NavRow(
                        icon: IconsaxPlusLinear.book_1,
                        title: 'help_and_guide'.tr,
                        onTap: controller.openGuide,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      _CompactPrefs(controller: controller),
                      const SizedBox(height: AppSpacing.xl),

                      OutlinedButton.icon(
                        onPressed: () async {
                          if (await confirmSignOut()) {
                            await controller.logout();
                          }
                        },
                        icon: const Icon(IconsaxPlusLinear.logout, size: 18),
                        label: Text('sign_out'.tr),
                        style: OutlinedButton.styleFrom(
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: Text(
                          'version_label'.trParams({
                            'version': AppConfig.appVersion,
                          }),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12.5,
                            color: theme.colorScheme.outline,
                          ),
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
    );
  }
}

/// Soft teal cover (gradient from top-right) + centered avatar + name.
class _CoverHeader extends StatelessWidget {
  const _CoverHeader({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final coverHeight = topInset + 88;
    const avatarRadius = 52.0;

    return Column(
      children: [
        SizedBox(
          // Leave a deliberate breathing gap below the portrait so the name
          // never appears attached to the avatar ring or camera action.
          height: coverHeight + avatarRadius + AppSpacing.sm,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // No band — the page's radial brand wash shows through, so the
              // header matches the home page. This just reserves the space
              // the avatar overlaps into.
              SizedBox(height: coverHeight, width: double.infinity),
              Positioned(
                top: coverHeight - avatarRadius,
                left: 0,
                right: 0,
                child: Center(
                  child: _AvatarCircle(
                    controller: controller,
                    radius: avatarRadius,
                  ),
                ),
              ),
            ],
          ),
        ),
        Obx(
          () => Text(
            controller.displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

/// Collapsed view: phone, email + an Edit button.
class _Identity extends StatelessWidget {
  const _Identity({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = controller.user;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.lg,
            runSpacing: 6,
            children: [
              if (user?.phone != null && user!.phone!.isNotEmpty)
                _contact(
                  context,
                  icon: IconsaxPlusLinear.call,
                  value: user.phone!,
                ),
              if (user?.email != null && user!.email!.isNotEmpty)
                _contact(
                  context,
                  icon: IconsaxPlusLinear.sms,
                  value: user.email!,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: controller.startEdit,
            icon: const Icon(IconsaxPlusLinear.edit_2, size: 14),
            label: Text('edit_profile'.tr),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 6,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _contact(
    BuildContext context, {
    required IconData icon,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.inkMuted(0.72),
          ),
        ),
      ],
    );
  }
}

/// Expanded inline edit form.
class _EditForm extends StatelessWidget {
  const _EditForm({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // First + last name share a row.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                context,
                label: 'first_name'.tr,
                ctrl: controller.firstNameCtrl,
                icon: IconsaxPlusLinear.profile,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'first_name_required'.tr
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _field(
                context,
                label: 'last_name'.tr,
                ctrl: controller.lastNameCtrl,
                icon: IconsaxPlusLinear.profile,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'last_name_required'.tr
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _dateField(context),
        const SizedBox(height: AppSpacing.sm),
        _genderField(context),
        const SizedBox(height: AppSpacing.sm),
        _field(
          context,
          label: 'phone'.tr,
          ctrl: controller.phoneCtrl,
          icon: IconsaxPlusLinear.call,
          readOnly: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        _field(
          context,
          label: 'email'.tr,
          ctrl: controller.emailCtrl,
          icon: IconsaxPlusLinear.sms,
          readOnly: true,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                IconsaxPlusLinear.lock_1,
                size: 13,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'login_contacts_locked'.tr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _field(
          context,
          label: 'current_address'.tr,
          ctrl: controller.currentAddressCtrl,
          icon: IconsaxPlusLinear.location,
          hint: 'current_address_hint'.tr,
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.newline,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),

        // Compact action row.
        Row(
          children: [
            Expanded(
              child: Obx(
                () => FilledButton(
                  onPressed: controller.isSaving.value ? null : controller.save,
                  style: _btnStyle,
                  child: controller.isSaving.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('save_changes'.tr),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: controller.cancelEdit,
              style: _cancelStyle,
              child: Text('cancel'.tr),
            ),
          ],
        ),
      ],
    );
  }

  static final ButtonStyle _btnStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
  );

  static final ButtonStyle _cancelStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.primary.withValues(alpha: 0.10),
    foregroundColor: AppColors.primary,
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
  );

  /// Compact labeled field: a small caption label above a dense filled input.
  Widget _field(
    BuildContext context, {
    required String label,
    required TextEditingController ctrl,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    bool autocorrect = true,
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final fieldFill = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42)
        : Colors.white;

    return _labeled(
      context,
      label: label,
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autocorrect: autocorrect,
        maxLines: maxLines,
        readOnly: readOnly,
        showCursor: !readOnly,
        enableInteractiveSelection: !readOnly,
        validator: validator,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: fieldFill,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          prefixIcon: Padding(
            // Top-align the icon when the field grows to multiple lines.
            padding: EdgeInsets.only(
              bottom: maxLines > 1 ? (maxLines - 1) * 19.0 : 0,
            ),
            child: Icon(icon, size: 19),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 0,
          ),
          suffixIcon: readOnly
              ? Icon(
                  IconsaxPlusLinear.lock_1,
                  size: 16,
                  color: theme.colorScheme.outline,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.72),
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  /// A modern tappable date-of-birth tile: a tinted calendar badge, the chosen
  /// date (or placeholder), and a chevron — opens the native picker.
  Widget _dateField(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42)
        : Colors.white;

    return _labeled(
      context,
      label: 'date_of_birth'.tr,
      child: Obx(() {
        final dob = controller.dateOfBirth.value;
        final hasValue = dob != null;
        final text = hasValue
            ? DateFormat('dd MMM yyyy').format(dob)
            : 'select_date'.tr;
        return Material(
          color: tileColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InkWell(
            onTap: () => controller.pickDateOfBirth(context),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(
                      IconsaxPlusLinear.calendar_1,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        color: hasValue
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: hasValue
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(
                    IconsaxPlusLinear.arrow_down_1,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  /// A compact Male / Female tab control with icons and a sliding active pill.
  Widget _genderField(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.76);

    return _labeled(
      context,
      label: 'gender'.tr,
      child: Obx(() {
        final selected = controller.gender.value;
        Widget tab(String value, String label, IconData icon) {
          final active = selected == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => controller.setGender(value),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                height: 36,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.26)
                        : Colors.transparent,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: active
                          ? AppColors.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: active
                            ? AppColors.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              tab('male', 'male'.tr, Icons.male_rounded),
              const SizedBox(width: 4),
              tab('female', 'female'.tr, Icons.female_rounded),
            ],
          ),
        );
      }),
    );
  }

  /// Small caption label above an arbitrary input control.
  Widget _labeled(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 5),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.controller, required this.radius});

  final ProfileController controller;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = controller.user;
      final picked = controller.pickedPhotoPath.value;
      final rawUrl = user?.imageUrl?.trim();
      final url = rawUrl == null || rawUrl.isEmpty
          ? null
          : AppConfig.resolveBackendAssetUrl(rawUrl);
      final isBusy =
          controller.isProcessingPhoto.value ||
          controller.isUploadingPhoto.value;

      ImageProvider? image;
      if (picked != null) {
        image = FileImage(File(picked));
      } else if (url != null) {
        image = NetworkImage(url);
      }

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: radius - 4,
              // Solid soft tint = primary blended into white (clean, opaque,
              // independent of whatever sits behind the avatar).
              backgroundColor: Color.alphaBlend(
                AppColors.primary.withValues(alpha: 0.12),
                Colors.white,
              ),
              backgroundImage: image,
              child: image == null
                  ? Text(
                      _initials(user?.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: isBusy ? null : () => _pickSheet(context),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isBusy
                      ? AppColors.primary.withValues(alpha: 0.48)
                      : AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        IconsaxPlusLinear.camera,
                        size: 16,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _pickSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(IconsaxPlusLinear.camera),
              title: Text('take_photo'.tr),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.gallery),
              title: Text('choose_gallery'.tr),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !context.mounted) return;
    final prepared = await controller.pickPhoto(source);
    if (!prepared || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (sheetContext) => _PhotoConfirmationSheet(
        controller: controller,
        onSaved: () => Navigator.of(sheetContext).pop(),
        onCancel: () async {
          await controller.discardPhoto();
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        },
      ),
    );

    // Covers route changes or other programmatic sheet dismissal.
    if (controller.pickedPhotoPath.value != null &&
        !controller.isUploadingPhoto.value) {
      await controller.discardPhoto();
    }
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class _PhotoConfirmationSheet extends StatelessWidget {
  const _PhotoConfirmationSheet({
    required this.controller,
    required this.onSaved,
    required this.onCancel,
  });

  final ProfileController controller;
  final VoidCallback onSaved;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'update_profile_photo'.tr,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'review_photo_hint'.tr,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14.5,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Obx(() {
              final path = controller.pickedPhotoPath.value;
              return Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  backgroundImage: path == null
                      ? null
                      : FileImage(File(path)) as ImageProvider,
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    IconsaxPlusLinear.tick_circle,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'photo_ready_status'.tr,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Obx(() {
              final uploading = controller.isUploadingPhoto.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            if (await controller.savePhoto()) onSaved();
                          },
                    icon: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(IconsaxPlusLinear.export_1, size: 19),
                    label: Text(
                      uploading ? 'uploading_photo'.tr : 'save_photo'.tr,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: uploading ? null : onCancel,
                    child: Text('cancel'.tr),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Tappable settings row card.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: softCardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13.5,
                  color: theme.inkMuted(0.66),
                ),
              ),
        trailing: Icon(
          IconsaxPlusLinear.arrow_right_3,
          size: 18,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

/// Small, low-emphasis language + theme controls.
class _CompactPrefs extends StatelessWidget {
  const _CompactPrefs({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = SegmentedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

    Widget row(IconData icon, String label, Widget control) => Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.inkMuted(0.74),
          ),
        ),
        const Spacer(),
        control,
      ],
    );

    return Container(
      decoration: softCardDecoration(context),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          row(
            IconsaxPlusLinear.global,
            'language'.tr,
            Obx(
              () => SegmentedButton<String>(
                style: small,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'en', label: Text('EN')),
                  ButtonSegment(value: 'km', label: Text('ខ្មែរ')),
                ],
                selected: {controller.settings.isKhmer ? 'km' : 'en'},
                onSelectionChanged: (_) => controller.settings.toggleLanguage(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1),
          ),
          row(
            IconsaxPlusLinear.moon,
            'theme'.tr,
            Obx(
              () => SegmentedButton<ThemeMode>(
                style: small,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(IconsaxPlusLinear.setting_2, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(IconsaxPlusLinear.sun_1, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(IconsaxPlusLinear.moon, size: 16),
                  ),
                ],
                selected: {controller.settings.themeMode.value},
                onSelectionChanged: (s) =>
                    controller.settings.setThemeMode(s.first),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
