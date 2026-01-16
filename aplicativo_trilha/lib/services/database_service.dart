// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._privateConstructor();
  static Database? _database;

  DatabaseService._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'trilha_local_buffer.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS eventos_buffer (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_usuario TEXT NOT NULL,
      id_tag TEXT NOT NULL,
      timestamp_leitura TEXT NOT NULL,
      direcao TEXT NOT NULL,
      status_sincronizacao TEXT DEFAULT 'pendente'
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS cache_api (
      chave TEXT PRIMARY KEY,
      valor TEXT NOT NULL,
      timestamp INTEGER NOT NULL
    )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_api (
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
      ''');
    }
  }

  Future<void> salvarCache(String chave, Map<String, dynamic> jsonMap) async {
    final db = await instance.database;
    final String jsonString = jsonEncode(jsonMap);
    final int agora = DateTime.now().millisecondsSinceEpoch;

    await db.insert('cache_api', {
      'chave': chave,
      'valor': jsonString,
      'timestamp': agora,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    print("[Database] Cache salvo para: $chave");
  }

  Future<void> salvarCacheLista(String chave, List<dynamic> jsonList) async {
    final db = await instance.database;
    final String jsonString = jsonEncode(jsonList);
    final int agora = DateTime.now().millisecondsSinceEpoch;

    await db.insert('cache_api', {
      'chave': chave,
      'valor': jsonString,
      'timestamp': agora,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<dynamic> lerCache(String chave) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cache_api',
      where: 'chave = ?',
      whereArgs: [chave],
    );

    if (maps.isNotEmpty) {
      final jsonString = maps.first['valor'] as String;
      print("[Database] Cache recuperado de: $chave");
      return jsonDecode(jsonString);
    }
    return null;
  }

  Future<int> insertEvent(Map<String, dynamic> event) async {
    final db = await instance.database;
    final row = Map<String, dynamic>.from(event);
    row['status_sincronizacao'] = 'pendente';
    return await db.insert('eventos_buffer', row);
  }

  Future<List<Map<String, dynamic>>> getPendingEvents() async {
    final db = await instance.database;
    return await db.query(
      'eventos_buffer',
      where: 'status_sincronizacao = ?',
      whereArgs: ['pendente'],
      orderBy: 'id ASC',
    );
  }

  Future<int> updateEventStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'eventos_buffer',
      {'status_sincronizacao': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getLastEvent() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'eventos_buffer',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<int> countTotalEvents() async {
    final db = await instance.database;
    final int? count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM eventos_buffer'),
    );
    return count ?? 0;
  }

  Future<int> countPendingEvents() async {
    final db = await instance.database;
    final int? count = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM eventos_buffer WHERE status_sincronizacao = 'pendente'",
      ),
    );
    return count ?? 0;
  }
}
