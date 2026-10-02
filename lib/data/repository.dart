import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../models/investment.dart';
import '../models/models.dart';
import '../models/recurring.dart';
import '../utils/recurrence.dart';

/// Kriteria filter untuk daftar transaksi. Field yang null = tidak difilter.
class TxFilter {
  String query = '';
  String? type; // 'income' | 'expense' | 'transfer'
  int? pocketId;
  int? categoryId;
  String? method; // 'cash' | 'card'
  DateTime? from;
  DateTime? to;

  TxFilter copy() => TxFilter()
    ..query = query
    ..type = type
    ..pocketId = pocketId
    ..categoryId = categoryId
    ..method = method
    ..from = from
    ..to = to;

  /// Jumlah filter aktif (pencarian teks tidak dihitung).
  int get activeCount =>
      (type != null ? 1 : 0) +
      (pocketId != null ? 1 : 0) +
      (categoryId != null ? 1 : 0) +
      (method != null ? 1 : 0) +
      (from != null || to != null ? 1 : 0);

  bool get isActive => activeCount > 0 || query.trim().isNotEmpty;
}

/// Satu-satunya tempat yang bicara langsung ke database.
/// Setiap kali data berubah, [notifyListeners] dipanggil supaya layar ikut refresh.
class Repo extends ChangeNotifier {
  Repo._();
  static final Repo I = Repo._();

  /// Dipakai setelah operasi besar di luar Repo (mis. restore backup) agar semua layar memuat ulang.
  void refresh() => notifyListeners();

  // ---------- POCKET ----------

  /// Saldo pocket = saldo awal + pemasukan - pengeluaran - transfer keluar + transfer masuk
  Future<List<Pocket>> pockets({bool includeArchived = false}) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT p.*,
        p.initial_balance
        + COALESCE((SELECT SUM(CASE t.type WHEN 'income' THEN t.amount ELSE -t.amount END)
                    FROM transactions t WHERE t.pocket_id = p.id), 0)
        + COALESCE((SELECT SUM(t.amount)
                    FROM transactions t WHERE t.type = 'transfer' AND t.to_pocket_id = p.id), 0)
        AS balance
      FROM pockets p
      ${includeArchived ? '' : 'WHERE p.is_archived = 0'}
      ORDER BY p.is_main DESC, p.id ASC
    ''');
    return rows.map(Pocket.fromMap).toList();
  }

  Future<void> savePocket(Pocket p) async {
    final db = await AppDatabase.instance;
    if (p.id == null) {
      await db.insert('pockets', {
        ...p.toMap(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      await db.update('pockets', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    }
    notifyListeners();
  }

  Future<void> archivePocket(int id) async {
    final db = await AppDatabase.instance;
    await db.update('pockets', {'is_archived': 1}, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  // ---------- KATEGORI ----------

  Future<List<TxCategory>> categories() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('categories', orderBy: 'id ASC');
    return rows.map(TxCategory.fromMap).toList();
  }

  Future<int> addCategory(TxCategory c) async {
    final db = await AppDatabase.instance;
    final id = await db.insert('categories', {'name': c.name, 'emoji': c.emoji, 'type': c.type});
    notifyListeners();
    return id;
  }

  // ---------- TRANSAKSI BERULANG ----------

  Future<List<RecurringTx>> recurring() async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT r.*,
             p.name  AS pocket_name,
             p.emoji AS pocket_emoji,
             tp.name AS to_pocket_name,
             c.name  AS category_name,
             c.emoji AS category_emoji
      FROM recurring_transactions r
      JOIN pockets p ON p.id = r.pocket_id
      LEFT JOIN pockets tp ON tp.id = r.to_pocket_id
      LEFT JOIN categories c ON c.id = r.category_id
      ORDER BY r.active DESC, r.next_due_date ASC
    ''');
    return rows.map(RecurringTx.fromMap).toList();
  }

  Future<void> saveRecurring(RecurringTx r) async {
    final db = await AppDatabase.instance;
    if (r.id == null) {
      await db.insert('recurring_transactions', r.toMap());
    } else {
      await db.update('recurring_transactions', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
    }
    notifyListeners();
  }

  Future<void> setRecurringActive(int id, bool active) async {
    final db = await AppDatabase.instance;
    await db.update('recurring_transactions', {'active': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> deleteRecurring(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  /// Mencatat semua transaksi yang sudah jatuh tempo (bisa lebih dari satu kali
  /// per item kalau aplikasi lama tidak dibuka), lalu menggeser next_due_date
  /// ke depan. Dipanggil sekali setiap aplikasi dibuka. Mengembalikan jumlah
  /// transaksi baru yang tercatat.
  Future<int> runDueRecurring() async {
    final db = await AppDatabase.instance;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final rows = await db.query('recurring_transactions', where: 'active = 1');

    var created = 0;
    for (final row in rows) {
      final r = RecurringTx.fromMap(row);
      var due = r.nextDueDate;
      var guard = 0;
      while (!due.isAfter(todayDate) && (r.endDate == null || !due.isAfter(r.endDate!)) && guard < 500) {
        guard++;
        await db.insert('transactions', {
          'type': r.type,
          'amount': r.amount,
          'date': DateTime(due.year, due.month, due.day, 9, 0).toIso8601String(),
          'pocket_id': r.pocketId,
          'to_pocket_id': r.toPocketId,
          'category_id': r.categoryId,
          'method': r.method,
          'note': r.note.isEmpty ? '(otomatis)' : r.note,
        });
        created++;
        due = nextOccurrence(due, r.frequency, r.intervalCount);
      }
      if (due != r.nextDueDate) {
        // Lewat tanggal akhir: matikan otomatis supaya tidak dicek berulang-ulang.
        final stillActive = r.endDate == null || !due.isAfter(r.endDate!);
        await db.update(
          'recurring_transactions',
          {'next_due_date': due.toIso8601String(), 'active': stillActive ? 1 : 0},
          where: 'id = ?',
          whereArgs: [r.id],
        );
      }
    }
    if (created > 0) notifyListeners();
    return created;
  }

  // ---------- INVESTASI ----------

  /// Ringkasan semua pocket investasi (yang tidak diarsipkan).
  Future<List<InvestmentSummary>> investments() async {
    final db = await AppDatabase.instance;
    final all = await pockets();
    final result = <InvestmentSummary>[];

    for (final p in all.where((p) => p.isInvestment)) {
      // Di pocket investasi hanya ada transfer, jadi saldo pocket = modal.
      final modal = p.balance;

      final last = await db.query(
        'investment_valuations',
        where: 'pocket_id = ?',
        whereArgs: [p.id],
        orderBy: 'date DESC, id DESC',
        limit: 1,
      );
      if (last.isEmpty) {
        // Belum ada update nilai: anggap nilai = modal (untung/rugi 0).
        result.add(InvestmentSummary(pocket: p, modal: modal, currentValue: modal));
        continue;
      }

      final v = Valuation.fromMap(last.first);
      // Setor/tarik yang terjadi SETELAH update nilai terakhir menggeser nilai,
      // supaya menyetor tidak terlihat seperti "rugi".
      final adjRows = await db.rawQuery('''
        SELECT COALESCE(SUM(CASE WHEN to_pocket_id = ? THEN amount ELSE -amount END), 0) AS adj
        FROM transactions
        WHERE type = 'transfer' AND (to_pocket_id = ? OR pocket_id = ?) AND date > ?
      ''', [p.id, p.id, p.id, v.date.toIso8601String()]);
      final adj = adjRows.first['adj'] as int;

      result.add(InvestmentSummary(
        pocket: p,
        modal: modal,
        currentValue: v.value + adj,
        lastValuationDate: v.date,
      ));
    }
    return result;
  }

  Future<List<Valuation>> valuations(int pocketId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'investment_valuations',
      where: 'pocket_id = ?',
      whereArgs: [pocketId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Valuation.fromMap).toList();
  }

  Future<void> addValuation(int pocketId, int value, DateTime date) async {
    final db = await AppDatabase.instance;
    await db.insert('investment_valuations', {
      'pocket_id': pocketId,
      'value': value,
      'date': date.toIso8601String(),
    });
    notifyListeners();
  }

  Future<void> deleteValuation(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('investment_valuations', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  // ---------- TRANSAKSI ----------

  Future<void> addTransaction(TxRecord t) async {
    final db = await AppDatabase.instance;
    await db.insert('transactions', t.toMap());
    notifyListeners();
  }

  Future<void> updateTransaction(TxRecord t) async {
    final db = await AppDatabase.instance;
    await db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
    notifyListeners();
  }

  Future<void> deleteTransaction(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  /// Daftar transaksi (terbaru dulu). Klausa WHERE disusun dari [filter];
  /// nilainya selalu lewat tanda tanya (?) supaya aman dari SQL injection.
  Future<List<TxRecord>> transactions({int? limit, TxFilter? filter}) async {
    final db = await AppDatabase.instance;
    final where = <String>[];
    final args = <Object?>[];

    final f = filter;
    if (f != null) {
      final q = f.query.trim();
      if (q.isNotEmpty) {
        where.add('(t.note LIKE ? OR c.name LIKE ?)');
        args.addAll(['%$q%', '%$q%']);
      }
      if (f.type != null) {
        where.add('t.type = ?');
        args.add(f.type);
      }
      if (f.pocketId != null) {
        where.add('(t.pocket_id = ? OR t.to_pocket_id = ?)');
        args.addAll([f.pocketId, f.pocketId]);
      }
      if (f.categoryId != null) {
        where.add('t.category_id = ?');
        args.add(f.categoryId);
      }
      if (f.method != null) {
        where.add('t.method = ?');
        args.add(f.method);
      }
      if (f.from != null) {
        where.add('t.date >= ?');
        args.add(DateTime(f.from!.year, f.from!.month, f.from!.day).toIso8601String());
      }
      if (f.to != null) {
        where.add('t.date < ?');
        args.add(DateTime(f.to!.year, f.to!.month, f.to!.day + 1).toIso8601String());
      }
    }

    final rows = await db.rawQuery('''
      SELECT t.*,
             p.name  AS pocket_name,
             tp.name AS to_pocket_name,
             c.name  AS category_name,
             c.emoji AS category_emoji
      FROM transactions t
      JOIN pockets p ON p.id = t.pocket_id
      LEFT JOIN pockets tp ON tp.id = t.to_pocket_id
      LEFT JOIN categories c ON c.id = t.category_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY t.date DESC, t.id DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', args);
    return rows.map(TxRecord.fromMap).toList();
  }

  /// Total pemasukan & pengeluaran pada bulan tertentu.
  Future<({int income, int expense})> monthTotals(DateTime month) async {
    final db = await AppDatabase.instance;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await db.rawQuery('''
      SELECT type, COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE date >= ? AND date < ? AND type IN ('income', 'expense')
      GROUP BY type
    ''', [start.toIso8601String(), end.toIso8601String()]);
    var income = 0, expense = 0;
    for (final r in rows) {
      if (r['type'] == 'income') income = r['total'] as int;
      if (r['type'] == 'expense') expense = r['total'] as int;
    }
    return (income: income, expense: expense);
  }
}
