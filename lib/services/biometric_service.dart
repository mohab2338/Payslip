import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles fingerprint / Face ID authentication and remembers, per device,
/// whether the signed-in user has opted in to biometric unlock.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _biometricEnabledKey = 'biometric_enabled';
  static const _lastEmailKey = 'last_email';

  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck && supported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Confirm it\'s you to continue'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  Future<void> saveLastEmail(String email) async {
    await _storage.write(key: _lastEmailKey, value: email);
  }

  Future<String?> getLastEmail() async {
    return _storage.read(key: _lastEmailKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _biometricEnabledKey);
  }
}
