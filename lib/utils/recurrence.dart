/// Frekuensi yang didukung transaksi berulang.
enum Freq { daily, weekly, monthly, yearly }

Freq freqFromDb(String s) => Freq.values.firstWhere((f) => f.name == s, orElse: () => Freq.monthly);

String freqLabel(Freq f) => switch (f) {
      Freq.daily => 'Hari',
      Freq.weekly => 'Minggu',
      Freq.monthly => 'Bulan',
      Freq.yearly => 'Tahun',
    };

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Tanggal berikutnya setelah menambah [count] x [freq] dari [from].
/// Untuk bulan/tahun, tanggal disesuaikan (clamp) jika bulan tujuan lebih pendek
/// (mis. tanggal 31 Januari + 1 bulan -> 28/29 Februari, bukan meluber ke Maret).
DateTime nextOccurrence(DateTime from, Freq freq, int count) {
  switch (freq) {
    case Freq.daily:
      return from.add(Duration(days: count));
    case Freq.weekly:
      return from.add(Duration(days: 7 * count));
    case Freq.monthly:
      final totalMonths = from.year * 12 + (from.month - 1) + count;
      final year = totalMonths ~/ 12;
      final month = totalMonths % 12 + 1;
      final day = from.day.clamp(1, _daysInMonth(year, month));
      return DateTime(year, month, day, from.hour, from.minute, from.second);
    case Freq.yearly:
      final year = from.year + count;
      final day = from.day.clamp(1, _daysInMonth(year, from.month));
      return DateTime(year, from.month, day, from.hour, from.minute, from.second);
  }
}
