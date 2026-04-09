import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:screen_protector/screen_protector.dart';

part 'screen_protection_service.g.dart';

class ScreenProtectionService {
  Future<void> enable() {
    return ScreenProtector.preventScreenshotOn();
  }

  Future<void> disable() {
    return ScreenProtector.preventScreenshotOff();
  }

  Future<void> resetLockedState() async {
    await enable();
    await disable();
  }
}

@Riverpod(keepAlive: true)
ScreenProtectionService screenProtectionService(Ref ref) {
  return ScreenProtectionService();
}
