import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/profile_image_processor.dart';
import '../../data/models/auth_user.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/settings_service.dart';
import '../home/home_controller.dart';

class ProfileController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final SettingsService settings = Get.find<SettingsService>();
  final ImagePicker _picker = ImagePicker();

  final formKey = GlobalKey<FormState>();
  late final TextEditingController firstNameCtrl;
  late final TextEditingController lastNameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController currentAddressCtrl;

  /// 'male' | 'female' | null.
  final gender = RxnString();

  /// Selected date of birth, null when unset.
  final dateOfBirth = Rxn<DateTime>();

  final isSaving = false.obs;

  /// Whether the inline edit form is expanded.
  final isEditing = false.obs;

  /// Local path of a newly picked photo, before it's uploaded. Drives the
  /// preview + the "Save photo" button.
  final pickedPhotoPath = RxnString();
  final isProcessingPhoto = false.obs;
  final isUploadingPhoto = false.obs;

  AuthUser? get user => _auth.currentUser.value;

  /// Full name, falling back to first + last when the API `name` is empty.
  String get displayName {
    final u = user;
    return u?.displayName ?? '—';
  }

  @override
  void onInit() {
    super.onInit();
    final u = user;
    firstNameCtrl = TextEditingController(text: u?.firstName ?? '');
    lastNameCtrl = TextEditingController(text: u?.lastName ?? '');
    phoneCtrl = TextEditingController(text: u?.phone ?? '');
    emailCtrl = TextEditingController(text: u?.email ?? '');
    currentAddressCtrl = TextEditingController(text: u?.currentAddress ?? '');
    _resetExtraFields();
  }

  void startEdit() => isEditing.value = true;

  /// Restore gender + date-of-birth from the saved user.
  void _resetExtraFields() {
    final u = user;
    gender.value = u?.gender;
    dateOfBirth.value = _parseDate(u?.dateOfBirth);
  }

  static DateTime? _parseDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    return DateTime.tryParse(iso.trim());
  }

  void setGender(String value) => gender.value = value;

  /// Open an iOS-style wheel picker for date of birth (drivers are 18+).
  Future<void> pickDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final minimumDate = DateTime(1940);
    final maximumDate = DateTime(now.year - 18, now.month, now.day);
    var selected = dateOfBirth.value ?? DateTime(now.year - 25, 1, 1);

    if (selected.isBefore(minimumDate)) selected = minimumDate;
    if (selected.isAfter(maximumDate)) selected = maximumDate;

    final theme = Theme.of(context);
    await showCupertinoModalPopup<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: theme.brightness,
          primaryColor: theme.colorScheme.primary,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                SizedBox(
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: Text('cancel'.tr),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            onPressed: () {
                              dateOfBirth.value = selected;
                              Navigator.of(sheetContext).pop();
                            },
                            child: Text(
                              'done'.tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IgnorePointer(
                        child: Text(
                          'date_of_birth'.tr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.55,
                  ),
                ),
                SizedBox(
                  height: 230,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: selected,
                    minimumDate: minimumDate,
                    maximumDate: maximumDate,
                    minimumYear: minimumDate.year,
                    maximumYear: maximumDate.year,
                    itemExtent: 40,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Collapse the form and restore fields to the saved values.
  void cancelEdit() {
    final u = user;
    firstNameCtrl.text = u?.firstName ?? '';
    lastNameCtrl.text = u?.lastName ?? '';
    phoneCtrl.text = u?.phone ?? '';
    emailCtrl.text = u?.email ?? '';
    currentAddressCtrl.text = u?.currentAddress ?? '';
    _resetExtraFields();
    isEditing.value = false;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    isSaving.value = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final dob = dateOfBirth.value;
      await _auth.updateProfile(
        firstName: firstNameCtrl.text.trim(),
        lastName: lastNameCtrl.text.trim(),
        gender: gender.value,
        dateOfBirth: dob == null ? null : DateFormat('yyyy-MM-dd').format(dob),
        currentAddress: currentAddressCtrl.text.trim(),
      );
      isEditing.value = false;
      AppSnackbar.success('profile_updated'.tr);
    } on ApiException catch (e) {
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    } finally {
      isSaving.value = false;
    }
  }

  // ---- Photo ---------------------------------------------------------------

  Future<bool> pickPhoto(ImageSource source) async {
    if (isProcessingPhoto.value || isUploadingPhoto.value) return false;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (picked == null) return false;

      isProcessingPhoto.value = true;
      final prepared = await prepareProfileImage(picked.path);
      await _deletePreparedPhoto();
      pickedPhotoPath.value = prepared.path;
      return true;
    } on ProfileImageProcessingException {
      AppSnackbar.error('photo_processing_failed'.tr);
    } on PlatformException {
      AppSnackbar.error('photo_picker_failed'.tr);
    } catch (_) {
      AppSnackbar.error('photo_processing_failed'.tr);
    } finally {
      isProcessingPhoto.value = false;
    }
    return false;
  }

  Future<void> discardPhoto() => _deletePreparedPhoto();

  Future<bool> savePhoto() async {
    final path = pickedPhotoPath.value;
    if (path == null || isUploadingPhoto.value) return false;

    isUploadingPhoto.value = true;
    try {
      await _auth.uploadAvatar(path);
      await _deletePreparedPhoto();
      AppSnackbar.success('photo_updated'.tr);
      return true;
    } on ApiException catch (e) {
      AppSnackbar.error(e.message);
    } catch (_) {
      AppSnackbar.error('error_generic'.tr);
    } finally {
      isUploadingPhoto.value = false;
    }
    return false;
  }

  Future<void> _deletePreparedPhoto() async {
    final path = pickedPhotoPath.value;
    pickedPhotoPath.value = null;
    if (path == null || !path.contains('veha_profile_')) return;

    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Picker cache cleanup is best-effort and must not block the profile.
    }
  }

  void openDocuments() => Get.toNamed(Routes.documents);

  /// Jump to the Guide tab.
  void openGuide() => Get.find<HomeController>().changeTab(2);

  /// Open the public privacy policy in an in-app browser sheet.
  Future<void> openPrivacyPolicy() async {
    final opened = await launchUrl(
      Uri.parse(AppConstants.privacyPolicyUrl),
      mode: LaunchMode.inAppBrowserView,
    );
    if (!opened) AppSnackbar.error('privacy_policy_open_failed'.tr);
  }

  Future<void> logout() async {
    await _auth.logout();
    Get.offAllNamed(Routes.login);
  }

  @override
  void onClose() {
    unawaited(_deletePreparedPhoto());
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    currentAddressCtrl.dispose();
    super.onClose();
  }
}
