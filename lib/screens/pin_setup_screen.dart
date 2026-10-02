import 'package:flutter/material.dart';

import '../services/auth_prefs.dart';
import '../services/biometric_service.dart';
import '../widgets/pin_dots.dart';

const _pinLength = 6;

/// Alur: (opsional verifikasi PIN lama) -> isi PIN baru -> ulangi PIN baru.
/// Dipakai untuk setup pertama maupun ganti PIN.
class PinSetupScreen extends StatefulWidget {
  final bool changingExisting;
  const PinSetupScreen({super.key, this.changingExisting = false});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _Step { verifyOld, enterNew, confirmNew }

class _PinSetupScreenState extends State<PinSetupScreen> {
  late _Step _step = widget.changingExisting ? _Step.verifyOld : _Step.enterNew;
  String _pin = '';
  String _firstNew = '';
  bool _error = false;

  String get _title => switch (_step) {
        _Step.verifyOld => 'Masukkan PIN lama',
        _Step.enterNew => 'Buat PIN baru',
        _Step.confirmNew => 'Ulangi PIN baru',
      };

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
    switch (_step) {
      case _Step.verifyOld:
        final ok = await AuthPrefs.verifyPin(_pin);
        if (!mounted) return;
        if (ok) {
          setState(() {
            _step = _Step.enterNew;
            _pin = '';
          });
        } else {
          setState(() {
            _error = true;
            _pin = '';
          });
        }
      case _Step.enterNew:
        setState(() {
          _firstNew = _pin;
          _step = _Step.confirmNew;
          _pin = '';
        });
      case _Step.confirmNew:
        if (_pin == _firstNew) {
          await AuthPrefs.setPin(_pin);
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _error = true;
            _pin = '';
            _step = _Step.enterNew;
            _firstNew = '';
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.changingExisting ? 'Ganti PIN' : 'Buat PIN')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(_title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (_error)
              Text(
                _step == _Step.verifyOld ? 'PIN salah' : 'PIN tidak cocok, ulangi dari awal',
                style: TextStyle(color: Colors.red.shade400),
              )
            else
              Text('PIN terdiri dari $_pinLength angka', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            PinDots(length: _pinLength, filled: _pin.length, error: _error),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: PinKeypad(onDigit: _onDigit),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
