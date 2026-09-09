import 'package:get/get.dart';

import '../../core/utils/external_launcher.dart';
import '../../data/models/guide_video.dart';
import '../../data/models/platform_info.dart';
import '../../data/repositories/guide_repository.dart';
import '../../data/services/settings_service.dart';

class GuideController extends GetxController {
  GuideController(this._guideRepository);

  final GuideRepository _guideRepository;

  final RxBool loadingVideos = false.obs;
  final RxnString videoError = RxnString();
  final RxList<GuideVideo> videos = <GuideVideo>[].obs;
  final RxBool loadingPlatformInfo = false.obs;
  final RxnString platformInfoError = RxnString();
  final Rxn<PlatformInfo> platformInfo = Rxn<PlatformInfo>();

  @override
  void onInit() {
    super.onInit();
    loadVideos();
    loadPlatformInfo();
    // Guide content is translated server-side (Content-Language header), so
    // refetch when the user switches language.
    ever(Get.find<SettingsService>().locale, (_) => loadVideos());
  }

  Future<void> loadVideos() async {
    loadingVideos.value = true;
    videoError.value = null;
    try {
      videos.assignAll(await _guideRepository.videos());
    } catch (e) {
      videoError.value = e.toString();
    } finally {
      loadingVideos.value = false;
    }
  }

  Future<void> openVideo(GuideVideo video) {
    final url = video.url?.isNotEmpty == true ? video.url : video.embedUrl;
    if (url == null || url.isEmpty) return Future.value();
    return ExternalLauncher.openUrl(url);
  }

  Future<void> loadPlatformInfo() async {
    loadingPlatformInfo.value = true;
    platformInfoError.value = null;
    try {
      platformInfo.value = await _guideRepository.platformInfo();
    } catch (e) {
      platformInfoError.value = e.toString();
    } finally {
      loadingPlatformInfo.value = false;
    }
  }

  Future<void> callPhone(String? phone) {
    if (phone == null || phone.isEmpty) return Future.value();
    return ExternalLauncher.call(phone);
  }

  Future<void> email(String? email) {
    if (email == null || email.isEmpty) return Future.value();
    return ExternalLauncher.email(email);
  }

  Future<void> openUrl(String? url) {
    if (url == null || url.isEmpty) return Future.value();
    return ExternalLauncher.openUrl(url);
  }
}
