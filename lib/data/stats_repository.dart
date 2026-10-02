import '../db/database.dart';

class PeriodTotals {
  final int income;
  final int expense;
  final int cashExpense;
  final int cardExpense;
  const PeriodTotals({this.income = 0, this.expense = 0, this.cashExpense = 0, this.cardExpense = 0});
}

class CategorySlice {
  final String name;
  final String emoji;
  final int total;
  const CategorySlice({required this.name, required this.emoji, required this.total});
}

/// Total satu "batang" pada grafik tren (satu hari atau satu bulan).
class BucketTotal {
  final DateTime start;
  final int income;
  final int expense;
  const BucketTotal({required this.start, required this.income, required this.expense});
}

/// Query khusus statistik. Rentang waktu: [from, to) — `to` tidak ikut dihitung.
/// Transfer antar pocket TIDAK dihitung sebagai pemasukan/pengeluaran.
class StatsRepo {
  static String _two(int n) => n.toString().padLeft(2, '0');

  static Future<PeriodTotals> totals(DateTime from, DateTime to) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT type, method, COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE date >= ? AND date < ? AND type IN ('income', 'expense')
      GROUP BY type, method
    ''', [from.toIso8601String(), to.toIso8601String()]);

    var income = 0, expense = 0, cash = 0, card = 0;
    for (final r in rows) {
      final total = r['total'] as int;
      if (r['type'] == 'income') {
        income += total;
      } else {
        expense += total;
        if (r['method'] == 'card') {
          card += total;
        } else {
          cash += total;
        }
      }
    }
    return PeriodTotals(income: income, expense: expense, cashExpense: cash, cardExpense: card);
  }

  /// Pengeluaran per kategori, terbesar dulu.
  static Future<List<CategorySlice>> expenseByCategory(DateTime from, DateTime to) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      SELECT COALESCE(c.name, 'Tanpa kategori') AS name,
             COALESCE(c.emoji, '❔') AS emoji,
             SUM(t.amount) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.type = 'expense' AND t.date >= ? AND t.date < ?
      GROUP BY t.category_id
      ORDER BY total DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return rows
        .map((r) => CategorySlice(
              name: r['name'] as String,
              emoji: r['emoji'] as String,
              total: r['total'] as int,
            ))
        .toList();
  }

  /// Pemasukan & pengeluaran per hari (monthly = false) atau per bulan (monthly = true).
  /// Hari/bulan tanpa transaksi tetap muncul dengan nilai 0.
  static Future<List<BucketTotal>> buckets(DateTime from, DateTime to, {required bool monthly}) async {
    final db = await AppDatabase.instance;
    final len = monthly ? 7 : 10; // 'YYYY-MM' atau 'YYYY-MM-DD'
    final rows = await db.rawQuery('''
      SELECT substr(date, 1, $len) AS k, type, COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE date >= ? AND date < ? AND type IN ('income', 'expense')
      GROUP BY k, type
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final map = <String, List<int>>{};
    for (final r in rows) {
      final m = map.putIfAbsent(r['k'] as String, () => [0, 0]);
      if (r['type'] == 'income') {
        m[0] += r['total'] as int;
      } else {
        m[1] += r['total'] as int;
      }
    }

    final out = <BucketTotal>[];
    var d = from;
    while (d.isBefore(to)) {
      final key = monthly ? '${d.year}-${_two(d.month)}' : '${d.year}-${_two(d.month)}-${_two(d.day)}';
      final m = map[key] ?? const [0, 0];
      out.add(BucketTotal(start: d, income: m[0], expense: m[1]));
      d = monthly ? DateTime(d.year, d.month + 1, 1) : DateTime(d.year, d.month, d.day + 1);
    }
    return out;
  }
}
