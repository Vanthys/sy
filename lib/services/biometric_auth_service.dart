import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biometric_auth_service.g.dart';

class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> authenticateForVault() async {
    final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final canAuthenticate =
        canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

    if (!canAuthenticate) {
      return false;
    }

    return _auth.authenticate(
      localizedReason: 'Please authenticate to unlock your Vault',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}

@Riverpod(keepAlive: true)
BiometricAuthService biometricAuthService(Ref ref) {
  return BiometricAuthService();
}
