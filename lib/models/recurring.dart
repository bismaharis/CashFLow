import '../utils/recurrence.dart';

class RecurringTx {
  final int? id;
  final String type; // 'income' | 'expense' | 'transfer'
  final int amount;
  final int pocketId;
  final int? toPocketId;
  final int? categoryId;
  final String? method;
  final String note;
  final Freq frequency;
  final int intervalCount;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDueDate;
  final bool active;

  // Hasil JOIN
  final String? pocketName;
  final String? pocketEmoji;
  final String? toPocketName;
  final String? categoryName;
  final String? categoryEmoji;

  const RecurringTx({
    this.id,
    required this.type,
    required this.amount,
    required this.pocketId,
    this.toPocketId,
    this.categoryId,
    this.method,
    this.note = '',
    required this.frequency,
    this.intervalCount = 1,
    required this.startDate,
    this.endDate,
    required this.nextDueDate,
    this.active = true,
    this.pocketName,
    this.pocketEmoji,
    this.toPocketName,
    this.categoryName,
    this.categoryEmoji,
  });

  factory RecurringTx.fromMap(Map<String, Object?> m) => RecurringTx(
        id: m['id'] as int,
        type: m['type'] as String,
        amount: m['amount'] as int,
        pocketId: m['pocket_id'] as int,
        toPocketId: m['to_pocket_id'] as int?,
        categoryId: m['category_id'] as int?,
        method: m['method'] as String?,
        note: (m['note'] as String?) ?? '',
        frequency: freqFromDb(m['frequency'] as String),
        intervalCount: m['interval_count'] as int,
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: m['end_date'] == null ? null : DateTime.parse(m['end_date'] as String),
        nextDueDate: DateTime.parse(m['next_due_date'] as String),
        active: (m['active'] as int) == 1,
        pocketName: m['pocket_name'] as String?,
        pocketEmoji: m['pocket_emoji'] as String?,
        toPocketName: m['to_pocket_name'] as String?,
        categoryName: m['category_name'] as String?,
        categoryEmoji: m['category_emoji'] as String?,
      );

  Map<String, Object?> toMap() => {
        'type': type,
        'amount': amount,
        'pocket_id': pocketId,
        'to_pocket_id': toPocketId,
        'category_id': categoryId,
        'method': method,
        'note': note,
        'frequency': frequency.name,
        'interval_count': intervalCount,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'next_due_date': nextDueDate.toIso8601String(),
        'active': active ? 1 : 0,
      };
}
