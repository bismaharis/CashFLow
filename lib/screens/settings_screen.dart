import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repository.dart';
import '../services/backup_prefs.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../services/file_output.dart';
import '../utils/format.dart';
import '../utils/period.dart';
import '../services/auth_prefs.dart';
import '../services/biometric_service.dart';
import '../widgets/output_sheet.dart';
import 'pin_setup_screen.dart';
import 'recurring_screen.dart';

class SettingsScreen extends StatefulWidget {
  /// true = langsung mulai proses backup saat layar dibuka (dari dialog pengingat).
  final bool startBackup;
  const SettingsScreen({super.key, this.startBackup = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  DateTime? _lastBackup;
  bool _lockOn = false;
  bool _bioOn = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadLast();
    _loadSecurity();
    if (widget.startBackup) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _backup());
    }
  }

  Future<void> _loadSecurity() async {
    final lockOn = await AuthPrefs.isLockEnabled();
    final bioOn = await AuthPrefs.isBiometricEnabled();
    final bioAvailable = await BiometricService.isAvailable();
    if (!mounted) return;
    setState(() {
      _lockOn = lockOn;
      _bioOn = bioOn;
      _bioAvailable = bioAvailable;
    });
  }

  // ---------- Keamanan ----------

  Future<void> _toggleLock(bool on) async {
    if (on) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (ok == true) _loadSecurity();
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Matikan kunci PIN?'),
          content: const Text(
              'Aplikasi tidak akan meminta PIN atau sidik jari lagi saat dibuka.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Matikan')),
          ],
        ),
      );
      if (confirm == true) {
        await AuthPrefs.disableLock();
        _loadSecurity();
      }
    }
  }

  Future<void> _changePin() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => const PinSetupScreen(changingExisting: true)),
    );
    if (ok == true) _snack('PIN berhasil diganti');
  }

  Future<void> _toggleBiometric(bool on) async {
    if (on) {
      final ok = await BiometricService.authenticate();
      if (!ok) {
        _snack('Verifikasi sidik jari gagal, coba lagi');
        return;
      }
    }
    await AuthPrefs.setBiometricEnabled(on);
    _loadSecurity();
  }

  Future<void> _loadLast() async {
    final d = await BackupPrefs.lastBackup();
    if (mounted) setState(() => _lastBackup = d);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ---------- Export Excel ----------

  Future<void> _export() async {
    final req = await showModalBottomSheet<ExportRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ExportOptionsSheet(),
    );
    if (req == null || !mounted) return;

    setState(() => _busy = true);
    OutputFile? file;
    try {
      final bytes = await ExportService.buildExcel(
          from: req.from, to: req.to, periodLabel: req.label);
      file =
          await FileOutput.prepare(ExportService.fileName(), bytes, xlsxMime);
    } catch (e) {
      _snack('Export gagal: $e');
    }
    if (mounted) setState(() => _busy = false);
    if (file != null && mounted) await showOutputSheet(context, file);
  }

  // ---------- Backup ----------

  Future<void> _backup() async {
    setState(() => _busy = true);
    OutputFile? file;
    try {
      final text = await BackupService.createJson();
      file = await FileOutput.prepare(
          BackupService.fileName(), utf8.encode(text), jsonMime);
    } catch (e) {
      _snack('Backup gagal: $e');
    }
    if (mounted) setState(() => _busy = false);
    if (file != null && mounted) {
      await showOutputSheet(context, file, onDone: () async {
        await BackupPrefs.markBackup();
        await _loadLast();
      });
    }
  }

  // ---------- Restore ----------

  Future<void> _restore() async {
    final picked = await FilePicker.pickFiles(type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan dari backup?'),
        content: Text(
          'SEMUA data saat ini akan diganti dengan isi file:\n\n${path.split('/').last}\n\n'
          'Sebaiknya backup data saat ini dulu.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ganti data')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final text = await File(path).readAsString();
      await BackupService.restore(text);
      Repo.I.refresh(); // semua layar memuat ulang data
      _snack('Data berhasil dipulihkan');
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Restore gagal, data lama tidak diubah. ($e)');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final last = _lastBackup == null
        ? 'Belum pernah backup'
        : 'Terakhir: ${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(_lastBackup!)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Keamanan',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('Kunci PIN'),
                  subtitle: const Text('Minta PIN setiap kali aplikasi dibuka'),
                  value: _lockOn,
                  onChanged: _busy ? null : _toggleLock,
                ),
                if (_lockOn) ...[
                  ListTile(
                    enabled: !_busy,
                    leading: const Icon(Icons.password),
                    title: const Text('Ganti PIN'),
                    onTap: _changePin,
                  ),
                  if (_bioAvailable)
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: const Text('Buka dengan sidik jari'),
                      subtitle:
                          const Text('PIN tetap berlaku sebagai cadangan'),
                      value: _bioOn,
                      onChanged: _busy ? null : _toggleBiometric,
                    ),
                ],
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Otomatis',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ListTile(
                  leading: const Icon(Icons.autorenew),
                  title: const Text('Transaksi Berulang'),
                  subtitle: const Text('Gaji, langganan, tagihan rutin'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecurringScreen()),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Data',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ListTile(
                  enabled: !_busy,
                  leading: const Icon(Icons.table_view),
                  title: const Text('Export ke Excel'),
                  subtitle: const Text(
                      'Transaksi, ringkasan kategori, saldo pocket, investasi'),
                  onTap: _export,
                ),
                ListTile(
                  enabled: !_busy,
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup data'),
                  subtitle: Text(last),
                  onTap: _backup,
                ),
                ListTile(
                  enabled: !_busy,
                  leading: const Icon(Icons.restore),
                  title: const Text('Pulihkan dari backup'),
                  subtitle: const Text('Ganti semua data dengan file backup'),
                  onTap: _restore,
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Data tersimpan hanya di HP ini. Jika HP hilang atau rusak, data hanya bisa kembali '
                    'lewat file backup. Aplikasi akan mengingatkan backup setiap 30 hari.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= Pilihan periode export =======================

class ExportRequest {
  final DateTime? from; // inklusif; null = tanpa batas
  final DateTime? to; // inklusif; null = tanpa batas
  final String label;
  const ExportRequest({this.from, this.to, required this.label});
}

class _ExportOptionsSheet extends StatefulWidget {
  const _ExportOptionsSheet();

  @override
  State<_ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<_ExportOptionsSheet> {
  static const _presets = <String, (String, PeriodKind, int)>{
    'month0': ('Bulan ini', PeriodKind.month, 0),
    'month1': ('Bulan lalu', PeriodKind.month, -1),
    'quarter': ('3 Bulan', PeriodKind.quarter, 0),
    'year': ('Tahun ini', PeriodKind.year, 0),
  };

  String _choice = 'all';
  DateTimeRange? _custom;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom,
    );
    if (r != null) {
      setState(() {
        _custom = r;
        _choice = 'custom';
      });
    }
  }

  ExportRequest _request() {
    if (_choice == 'all') return const ExportRequest(label: 'Semua data');
    if (_choice == 'custom' && _custom != null) {
      return ExportRequest(
        from: _custom!.start,
        to: _custom!.end,
        label:
            '${tanggalPendek(_custom!.start)} – ${tanggalPendek(_custom!.end)}',
      );
    }
    final (_, kind, offset) = _presets[_choice]!;
    final p = Period.of(kind, offset);
    // Period.end bersifat eksklusif, sedangkan filter export inklusif: mundur satu hari.
    return ExportRequest(
        from: p.start,
        to: DateTime(p.end.year, p.end.month, p.end.day - 1),
        label: p.label);
  }

  @override
  Widget build(BuildContext context) {
    final req = _request();
    final rangeText = req.from == null ? 'Semua transaksi' : req.label;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export ke Excel',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Pilih periode transaksi yang ingin diexport.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                    label: const Text('Semua data'),
                    selected: _choice == 'all',
                    onSelected: (_) => setState(() => _choice = 'all')),
                for (final e in _presets.entries)
                  ChoiceChip(
                    label: Text(e.value.$1),
                    selected: _choice == e.key,
                    onSelected: (_) => setState(() => _choice = e.key),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(_custom != null && _choice == 'custom'
                      ? 'Rentang: ${tanggalPendek(_custom!.start)} – ${tanggalPendek(_custom!.end)}'
                      : 'Pilih tanggal'),
                  onPressed: _pickRange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Periode: $rangeText',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, req),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Buat file Excel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
