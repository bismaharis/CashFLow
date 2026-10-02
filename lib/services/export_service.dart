import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../data/repository.dart';
import '../models/investment.dart';
import '../models/models.dart';

/// Membuat file Excel (.xlsx) dengan 4 sheet:
/// Transaksi, Ringkasan Kategori, Saldo Pocket, Investasi.
class ExportService {
  static String fileName([DateTime? now]) =>
      'keuanganku_export_${DateFormat('yyyyMMdd_HHmm').format(now ?? DateTime.now())}.xlsx';

  static const _tipe = {'income': 'Pemasukan', 'expense': 'Pengeluaran', 'transfer': 'Transfer'};

  /// [from]/[to] (inklusif) membatasi sheet Transaksi & Ringkasan Kategori.
  /// Saldo Pocket dan Investasi selalu menunjukkan kondisi saat ini.
  static Future<List<int>> buildExcel({DateTime? from, DateTime? to, required String periodLabel}) async {
    final filter = TxFilter()
      ..from = from
      ..to = to;
    final items = (await Repo.I.transactions(filter: filter)).reversed.toList(); // lama -> baru
    final pockets = await Repo.I.pockets();
    final inv = await Repo.I.investments();

    final excel = Excel.createExcel();
    final def = excel.getDefaultSheet();
    if (def != null) excel.rename(def, 'Transaksi');

    _sheetTransactions(excel['Transaksi'], items);
    _sheetCategories(excel['Ringkasan Kategori'], items, periodLabel);
    _sheetPockets(excel['Saldo Pocket'], pockets);
    await _sheetInvestments(excel['Investasi'], inv);

    final bytes = excel.save();
    if (bytes == null) throw Exception('Gagal membuat file Excel');
    return bytes;
  }

  // ---------- helper ----------

  /// Menambah satu baris. int -> angka, double -> angka desimal, lainnya -> teks.
  static void _row(Sheet s, List<Object?> values, {bool bold = false}) {
    s.appendRow(values.map<CellValue?>((v) {
      if (v == null) return null;
      if (v is int) return IntCellValue(v);
      if (v is double) return DoubleCellValue(v);
      return TextCellValue(v.toString());
    }).toList());
    if (bold) {
      final r = s.maxRows - 1;
      for (var c = 0; c < values.length; c++) {
        s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = CellStyle(bold: true);
      }
    }
  }

  static void _widths(Sheet s, List<double> widths) {
    for (var i = 0; i < widths.length; i++) {
      s.setColumnWidth(i, widths[i]);
    }
  }

  static double _pct(int part, int total) => double.parse((part * 100 / total).toStringAsFixed(1));

  // ---------- sheet 1: Transaksi ----------

  static void _sheetTransactions(Sheet s, List<TxRecord> items) {
    _row(s, ['Tanggal', 'Jam', 'Tipe', 'Pocket', 'Pocket Tujuan', 'Kategori', 'Metode', 'Nominal', 'Arus Kas', 'Catatan'],
        bold: true);
    final d = DateFormat('yyyy-MM-dd');
    final h = DateFormat('HH:mm');
    for (final t in items) {
      final arus = t.type == 'income' ? t.amount : (t.type == 'expense' ? -t.amount : 0);
      _row(s, [
        d.format(t.date),
        h.format(t.date),
        _tipe[t.type] ?? t.type,
        t.pocketName ?? '',
        t.toPocketName ?? '',
        t.categoryName ?? '',
        t.method == null ? '' : (t.method == 'card' ? 'Card' : 'Cash'),
        t.amount,
        arus,
        t.note,
      ]);
    }
    _widths(s, [12, 8, 13, 18, 18, 18, 9, 14, 14, 30]);
  }

  // ---------- sheet 2: Ringkasan Kategori ----------

  static void _sheetCategories(Sheet s, List<TxRecord> items, String periodLabel) {
    final income = items.where((t) => t.type == 'income').fold<int>(0, (a, t) => a + t.amount);
    final expense = items.where((t) => t.type == 'expense').fold<int>(0, (a, t) => a + t.amount);

    _row(s, ['Periode', periodLabel], bold: true);
    _row(s, ['Total Pemasukan', income]);
    _row(s, ['Total Pengeluaran', expense]);
    _row(s, ['Selisih', income - expense]);
    _row(s, ['Pengeluaran / Pemasukan (%)', income == 0 ? '-' : _pct(expense, income)]);
    _row(s, ['']);
    _row(s, ['Kategori', 'Tipe', 'Total', 'Persen dari total tipe (%)'], bold: true);

    for (final type in ['expense', 'income']) {
      final totals = <String, int>{};
      for (final t in items.where((t) => t.type == type)) {
        final key = t.categoryName ?? 'Tanpa kategori';
        totals[key] = (totals[key] ?? 0) + t.amount;
      }
      final sum = totals.values.fold<int>(0, (a, b) => a + b);
      final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final e in entries) {
        _row(s, [e.key, _tipe[type], e.value, sum == 0 ? 0.0 : _pct(e.value, sum)]);
      }
    }
    _widths(s, [30, 14, 16, 26]);
  }

  // ---------- sheet 3: Saldo Pocket ----------

  static void _sheetPockets(Sheet s, List<Pocket> pockets) {
    _row(s, ['Pocket', 'Tipe', 'Saldo saat export'], bold: true);
    for (final p in pockets) {
      _row(s, [p.name, p.isInvestment ? 'Investasi (modal)' : 'Biasa', p.balance]);
    }
    final total = pockets.where((p) => !p.isInvestment).fold<int>(0, (a, p) => a + p.balance);
    _row(s, ['']);
    _row(s, ['Total Uang Pocket (tanpa investasi)', '', total], bold: true);
    _widths(s, [36, 18, 20]);
  }

  // ---------- sheet 4: Investasi ----------

  static Future<void> _sheetInvestments(Sheet s, List<InvestmentSummary> inv) async {
    _row(s, ['Pocket', 'Modal', 'Nilai Terkini', 'Untung/Rugi', 'Untung/Rugi (%)', 'Update Terakhir'], bold: true);
    if (inv.isEmpty) {
      _row(s, ['Belum ada pocket investasi']);
    }
    final d = DateFormat('yyyy-MM-dd');
    for (final i in inv) {
      _row(s, [
        i.pocket.name,
        i.modal,
        i.currentValue,
        i.profit,
        i.profitPct == null ? '-' : double.parse(i.profitPct!.toStringAsFixed(1)),
        i.lastValuationDate == null ? 'Belum pernah' : d.format(i.lastValuationDate!),
      ]);
    }
    if (inv.isNotEmpty) {
      final modal = inv.fold<int>(0, (a, i) => a + i.modal);
      final nilai = inv.fold<int>(0, (a, i) => a + i.currentValue);
      _row(s, ['Total', modal, nilai, nilai - modal, modal <= 0 ? '-' : _pct(nilai - modal, modal)], bold: true);

      _row(s, ['']);
      _row(s, ['Riwayat Nilai'], bold: true);
      _row(s, ['Pocket', 'Tanggal', 'Nilai'], bold: true);
      for (final i in inv) {
        for (final v in await Repo.I.valuations(i.pocket.id!)) {
          _row(s, [i.pocket.name, d.format(v.date), v.value]);
        }
      }
    }
    _widths(s, [26, 16, 16, 16, 16, 18]);
  }
}
