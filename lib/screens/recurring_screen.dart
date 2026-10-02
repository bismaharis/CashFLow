import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/recurring.dart';
import '../utils/format.dart';
import '../utils/recurrence.dart';
import 'recurring_form_screen.dart';

const _tipe = {'income': 'Pemasukan', 'expense': 'Pengeluaran', 'transfer': 'Transfer'};

/// Daftar semua template transaksi berulang (aktif di atas, nonaktif di bawah).
class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<RecurringTx> _items = [];

  @override
  void initState() {
    super.initState();
    Repo.I.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    Repo.I.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await Repo.I.recurring();
    if (!mounted) return;
    setState(() => _items = items);
  }

  void _open([RecurringTx? r]) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecurringFormScreen(edit: r)),
      );

  @override
  Widget build(BuildContext context) {
    final active = _items.where((r) => r.active).toList();
    final paused = _items.where((r) => !r.active).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Berulang'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'Baru', onPressed: () => _open()),
        ],
      ),
      body: _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada transaksi berulang.\nCocok untuk gaji, langganan, atau tagihan rutin.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final r in active) _RecurringCard(r: r, onTap: () => _open(r)),
                if (paused.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                    child: Text('Nonaktif', style: Theme.of(context).textTheme.labelLarge),
                  ),
                  for (final r in paused) _RecurringCard(r: r, onTap: () => _open(r)),
                ],
              ],
            ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  final RecurringTx r;
  final VoidCallback onTap;
  const _RecurringCard({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTransfer = r.type == 'transfer';
    final emoji = isTransfer ? '🔁' : (r.categoryEmoji ?? '❔');
    final title = isTransfer ? 'Transfer ke ${r.toPocketName}' : (r.categoryName ?? '-');
    final color = r.type == 'income' ? Colors.green.shade600 : (isTransfer ? null : Colors.red.shade600);
    final sign = r.type == 'income' ? '+' : (isTransfer ? '' : '-');

    return Card(
      child: ListTile(
        onTap: onTap,
        enabled: r.active,
        leading: CircleAvatar(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        title: Text(title),
        subtitle: Text(
          'Setiap ${r.intervalCount} ${freqLabel(r.frequency).toLowerCase()} • '
          '${r.pocketName} • berikutnya ${tanggalPendek(r.nextDueDate)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$sign${rupiah(r.amount)}', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            Switch(
              value: r.active,
              onChanged: (v) => Repo.I.setRecurringActive(r.id!, v),
            ),
          ],
        ),
      ),
    );
  }
}
