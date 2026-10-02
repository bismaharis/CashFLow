import 'package:intl/intl.dart';

enum PeriodKind { week, month, quarter, half, year }

/// Satu rentang waktu untuk statistik. [end] bersifat eksklusif (tidak ikut dihitung).
///
///  - week    : Senin – Minggu
///  - month   : tanggal 1 – akhir bulan
///  - quarter : 3 bulan berakhir di bulan ini (mis. Jul–Sep jika sekarang September)
///  - half    : 6 bulan berakhir di bulan ini
///  - year    : 1 Januari – 31 Desember
///
/// [offset] 0 = periode sekarang, -1 = periode sebelumnya, dst.
class Period {
  final PeriodKind kind;
  final int offset;
  final DateTime start;
  final DateTime end;

  const Period._(this.kind, this.offset, this.start, this.end);

  /// Periode panjang dipecah per bulan; periode pendek dipecah per hari.
  bool get monthlyBuckets =>
      kind == PeriodKind.quarter || kind == PeriodKind.half || kind == PeriodKind.year;

  static Period of(PeriodKind kind, int offset, [DateTime? now]) {
    final n = now ?? DateTime.now();
    switch (kind) {
      case PeriodKind.week:
        final monday = DateTime(n.year, n.month, n.day - (n.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day + 7 * offset);
        return Period._(kind, offset, start, DateTime(start.year, start.month, start.day + 7));
      case PeriodKind.month:
        return Period._(kind, offset, DateTime(n.year, n.month + offset, 1), DateTime(n.year, n.month + offset + 1, 1));
      case PeriodKind.quarter:
        return _months(kind, 3, offset, n);
      case PeriodKind.half:
        return _months(kind, 6, offset, n);
      case PeriodKind.year:
        return Period._(kind, offset, DateTime(n.year + offset, 1, 1), DateTime(n.year + offset + 1, 1, 1));
    }
  }

  static Period _months(PeriodKind kind, int months, int offset, DateTime n) {
    final endMonth = n.month + offset * months; // bulan terakhir dalam rentang
    return Period._(kind, offset, DateTime(n.year, endMonth - months + 1, 1), DateTime(n.year, endMonth + 1, 1));
  }

  String get label {
    final last = DateTime(end.year, end.month, end.day - 1);
    switch (kind) {
      case PeriodKind.week:
        return '${DateFormat('d MMM', 'id_ID').format(start)} – ${DateFormat('d MMM yyyy', 'id_ID').format(last)}';
      case PeriodKind.month:
        return DateFormat('MMMM yyyy', 'id_ID').format(start);
      case PeriodKind.quarter:
      case PeriodKind.half:
        final s = start.year == last.year
            ? DateFormat('MMM', 'id_ID').format(start)
            : DateFormat('MMM yyyy', 'id_ID').format(start);
        return '$s – ${DateFormat('MMM yyyy', 'id_ID').format(last)}';
      case PeriodKind.year:
        return '${start.year}';
    }
  }
}
