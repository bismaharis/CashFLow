class Pocket {
  final int? id;
  final String name;
  final String emoji;
  final int color;
  final String type; // 'regular' | 'investment'
  final int initialBalance;
  final int? targetAmount;
  final DateTime? targetDate;
  final bool isMain;
  final int balance; // dihitung dari query, bukan kolom

  const Pocket({
    this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.type = 'regular',
    this.initialBalance = 0,
    this.targetAmount,
    this.targetDate,
    this.isMain = false,
    this.balance = 0,
  });

  bool get isInvestment => type == 'investment';

  factory Pocket.fromMap(Map<String, Object?> m) => Pocket(
        id: m['id'] as int,
        name: m['name'] as String,
        emoji: m['emoji'] as String,
        color: m['color'] as int,
        type: m['type'] as String,
        initialBalance: m['initial_balance'] as int,
        targetAmount: m['target_amount'] as int?,
        targetDate: m['target_date'] == null ? null : DateTime.parse(m['target_date'] as String),
        isMain: (m['is_main'] as int) == 1,
        balance: (m['balance'] as int?) ?? (m['initial_balance'] as int),
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'emoji': emoji,
        'color': color,
        'type': type,
        'initial_balance': initialBalance,
        'target_amount': targetAmount,
        'target_date': targetDate?.toIso8601String(),
      };
}

class TxCategory {
  final int? id;
  final String name;
  final String emoji;
  final String type; // 'income' | 'expense'

  const TxCategory({this.id, required this.name, required this.emoji, required this.type});

  factory TxCategory.fromMap(Map<String, Object?> m) => TxCategory(
        id: m['id'] as int,
        name: m['name'] as String,
        emoji: m['emoji'] as String,
        type: m['type'] as String,
      );
}

class TxRecord {
  final int? id;
  final String type; // 'income' | 'expense' | 'transfer'
  final int amount;
  final DateTime date;
  final int pocketId;
  final int? toPocketId;
  final int? categoryId;
  final String? method; // 'cash' | 'card'
  final String note;

  // Hasil JOIN (hanya terisi saat dibaca dari database)
  final String? pocketName;
  final String? toPocketName;
  final String? categoryName;
  final String? categoryEmoji;

  const TxRecord({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.pocketId,
    this.toPocketId,
    this.categoryId,
    this.method,
    this.note = '',
    this.pocketName,
    this.toPocketName,
    this.categoryName,
    this.categoryEmoji,
  });

  factory TxRecord.fromMap(Map<String, Object?> m) => TxRecord(
        id: m['id'] as int,
        type: m['type'] as String,
        amount: m['amount'] as int,
        date: DateTime.parse(m['date'] as String),
        pocketId: m['pocket_id'] as int,
        toPocketId: m['to_pocket_id'] as int?,
        categoryId: m['category_id'] as int?,
        method: m['method'] as String?,
        note: (m['note'] as String?) ?? '',
        pocketName: m['pocket_name'] as String?,
        toPocketName: m['to_pocket_name'] as String?,
        categoryName: m['category_name'] as String?,
        categoryEmoji: m['category_emoji'] as String?,
      );

  Map<String, Object?> toMap() => {
        'type': type,
        'amount': amount,
        'date': date.toIso8601String(),
        'pocket_id': pocketId,
        'to_pocket_id': toPocketId,
        'category_id': categoryId,
        'method': method,
        'note': note,
      };
}
