import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan kapan terakhir backup dan kapan pengingat terakhir ditunda.
class BackupPrefs {
  static const _kLast = 'last_backup';
  static const _kSnooze = 'reminder_snooze';
  static const _kFirstRun = 'first_run';

  static Future<DateTime?> lastBackup() async {
    final p = await SharedPreferences.getInstance();
    return DateTime.tryParse(p.getString(_kLast) ?? '');
  }

  static Future<void> markBackup() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLast, DateTime.now().toIso8601String());
  }

  static Future<void> snoozeReminder() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSnooze, DateTime.now().toIso8601String());
  }

  /// True jika sudah >= [days] hari sejak backup terakhir (atau sejak pertama kali
  /// aplikasi dipakai bila belum pernah backup). Setelah pengingat muncul, ditunda 24 jam.
  static Future<bool> shouldRemind({int days = 30}) async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final firstRaw = p.getString(_kFirstRun);
    if (firstRaw == null) {
      await p.setString(_kFirstRun, now.toIso8601String());
      return false;
    }

    final snooze = DateTime.tryParse(p.getString(_kSnooze) ?? '');
    if (snooze != null && now.difference(snooze).inHours < 24) return false;

    final last = DateTime.tryParse(p.getString(_kLast) ?? '') ?? DateTime.parse(firstRaw);
    return now.difference(last).inDays >= days;
  }
}
