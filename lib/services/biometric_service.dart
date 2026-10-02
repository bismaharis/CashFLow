import 'package:local_auth/local_auth.dart';

/// Pembungkus tipis di atas [LocalAuthentication] supaya sisa kode tidak
/// perlu tahu detail paketnya, dan aman dipakai walau perangkat tidak mendukung.
class BiometricService {
  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// true = berhasil, false = gagal/dibatalkan/error (tidak melempar exception).
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Verifikasi untuk membuka KeuanganKu',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
