import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan status kunci aplikasi (PIN & sidik jari).
/// PIN TIDAK disimpan sebagai teks biasa, hanya hash + salt-nya.
class AuthPrefs {
  static const _kPinHash = 'pin_hash';
  static const _kPinSalt = 'pin_salt';
  static const _kLockEnabled = 'lock_enabled';
  static const _kBiometricEnabled = 'biometric_enabled';

  static String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _newSalt() {
    final rnd = Random.secure();
    return List.generate(16, (_) => rnd.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<bool> isLockEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kLockEnabled) ?? false;
  }

  static Future<bool> isBiometricEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kBiometricEnabled) ?? false;
  }

  static Future<void> setBiometricEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kBiometricEnabled, v);
  }

  /// Menyalakan kunci dan menyimpan PIN baru (dipakai saat setup pertama atau ganti PIN).
  static Future<void> setPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final salt = _newSalt();
    await p.setString(_kPinSalt, salt);
    await p.setString(_kPinHash, _hash(pin, salt));
    await p.setBool(_kLockEnabled, true);
  }

  /// Mematikan kunci aplikasi. PIN & pengaturan sidik jari ikut dihapus.
  static Future<void> disableLock() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPinHash);
    await p.remove(_kPinSalt);
    await p.setBool(_kLockEnabled, false);
    await p.setBool(_kBiometricEnabled, false);
  }

  static Future<bool> verifyPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final salt = p.getString(_kPinSalt);
    final hash = p.getString(_kPinHash);
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }
}
