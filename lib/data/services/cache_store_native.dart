/// SQLite-backed cache store for Android, iOS, macOS, Linux, Windows.
/// Uses sqflite + path_provider — NOT imported on Web.

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class CacheEntry {
  final String payload;
  final int updatedAt;
  const CacheEntry({required this.payload, required this.updatedAt});
}

class CacheStore {
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'campus_talent_cache.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE cache_items(
            cache_key TEXT PRIMARY KEY,
            payload   TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE offline_queue(
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type  TEXT NOT NULL,
            payload      TEXT NOT NULL,
            created_at   INTEGER NOT NULL,
            retry_count  INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_queue(
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              action_type  TEXT NOT NULL,
              payload      TEXT NOT NULL,
              created_at   INTEGER NOT NULL,
              retry_count  INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
      },
    );
    return _db!;
  }

  Future<void> write(String key, String payload) async {
    final db = await _open();
    await db.insert(
      'cache_items',
      {
        'cache_key': key,
        'payload': payload,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CacheEntry?> read(String key) async {
    final db = await _open();
    final rows = await db.query(
      'cache_items',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CacheEntry(
      payload: rows.first['payload'] as String,
      updatedAt: rows.first['updated_at'] as int,
    );
  }

  Future<void> enqueue(String actionType, String payload) async {
    final db = await _open();
    await db.insert('offline_queue', {
      'action_type': actionType,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> pendingActions() async {
    final db = await _open();
    return db.query('offline_queue', orderBy: 'created_at ASC');
  }

  Future<int> pendingCount() async {
    final db = await _open();
    final result =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM offline_queue');
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> dequeue(int id) async {
    final db = await _open();
    await db.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetry(int id) async {
    final db = await _open();
    await db.rawUpdate(
      'UPDATE offline_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }
}
