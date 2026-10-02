import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../utils/format.dart';

const _emojis = [
  '💰',
  '👨‍👩‍👧',
  '📚',
  '🎯',
  '✈️',
  '🏠',
  '🚗',
  '🎮',
  '🍜',
  '💊',
  '🎁',
  '📈',
  '🪙',
  '🏦',
  '😺',
  '🎓',
  '💻'
];
const _colors = [
  0xFF00897B,
  0xFF1E88E5,
  0xFF8E24AA,
  0xFFE53935,
  0xFFFB8C00,
  0xFF43A047,
  0xFF3949AB,
  0xFF6D4C41,
];

/// Form untuk membuat / mengubah pocket.
class PocketFormScreen extends StatefulWidget {
  final Pocket? pocket; // null = buat baru
  const PocketFormScreen({super.key, this.pocket});

  @override
  State<PocketFormScreen> createState() => _PocketFormScreenState();
}

class _PocketFormScreenState extends State<PocketFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _initial;
  late final TextEditingController _target;
  late String _emoji;
  late int _color;
  late String _type;
  DateTime? _targetDate;

  bool get _editing => widget.pocket != null;
  bool get _isMain => widget.pocket?.isMain ?? false;

  @override
  void initState() {
    super.initState();
    final p = widget.pocket;
    _name = TextEditingController(text: p?.name ?? '');
    _initial = TextEditingController(
        text:
            p == null || p.initialBalance == 0 ? '' : angka(p.initialBalance));
    _target = TextEditingController(
        text: p?.targetAmount == null ? '' : angka(p!.targetAmount!));
    _emoji = p?.emoji ?? _emojis.first;
    _color = p?.color ?? _colors.first;
    _type = p?.type ?? 'regular';
    _targetDate = p?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Nama pocket wajib diisi');
      return;
    }
    final target = parseAngka(_target.text);
    await Repo.I.savePocket(Pocket(
      id: widget.pocket?.id,
      name: name,
      emoji: _emoji,
      color: _color,
      type: _type,
      initialBalance: parseAngka(_initial.text),
      targetAmount: target > 0 ? target : null,
      targetDate: target > 0 ? _targetDate : null,
      isMain: _isMain,
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archive() async {
    if (widget.pocket!.balance != 0) {
      _snack('Saldo harus 0. Pindahkan dulu lewat Transfer ke pocket lain.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arsipkan pocket?'),
        content: const Text(
            'Pocket disembunyikan, riwayat transaksinya tetap tersimpan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Arsipkan')),
        ],
      ),
    );
    if (ok != true) return;
    await Repo.I.archivePocket(widget.pocket!.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (d != null) setState(() => _targetDate = d);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Ubah Pocket' : 'Pocket Baru')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nama pocket', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          const Text('Ikon'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _emojis)
                ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 20)),
                  selected: _emoji == e,
                  onSelected: (_) => setState(() => _emoji = e),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Warna'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final c in _colors)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: CircleAvatar(
                    backgroundColor: Color(c),
                    radius: 18,
                    child: _color == c
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          if (!_isMain) ...[
            const SizedBox(height: 16),
            const Text('Tipe'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'regular',
                    label: Text('Biasa'),
                    icon: Icon(Icons.account_balance_wallet_outlined)),
                ButtonSegment(
                    value: 'investment',
                    label: Text('Investasi'),
                    icon: Icon(Icons.trending_up)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 4),
            Text(
              _type == 'investment'
                  ? 'Saldo pocket investasi tidak dihitung sebagai Uang Pocket.'
                  : 'Pocket biasa untuk pemasukan & pengeluaran harian.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _initial,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            decoration: InputDecoration(
              labelText: _type == 'investment' ? 'Modal awal' : 'Saldo awal',
              prefixText: 'Rp ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            decoration: const InputDecoration(
              labelText: 'Target (opsional)',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_targetDate == null
                ? 'Tenggat target (opsional)'
                : tanggalPendek(_targetDate!)),
            trailing: _targetDate == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _targetDate = null)),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
          if (_editing && !_isMain) ...[
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: _archive, child: const Text('Arsipkan pocket')),
          ],
        ],
      ),
    );
  }
}
