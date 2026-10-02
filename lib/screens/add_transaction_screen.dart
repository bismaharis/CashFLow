import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../utils/format.dart';

/// Form catat pemasukan / pengeluaran / transfer antar pocket.
/// Jika [edit] diisi, form berubah menjadi mode ubah transaksi.
class AddTransactionScreen extends StatefulWidget {
  final TxRecord? edit;

  /// Opsional: untuk pintasan (mis. tombol Setor/Tarik di halaman investasi).
  final String? initialType;
  final int? presetFromId;
  final int? presetToId;

  const AddTransactionScreen({
    super.key,
    this.edit,
    this.initialType,
    this.presetFromId,
    this.presetToId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  String _type = 'expense';
  String _method = 'cash';
  DateTime _date = DateTime.now();

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
      _date = e.date;
      _fromId = e.pocketId;
      _toId = e.toPocketId;
      _categoryId = e.categoryId;
      _amount.text = angka(e.amount);
      _note.text = e.note;
    } else {
      _type = widget.initialType ?? 'expense';
      _fromId = widget.presetFromId;
      _toId = widget.presetToId;
    }
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Saat mengubah transaksi lama, pocket yang sudah diarsipkan tetap harus muncul.
    final p = await Repo.I.pockets(includeArchived: _editing);
    final c = await Repo.I.categories();
    if (!mounted) return;
    setState(() {
      _pockets = p;
      _categories = c;
      _fixSelection();
    });
  }

  /// Pocket untuk pemasukan/pengeluaran hanya yang bertipe biasa.
  /// Transfer boleh ke/dari pocket investasi.
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

  Future<void> _addCategory() async {
    final name = TextEditingController();
    final emoji = TextEditingController(text: '🏷️');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategori baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emoji, decoration: const InputDecoration(labelText: 'Emoji')),
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama kategori'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final id = await Repo.I.addCategory(TxCategory(
      name: name.text.trim(),
      emoji: emoji.text.trim().isEmpty ? '🏷️' : emoji.text.trim(),
      type: _type,
    ));
    final c = await Repo.I.categories();
    if (!mounted) return;
    setState(() {
      _categories = c;
      _categoryId = id;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final amount = parseAngka(_amount.text);
    if (amount <= 0) return _snack('Nominal harus lebih dari 0');
    if (_fromId == null) return _snack('Pilih pocket');
    if (_type == 'transfer') {
      if (_toId == null || _toId == _fromId) return _snack('Pilih pocket tujuan yang berbeda');
    } else if (_categoryId == null) {
      return _snack('Pilih kategori');
    }

    // Jam tetap dipertahankan supaya urutan transaksi di hari yang sama tidak berubah.
    final base = widget.edit?.date ?? DateTime.now();
    final when = DateTime(_date.year, _date.month, _date.day, base.hour, base.minute, base.second);

    final tx = TxRecord(
      id: widget.edit?.id,
      type: _type,
      amount: amount,
      date: when,
      pocketId: _fromId!,
      toPocketId: _type == 'transfer' ? _toId : null,
      categoryId: _type == 'transfer' ? null : _categoryId,
      method: _type == 'transfer' ? null : _method,
      note: _note.text.trim(),
    );

    if (_editing) {
      await Repo.I.updateTransaction(tx);
    } else {
      await Repo.I.addTransaction(tx);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await Repo.I.deleteTransaction(widget.edit!.id!);
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
        title: Text(_editing ? 'Ubah Transaksi' : 'Catat Transaksi'),
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
            // Tipe tidak bisa diganti saat mengubah transaksi (hapus lalu buat baru jika perlu).
            onSelectionChanged: _editing
                ? null
                : (s) => setState(() {
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
              for (final p in pockets)
                DropdownMenuItem(value: p.id, child: Text('${p.emoji} ${p.name}  •  ${rupiah(p.balance)}')),
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
                ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Baru'), onPressed: _addCategory),
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
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(tanggalPanjang(_date)),
            onTap: _pickDate,
          ),
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
