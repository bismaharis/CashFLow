import 'models.dart';

/// Satu catatan "nilai terkini" investasi pada tanggal tertentu.
class Valuation {
  final int id;
  final int pocketId;
  final int value;
  final DateTime date;

  const Valuation({required this.id, required this.pocketId, required this.value, required this.date});

  factory Valuation.fromMap(Map<String, Object?> m) => Valuation(
        id: m['id'] as int,
        pocketId: m['pocket_id'] as int,
        value: m['value'] as int,
        date: DateTime.parse(m['date'] as String),
      );
}

/// Ringkasan satu pocket investasi.
///  - modal        = saldo awal + total setor - total tarik
///  - currentValue = nilai terakhir yang diinput + setor/tarik SETELAH tanggal input itu
class InvestmentSummary {
  final Pocket pocket;
  final int modal;
  final int currentValue;
  final DateTime? lastValuationDate; // null = belum pernah update nilai

  const InvestmentSummary({
    required this.pocket,
    required this.modal,
    required this.currentValue,
    this.lastValuationDate,
  });

  int get profit => currentValue - modal;

  /// Persentase untung/rugi terhadap modal. Null jika modal <= 0.
  double? get profitPct => modal <= 0 ? null : profit * 100 / modal;
}
