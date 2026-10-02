import 'package:flutter/material.dart';

import '../services/auth_prefs.dart';
import '../services/biometric_service.dart';
import '../widgets/pin_dots.dart';

const _pinLength = 6;

/// Layar kunci PIN. Dipasang sebagai halaman terdepan aplikasi (lihat main.dart),
/// dan memanggil [onUnlocked] begitu PIN benar atau sidik jari berhasil.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _error = false;
  bool _biometricAvailable = false;
  int _failCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final bioOn = await AuthPrefs.isBiometricEnabled();
    final bioReady = bioOn && await BiometricService.isAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = bioReady);
    if (bioReady) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final ok = await BiometricService.authenticate();
    if (ok && mounted) widget.onUnlocked();
  }

  Future<void> _onDigit(String? d) async {
    if (_error) setState(() => _error = false);
    if (d == null) {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= _pinLength) return;
    setState(() => _pin += d);
    if (_pin.length == _pinLength) await _submit();
  }

  Future<void> _submit() async {
    final ok = await AuthPrefs.verifyPin(_pin);
    if (ok) {
      widget.onUnlocked();
      return;
    }
    _failCount++;
    if (!mounted) return;
    setState(() {
      _error = true;
      _pin = '';
    });
    if (_failCount >= 5) {
      // Bukan pengunci akun, hanya jeda singkat supaya tidak bisa dicoba bertubi-tubi.
      setState(() {}); // pastikan indikator error sempat tampil
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _failCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.lock_outline, size: 40),
            const SizedBox(height: 12),
            Text('KeuanganKu Terkunci', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _error ? 'PIN salah, coba lagi' : 'Masukkan PIN',
              style: TextStyle(color: _error ? Colors.red.shade400 : null),
            ),
            const SizedBox(height: 24),
            PinDots(length: _pinLength, filled: _pin.length, error: _error),
            const Spacer(),
            if (_biometricAvailable)
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Gunakan sidik jari'),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: PinKeypad(onDigit: _failCount >= 5 ? (_) {} : _onDigit),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
