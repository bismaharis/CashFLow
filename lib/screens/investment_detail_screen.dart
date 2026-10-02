import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/investment.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/tx_tile.dart';
import 'add_transaction_screen.dart';
import 'pocket_form_screen.dart';

/// Detail satu pocket investasi: nilai terkini, untung/rugi, riwayat nilai, setor/tarik.
class InvestmentDetailScreen extends StatefulWidget {
  final int pocketId;
  const InvestmentDetailScreen({super.key, required this.pocketId});

  @override
  State<InvestmentDetailScreen> createState() => _InvestmentDetailScreenState();
}

class _InvestmentDetailScreenState extends State<InvestmentDetailScreen> {
  InvestmentSummary? _s;
  List<Valuation> _vals = [];
  List<TxRecord> _transfers = [];

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
    final inv = await Repo.I.investments();
    final s = inv.where((i) => i.pocket.id == widget.pocketId).firstOrNull;
    if (!mounted) return;
    if (s == null) {
      // Pocket diarsipkan / tidak ditemukan lagi.
      Navigator.of(context).maybePop();
      return;
    }
    final vals = await Repo.I.valuations(widget.pocketId);
    final txs = await Repo.I.transactions(
      filter: TxFilter()
        ..pocketId = widget.pocketId
        ..type = 'transfer',
    );
    if (!mounted) return;
    setState(() {
      _s = s;
      _vals = vals;
      _transfers = txs;
    });
  }

  Future<void> _updateValue(InvestmentSummary s) async {
    final ctl = TextEditingController(text: s.currentValue > 0 ? angka(s.currentValue) : '');
    var date = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Update nilai terkini'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                decoration: const InputDecoration(labelText: 'Nilai sekarang', prefixText: 'Rp '),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(tanggalPendek(date)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setD(() => date = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true || ctl.text.trim().isEmpty) return;

    final now = DateTime.now();
    await Repo.I.addValuation(
      widget.pocketId,
      parseAngka(ctl.text),
      DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second),
    );
  }

  Future<void> _deleteValuation(Valuation v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus catatan nilai?'),
        content: Text('${tanggalPendek(v.date)} • ${rupiah(v.value)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) await Repo.I.deleteValuation(v.id);
  }

  void _transfer({int? fromId, int? toId}) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(initialType: 'transfer', presetFromId: fromId, presetToId: toId),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final color = Color(s.pocket.color);
    final up = s.profit >= 0;
    final profitColor = up ? Colors.green.shade700 : Colors.red.shade700;
    final pct = s.profitPct == null ? '' : ' (${up ? '+' : ''}${s.profitPct!.toStringAsFixed(1)}%)';

    return Scaffold(
      appBar: AppBar(
        title: Text('${s.pocket.emoji} ${s.pocket.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Ubah pocket',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PocketFormScreen(pocket: s.pocket)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            color: color.withOpacity(0.12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nilai terkini'),
                  const SizedBox(height: 4),
                  Text(rupiah(s.currentValue), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  Text(
                    s.lastValuationDate == null
                        ? 'Belum pernah diupdate — nilai dianggap sama dengan modal'
                        : 'Diupdate ${tanggalPendek(s.lastValuationDate!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Modal', style: TextStyle(fontSize: 12)),
                          Text(rupiah(s.modal), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(up ? 'Untung' : 'Rugi', style: const TextStyle(fontSize: 12)),
                          Text(
                            '${up ? '+' : ''}${rupiah(s.profit)}$pct',
                            style: TextStyle(fontWeight: FontWeight.w700, color: profitColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _updateValue(s),
            icon: const Icon(Icons.trending_up),
            label: const Text('Update nilai terkini'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _transfer(toId: widget.pocketId),
                  icon: const Icon(Icons.add),
                  label: const Text('Setor modal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _transfer(fromId: widget.pocketId),
                  icon: const Icon(Icons.remove),
                  label: const Text('Tarik dana'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Riwayat nilai', style: Theme.of(context).textTheme.titleMedium),
          if (_vals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada catatan nilai.'),
            )
          else
            for (var i = 0; i < _vals.length; i++) _valuationTile(i),
          const SizedBox(height: 20),
          Text('Setor & tarik', style: Theme.of(context).textTheme.titleMedium),
          if (_transfers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada setoran atau penarikan.'),
            )
          else
            ..._transfers.map((t) => TxTile(tx: t, onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddTransactionScreen(edit: t)),
                ))),
        ],
      ),
    );
  }

  /// Baris riwayat nilai, dengan selisih terhadap catatan sebelumnya.
  Widget _valuationTile(int i) {
    final v = _vals[i];
    final prev = i + 1 < _vals.length ? _vals[i + 1] : null;
    final delta = prev == null ? null : v.value - prev.value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(rupiah(v.value), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(tanggalPendek(v.date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (delta != null)
            Text(
              '${delta >= 0 ? '+' : ''}${rupiah(delta)}',
              style: TextStyle(color: delta >= 0 ? Colors.green.shade600 : Colors.red.shade600),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Hapus',
            onPressed: () => _deleteValuation(v),
          ),
        ],
      ),
    );
  }
}
