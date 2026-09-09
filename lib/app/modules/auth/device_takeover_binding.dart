import 'package:get/get.dart';

import 'device_takeover_controller.dart';

class DeviceTakeoverBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DeviceTakeoverController());
  }
}
