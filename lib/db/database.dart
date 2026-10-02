import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Membuka database SQLite lokal (file di penyimpanan internal aplikasi).
class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'keuangan.db');
    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Dipanggil otomatis saat versi database naik (data lama tetap aman).
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createValuations(db);
    if (oldVersion < 3) await _createRecurring(db);
  }

  /// Template transaksi berulang (gaji, langganan, dll).
  static Future<void> _createRecurring(Database db) async {
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        pocket_id INTEGER NOT NULL,
        to_pocket_id INTEGER,
        category_id INTEGER,
        method TEXT,
        note TEXT NOT NULL DEFAULT '',
        frequency TEXT NOT NULL,
        interval_count INTEGER NOT NULL DEFAULT 1,
        start_date TEXT NOT NULL,
        end_date TEXT,
        next_due_date TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (pocket_id) REFERENCES pockets(id),
        FOREIGN KEY (to_pocket_id) REFERENCES pockets(id),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )''');
    // frequency: 'daily' | 'weekly' | 'monthly' | 'yearly'
  }

  /// Riwayat "nilai terkini" investasi yang diinput manual.
  static Future<void> _createValuations(Database db) async {
    await db.execute('''
      CREATE TABLE investment_valuations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pocket_id INTEGER NOT NULL,
        value INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (pocket_id) REFERENCES pockets(id)
      )''');
    await db.execute('CREATE INDEX idx_val_pocket ON investment_valuations(pocket_id, date)');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pockets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        color INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'regular',
        initial_balance INTEGER NOT NULL DEFAULT 0,
        target_amount INTEGER,
        target_date TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_main INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )''');
    // pockets.type: 'regular' | 'investment'

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        type TEXT NOT NULL
      )''');
    // categories.type: 'income' | 'expense'

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        pocket_id INTEGER NOT NULL,
        to_pocket_id INTEGER,
        category_id INTEGER,
        method TEXT,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (pocket_id) REFERENCES pockets(id),
        FOREIGN KEY (to_pocket_id) REFERENCES pockets(id),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )''');
    // transactions.type: 'income' | 'expense' | 'transfer'
    // transactions.method: 'cash' | 'card' (null untuk transfer)
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await _createValuations(db);
    await _createRecurring(db);

    // Data awal
    await db.insert('pockets', {
      'name': 'Kantong Utama',
      'emoji': '💰',
      'color': 0xFF00897B,
      'type': 'regular',
      'initial_balance': 0,
      'is_main': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    const expense = [
      ['Makan & Minum', '🍜'],
      ['Transportasi', '🚗'],
      ['Belanja', '🛍️'],
      ['Tagihan', '🧾'],
      ['Kesehatan', '💊'],
      ['Hiburan', '🎮'],
      ['Pendidikan', '📚'],
      ['Keluarga', '👨‍👩‍👧'],
      ['Lainnya', '📦'],
    ];
    const income = [
      ['Gaji', '💼'],
      ['Bonus', '🎁'],
      ['Usaha', '🏪'],
      ['Lainnya', '💵'],
    ];
    final batch = db.batch();
    for (final c in expense) {
      batch.insert('categories', {'name': c[0], 'emoji': c[1], 'type': 'expense'});
    }
    for (final c in income) {
      batch.insert('categories', {'name': c[0], 'emoji': c[1], 'type': 'income'});
    }
    await batch.commit(noResult: true);
  }
}
