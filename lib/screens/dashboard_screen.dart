import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/investment.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/tx_tile.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Pocket> _pockets = [];
  List<InvestmentSummary> _inv = [];
  List<TxRecord> _recent = [];
  int _income = 0;
  int _expense = 0;

  @override
  void initState() {
    super.initState();
    Repo.I.addListener(_load); // refresh otomatis saat data berubah
    _load();
  }

  @override
  void dispose() {
    Repo.I.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final pockets = await Repo.I.pockets();
    final recent = await Repo.I.transactions(limit: 5);
    final totals = await Repo.I.monthTotals(DateTime.now());
    final inv = await Repo.I.investments();
    if (!mounted) return;
    setState(() {
      _pockets = pockets;
      _inv = inv;
      _recent = recent;
      _income = totals.income;
      _expense = totals.expense;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uangPocket = _pockets.where((p) => !p.isInvestment).fold<int>(0, (s, p) => s + p.balance);
    // Investasi dihitung dari NILAI TERKINI (bukan modal).
    final investasi = _inv.fold<int>(0, (s, i) => s + i.currentValue);
    final untung = _inv.fold<int>(0, (s, i) => s + i.profit);
    final persen = _income == 0 ? null : (_expense * 100 / _income);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KeuanganKu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Uang Pocket', style: TextStyle(color: cs.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text(
                      rupiah(uangPocket),
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tidak termasuk investasi',
                      style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withOpacity(0.7)),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _mini('Investasi (${untung >= 0 ? '+' : ''}${rupiah(untung)})', rupiah(investasi), cs.onPrimaryContainer),
                        _mini('Total Kekayaan', rupiah(uangPocket + investasi), cs.onPrimaryContainer),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bulan ini', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _flow(Icons.arrow_downward, 'Pemasukan', _income, Colors.green.shade600)),
                        Expanded(child: _flow(Icons.arrow_upward, 'Pengeluaran', _expense, Colors.red.shade600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: persen == null ? 0 : (persen / 100).clamp(0.0, 1.0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      persen == null
                          ? 'Belum ada pemasukan bulan ini'
                          : 'Pengeluaran ${persen.toStringAsFixed(0)}% dari pemasukan',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Transaksi terbaru', style: Theme.of(context).textTheme.titleMedium),
            if (_recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Belum ada transaksi. Tekan "Catat" untuk mulai.')),
              )
            else
              ..._recent.map((t) => TxTile(tx: t)),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      );

  Widget _flow(IconData icon, String label, int value, Color color) => Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: color.withOpacity(0.15), child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text(rupiah(value), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      );
}
