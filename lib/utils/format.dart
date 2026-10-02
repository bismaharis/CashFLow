import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _num = NumberFormat.decimalPattern('id_ID');

/// 1500000 -> "Rp 1.500.000"
String rupiah(int v) => _rp.format(v);

/// 1500000 -> "1.500.000"
String angka(int v) => _num.format(v);

String tanggalPanjang(DateTime d) => DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(d);
String tanggalPendek(DateTime d) => DateFormat('d MMM yyyy', 'id_ID').format(d);

/// "1.500.000" -> 1500000
int parseAngka(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Otomatis menambah titik ribuan saat mengetik nominal.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    if (digits.length > 12) digits = digits.substring(0, 12);
    final formatted = angka(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
