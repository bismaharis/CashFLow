import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../services/backup_prefs.dart';
import 'add_transaction_screen.dart';
import 'dashboard_screen.dart';
import 'pockets_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'transactions_screen.dart';

/// Kerangka utama: 4 tab + tombol "Catat".
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _runRecurring();
      await _checkBackupReminder();
    });
  }

  Future<void> _runRecurring() async {
    final created = await Repo.I.runDueRecurring();
    if (created > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$created transaksi berulang otomatis tercatat')),
      );
    }
  }

  Future<void> _checkBackupReminder() async {
    final hasData = (await Repo.I.transactions(limit: 1)).isNotEmpty;
    if (!hasData) return;
    if (!await BackupPrefs.shouldRemind(days: 30)) return;
    if (!mounted) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Waktunya backup'),
        content: const Text(
          'Sudah lebih dari 30 hari sejak backup terakhir. '
          'Simpan cadangan data supaya aman jika HP hilang atau rusak.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nanti')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Backup sekarang')),
        ],
      ),
    );

    await BackupPrefs.snoozeReminder();
    if (go == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen(startBackup: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          TransactionsScreen(),
          StatsScreen(),
          PocketsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transaksi'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Statistik'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Pocket'),
        ],
      ),
    );
  }
}
