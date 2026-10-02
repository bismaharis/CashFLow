import 'package:flutter/material.dart';

import '../services/auth_prefs.dart';
import 'lock_screen.dart';

/// Membungkus seluruh aplikasi. Menampilkan [LockScreen] saat aplikasi baru
/// dibuka, dan saat kembali dari background jika kunci aktif.
class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool _checked = false; // sudah selesai cek status kunci saat startup?
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAtStartup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAtStartup() async {
    final on = await AuthPrefs.isLockEnabled();
    if (!mounted) return;
    setState(() {
      _locked = on;
      _checked = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Ditandai terkunci di sini; layar kunci baru MUNCUL setelah dicek di 'resumed',
      // supaya tidak mengunci hanya karena notifikasi geser turun sebentar.
      AuthPrefs.isLockEnabled().then((on) {
        if (on) _locked = true;
      });
    } else if (state == AppLifecycleState.resumed && _locked) {
      setState(() {}); // paksa build ulang supaya LockScreen tampil
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();
    if (_locked) {
      return LockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return widget.child;
  }
}
