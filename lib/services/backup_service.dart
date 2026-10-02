import 'dart:convert';

import 'package:intl/intl.dart';

import '../db/database.dart';

/// Backup = salinan seluruh isi database dalam satu file JSON (bisa dibaca manusia).
class BackupService {
  // Urutan penting: tabel "induk" dulu, baru tabel yang mengacu padanya (foreign key).
  static const _tables = [
    'pockets',
    'categories',
    'transactions',
    'investment_valuations'
  ];

  static String fileName([DateTime? now]) =>
      'keuanganku_backup_${DateFormat('yyyyMMdd_HHmm').format(now ?? DateTime.now())}.json';

  static Future<String> createJson() async {
    final db = await AppDatabase.instance;
    final data = <String, Object?>{
      'app': 'keuanganku',
      'format': 1,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    for (final t in _tables) {
      data[t] = await db.query(t);
    }
    return jsonEncode(data);
  }

  /// Mengganti SELURUH data saat ini dengan isi backup.
  /// Berjalan dalam satu transaksi database: jika gagal di tengah, data lama tetap utuh.
  /// Melempar [FormatException] jika file bukan backup KeuanganKu yang valid.
  static Future<void> restore(String jsonText) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const FormatException('File bukan JSON yang valid.');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'keuanganku') {
      throw const FormatException('Ini bukan file backup KeuanganKu.');
    }
    for (final t in ['pockets', 'categories', 'transactions']) {
      if (decoded[t] is! List)
        throw FormatException('Data "$t" tidak ditemukan di file backup.');
    }

    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      // Hapus dari tabel anak ke induk.
      for (final t in _tables.reversed) {
        await txn.delete(t);
      }
      // Isi dari tabel induk ke anak. (Backup versi lama mungkin belum punya valuations.)
      for (final t in _tables) {
        final rows =
            ((decoded as Map<String, dynamic>)[t] as List?) ?? const [];
        for (final row in rows) {
          await txn.insert(t, Map<String, Object?>.from(row as Map));
        }
      }
    });
  }
}
