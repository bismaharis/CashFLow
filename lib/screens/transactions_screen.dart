import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/tx_tile.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  final TxFilter _filter = TxFilter();

  List<TxRecord> _items = [];
  List<Pocket> _pockets = [];
  List<TxCategory> _categories = [];
  bool _searching = false;
  int _req = 0; // penanda agar hasil query lama tidak menimpa yang baru

  @override
  void initState() {
    super.initState();
    Repo.I.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    Repo.I.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_req;
    final items = await Repo.I.transactions(filter: _filter);
    final pockets = await Repo.I.pockets(includeArchived: true);
    final cats = await Repo.I.categories();
    if (!mounted || id != _req) return;
    setState(() {
      _items = items;
      _pockets = pockets;
      _categories = cats;
    });
  }

  void _toggleSearch() {
    if (_searching) {
      _search.clear();
      _filter.query = '';
      setState(() => _searching = false);
      _load();
    } else {
      setState(() => _searching = true);
    }
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<TxFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _filter, pockets: _pockets, categories: _categories),
    );
    if (result == null) return;
    _filter
      ..type = result.type
      ..pocketId = result.pocketId
      ..categoryId = result.categoryId
      ..method = result.method
      ..from = result.from
      ..to = result.to;
    setState(() {});
    _load();
  }

  Future<void> _confirmDelete(TxRecord t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text('${t.categoryName ?? 'Transfer'} • ${rupiah(t.amount)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) await Repo.I.deleteTransaction(t.id!);
  }

  void _edit(TxRecord t) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddTransactionScreen(edit: t)),
      );

  @override
  Widget build(BuildContext context) {
    final income = _items.where((t) => t.type == 'income').fold<int>(0, (s, t) => s + t.amount);
    final expense = _items.where((t) => t.type == 'expense').fold<int>(0, (s, t) => s + t.amount);

    final children = <Widget>[];
    String? lastDay;
    for (final t in _items) {
      final day = tanggalPanjang(t.date);
      if (day != lastDay) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(day, style: Theme.of(context).textTheme.labelLarge),
        ));
        lastDay = day;
      }
      children.add(TxTile(tx: t, onTap: () => _edit(t), onLongPress: () => _confirmDelete(t)));
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Cari catatan / kategori', border: InputBorder.none),
                onChanged: (v) {
                  _filter.query = v;
                  _load();
                },
              )
            : const Text('Transaksi'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: 'Cari',
            onPressed: _toggleSearch,
          ),
          IconButton(
            tooltip: 'Filter',
            icon: Badge(
              isLabelVisible: _filter.activeCount > 0,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _openFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filter.isActive)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${_items.length} transaksi  •  Masuk ${rupiah(income)}  •  Keluar ${rupiah(expense)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: _items.isEmpty
                ? Center(child: Text(_filter.isActive ? 'Tidak ada transaksi yang cocok' : 'Belum ada transaksi'))
                : ListView(padding: const EdgeInsets.only(bottom: 96), children: children),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet berisi pilihan filter. Mengembalikan TxFilter baru saat "Terapkan".
class _FilterSheet extends StatefulWidget {
  final TxFilter initial;
  final List<Pocket> pockets;
  final List<TxCategory> categories;

  const _FilterSheet({required this.initial, required this.pockets, required this.categories});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TxFilter f = widget.initial.copy();

  bool _same(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: f.from != null && f.to != null ? DateTimeRange(start: f.from!, end: f.to!) : null,
    );
    if (r != null) setState(() {
      f.from = r.start;
      f.to = r.end;
    });
  }

  Widget _section(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: chips),
          ],
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ranges = <String, (DateTime, DateTime)>{
      'Bulan ini': (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0)),
      'Bulan lalu': (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0)),
      '3 bulan': (DateTime(now.year, now.month - 2, 1), DateTime(now.year, now.month + 1, 0)),
      'Tahun ini': (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31)),
    };
    final isPreset = ranges.values.any((r) => _same(f.from, r.$1) && _same(f.to, r.$2));
    final expenseCats = widget.categories.where((c) => c.type == 'expense');
    final incomeCats = widget.categories.where((c) => c.type == 'income');

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Periode', [
              _chip('Semua', f.from == null && f.to == null, () => setState(() {
                    f.from = null;
                    f.to = null;
                  })),
              for (final e in ranges.entries)
                _chip(e.key, _same(f.from, e.value.$1) && _same(f.to, e.value.$2), () => setState(() {
                      f.from = e.value.$1;
                      f.to = e.value.$2;
                    })),
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(f.from != null && f.to != null && !isPreset
                    ? '${tanggalPendek(f.from!)} – ${tanggalPendek(f.to!)}'
                    : 'Pilih tanggal'),
                onPressed: _pickRange,
              ),
            ]),
            _section('Tipe', [
              _chip('Semua', f.type == null, () => setState(() => f.type = null)),
              _chip('Masuk', f.type == 'income', () => setState(() => f.type = 'income')),
              _chip('Keluar', f.type == 'expense', () => setState(() => f.type = 'expense')),
              _chip('Transfer', f.type == 'transfer', () => setState(() => f.type = 'transfer')),
            ]),
            _section('Metode', [
              _chip('Semua', f.method == null, () => setState(() => f.method = null)),
              _chip('Cash', f.method == 'cash', () => setState(() => f.method = 'cash')),
              _chip('Card', f.method == 'card', () => setState(() => f.method = 'card')),
            ]),
            _section('Pocket', [
              _chip('Semua', f.pocketId == null, () => setState(() => f.pocketId = null)),
              for (final p in widget.pockets)
                _chip('${p.emoji} ${p.name}', f.pocketId == p.id, () => setState(() => f.pocketId = p.id)),
            ]),
            _section('Kategori pengeluaran', [
              _chip('Semua', f.categoryId == null, () => setState(() => f.categoryId = null)),
              for (final c in expenseCats)
                _chip('${c.emoji} ${c.name}', f.categoryId == c.id, () => setState(() => f.categoryId = c.id)),
            ]),
            _section('Kategori pemasukan', [
              for (final c in incomeCats)
                _chip('${c.emoji} ${c.name}', f.categoryId == c.id, () => setState(() => f.categoryId = c.id)),
            ]),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      final q = f.query;
                      f = TxFilter()..query = q;
                    }),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: () => Navigator.pop(context, f), child: const Text('Terapkan')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
