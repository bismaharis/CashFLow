import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../models/recurring.dart';
import '../utils/format.dart';
import '../utils/recurrence.dart';

/// Form buat / ubah template transaksi berulang.
class RecurringFormScreen extends StatefulWidget {
  final RecurringTx? edit;
  const RecurringFormScreen({super.key, this.edit});

  @override
  State<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends State<RecurringFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _interval = TextEditingController(text: '1');

  String _type = 'expense';
  String _method = 'cash';
  Freq _freq = Freq.monthly;
  DateTime _start = DateTime.now();
  DateTime? _end;

  List<Pocket> _pockets = [];
  List<TxCategory> _categories = [];
  int? _fromId;
  int? _toId;
  int? _categoryId;

  bool get _editing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _type = e.type;
      _method = e.method ?? 'cash';
      _freq = e.frequency;
      _start = e.startDate;
      _end = e.endDate;
      _fromId = e.pocketId;
      _toId = e.toPocketId;
      _categoryId = e.categoryId;
      _amount.text = angka(e.amount);
      _note.text = e.note;
      _interval.text = '${e.intervalCount}';
    }
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await Repo.I.pockets();
    final c = await Repo.I.categories();
    if (!mounted) return;
    setState(() {
      _pockets = p;
      _categories = c;
      _fixSelection();
    });
  }

  List<Pocket> get _availablePockets =>
      _type == 'transfer' ? _pockets : _pockets.where((p) => !p.isInvestment).toList();

  void _fixSelection() {
    final ids = _availablePockets.map((p) => p.id).toList();
    if (!ids.contains(_fromId)) _fromId = ids.isEmpty ? null : ids.first;
    if (_type == 'transfer') {
      if (!ids.contains(_toId) || _toId == _fromId) {
        _toId = ids.firstWhere((id) => id != _fromId, orElse: () => null);
      }
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : (_end ?? _start.add(const Duration(days: 365))),
      firstDate: isStart ? DateTime(2000) : _start,
      lastDate: DateTime(now.year + 20),
    );
    if (d == null) return;
    setState(() => isStart ? _start = d : _end = d);
  }

  Future<void> _save() async {
    final amount = parseAngka(_amount.text);
    final interval = int.tryParse(_interval.text) ?? 0;
    if (amount <= 0) return _snack('Nominal harus lebih dari 0');
    if (interval <= 0) return _snack('Pengulangan harus minimal 1');
    if (_fromId == null) return _snack('Pilih pocket');
    if (_type == 'transfer') {
      if (_toId == null || _toId == _fromId) return _snack('Pilih pocket tujuan yang berbeda');
    } else if (_categoryId == null) {
      return _snack('Pilih kategori');
    }
    if (_end != null && !_end!.isAfter(_start)) return _snack('Tanggal berakhir harus setelah tanggal mulai');

    // Saat mengubah, next_due_date lama dipertahankan kalau masih di masa depan,
    // supaya jadwal yang sudah berjalan tidak mendadak mundur/maju.
    final nextDue = (_editing && widget.edit!.nextDueDate.isAfter(DateTime.now())) ? widget.edit!.nextDueDate : _start;

    await Repo.I.saveRecurring(RecurringTx(
      id: widget.edit?.id,
      type: _type,
      amount: amount,
      pocketId: _fromId!,
      toPocketId: _type == 'transfer' ? _toId : null,
      categoryId: _type == 'transfer' ? null : _categoryId,
      method: _type == 'transfer' ? null : _method,
      note: _note.text.trim(),
      frequency: _freq,
      intervalCount: interval,
      startDate: _start,
      endDate: _end,
      nextDueDate: nextDue,
      active: widget.edit?.active ?? true,
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi berulang ini?'),
        content: const Text('Transaksi yang sudah tercatat sebelumnya tidak ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await Repo.I.deleteRecurring(widget.edit!.id!);
    if (mounted) Navigator.pop(context);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isTransfer = _type == 'transfer';
    final cats = _categories.where((c) => c.type == _type).toList();
    final pockets = _availablePockets;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Ubah Transaksi Berulang' : 'Transaksi Berulang Baru'),
        actions: [
          if (_editing) IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Hapus', onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Keluar')),
              ButtonSegment(value: 'income', label: Text('Masuk')),
              ButtonSegment(value: 'transfer', label: Text('Transfer')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null;
              _fixSelection();
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _fromId,
            decoration: InputDecoration(
              labelText: isTransfer ? 'Dari pocket' : 'Pocket',
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final p in pockets) DropdownMenuItem(value: p.id, child: Text('${p.emoji} ${p.name}')),
            ],
            onChanged: (v) => setState(() {
              _fromId = v;
              _fixSelection();
            }),
          ),
          if (isTransfer) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _toId,
              decoration: const InputDecoration(labelText: 'Ke pocket', border: OutlineInputBorder()),
              items: [
                for (final p in pockets.where((p) => p.id != _fromId))
                  DropdownMenuItem(value: p.id, child: Text('${p.emoji} ${p.name}')),
              ],
              onChanged: (v) => setState(() => _toId = v),
            ),
          ],
          if (!isTransfer) ...[
            const SizedBox(height: 16),
            const Text('Kategori'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in cats)
                  ChoiceChip(
                    label: Text('${c.emoji} ${c.name}'),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Metode'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: 'card', label: Text('Card'), icon: Icon(Icons.credit_card)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Pengulangan', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Setiap'),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<Freq>(
                  value: _freq,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: [for (final f in Freq.values) DropdownMenuItem(value: f, child: Text(freqLabel(f)))],
                  onChanged: (v) => setState(() => _freq = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Mulai'),
            subtitle: Text(tanggalPanjang(_start)),
            onTap: () => _pickDate(isStart: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy),
            title: const Text('Berakhir'),
            subtitle: Text(_end == null ? 'Tidak ada tanggal akhir' : tanggalPanjang(_end!)),
            trailing: _end == null
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _end = null)),
            onTap: () => _pickDate(isStart: false),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(_editing ? 'Simpan perubahan' : 'Simpan')),
        ],
      ),
    );
  }
}
