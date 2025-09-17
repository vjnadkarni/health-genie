import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  
  // Database configuration
  static const String _databaseName = 'health_genie.db';
  static const int _databaseVersion = 3;
  
  // Table names
  static const String tableBiometrics = 'biometrics';
  static const String tableHealthScores = 'health_scores';
  static const String tableSyncQueue = 'sync_queue';
  
  // Circular buffer configuration (24 hours of data at 15-second intervals)
  static const int maxBiometricRecords = 5760; // 24 * 60 * 4
  int _oldestRecordPointer = 0;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create biometrics table with circular buffer support
    await db.execute('''
      CREATE TABLE $tableBiometrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        heart_rate REAL,
        heart_rate_variability REAL,
        resting_heart_rate REAL,
        heart_rate_min REAL,
        heart_rate_max REAL,
        steps REAL,
        distance REAL,
        active_energy REAL,
        blood_oxygen REAL,
        blood_oxygen_min REAL,
        blood_oxygen_max REAL,
        body_temperature REAL,
        sleep_total REAL,
        sleep_deep REAL,
        sleep_light REAL,
        sleep_rem REAL,
        sleep_awake REAL,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create health scores table
    await db.execute('''
      CREATE TABLE $tableHealthScores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        overall_score REAL NOT NULL,
        cardiovascular_score REAL,
        sleep_score REAL,
        activity_score REAL,
        recovery_score REAL,
        stress_score REAL,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create sync queue table for cloud synchronization
    await db.execute('''
      CREATE TABLE $tableSyncQueue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        retry_count INTEGER DEFAULT 0,
        last_retry TEXT
      )
    ''');

    // Create indices for better performance
    await db.execute('CREATE INDEX idx_biometrics_timestamp ON $tableBiometrics(timestamp)');
    await db.execute('CREATE INDEX idx_biometrics_synced ON $tableBiometrics(is_synced)');
    await db.execute('CREATE INDEX idx_scores_timestamp ON $tableHealthScores(timestamp)');
    await db.execute('CREATE INDEX idx_scores_synced ON $tableHealthScores(is_synced)');
    
    debugPrint('Database tables created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades
    debugPrint('Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 2) {
      // Add new columns for heart rate min/max
      await db.execute('ALTER TABLE $tableBiometrics ADD COLUMN heart_rate_min REAL');
      await db.execute('ALTER TABLE $tableBiometrics ADD COLUMN heart_rate_max REAL');
      debugPrint('Added heart_rate_min and heart_rate_max columns to biometrics table');
    }

    if (oldVersion < 3) {
      // Add new columns for blood oxygen min/max
      await db.execute('ALTER TABLE $tableBiometrics ADD COLUMN blood_oxygen_min REAL');
      await db.execute('ALTER TABLE $tableBiometrics ADD COLUMN blood_oxygen_max REAL');
      debugPrint('Added blood_oxygen_min and blood_oxygen_max columns to biometrics table');
    }
  }

  /// Insert biometric data with circular buffer management
  Future<int> insertBiometrics(Map<String, dynamic> data) async {
    final db = await database;
    
    // Check if we need to implement circular buffer
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableBiometrics')
    ) ?? 0;

    if (count >= maxBiometricRecords) {
      // Delete oldest record to maintain circular buffer
      await _deleteOldestBiometric(db);
    }

    // Insert new record
    final id = await db.insert(tableBiometrics, {
      ...data,
      'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
      'is_synced': 0,
    });

    debugPrint('Inserted biometric record with ID: $id');
    return id;
  }

  /// Delete the oldest biometric record (circular buffer implementation)
  Future<void> _deleteOldestBiometric(Database db) async {
    // Get the oldest record
    final List<Map<String, dynamic>> oldest = await db.query(
      tableBiometrics,
      orderBy: 'id ASC',
      limit: 1,
    );

    if (oldest.isNotEmpty) {
      final oldestId = oldest.first['id'];
      
      // If not synced, add to sync queue before deletion
      if (oldest.first['is_synced'] == 0) {
        await _addToSyncQueue(db, tableBiometrics, oldestId, 'INSERT', oldest.first);
      }
      
      // Delete the oldest record
      await db.delete(
        tableBiometrics,
        where: 'id = ?',
        whereArgs: [oldestId],
      );
      
      debugPrint('Deleted oldest biometric record (ID: $oldestId) for circular buffer');
    }
  }

  /// Add record to sync queue for later cloud synchronization
  Future<void> _addToSyncQueue(Database db, String tableName, int recordId, String action, Map<String, dynamic> data) async {
    await db.insert(tableSyncQueue, {
      'table_name': tableName,
      'record_id': recordId,
      'action': action,
      'data': data.toString(), // In production, use JSON encoding
    });
  }

  /// Insert health score
  Future<int> insertHealthScore(Map<String, dynamic> score) async {
    final db = await database;
    
    final id = await db.insert(tableHealthScores, {
      ...score,
      'timestamp': score['timestamp'] ?? DateTime.now().toIso8601String(),
      'is_synced': 0,
    });

    debugPrint('Inserted health score with ID: $id');
    return id;
  }

  /// Get recent biometric data
  Future<List<Map<String, dynamic>>> getRecentBiometrics({int limit = 100}) async {
    final db = await database;
    
    return await db.query(
      tableBiometrics,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// Get biometric data for a specific time range
  Future<List<Map<String, dynamic>>> getBiometricsInRange(DateTime start, DateTime end) async {
    final db = await database;
    
    return await db.query(
      tableBiometrics,
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
  }

  /// Get latest health score
  Future<Map<String, dynamic>?> getLatestHealthScore() async {
    final db = await database;
    
    final results = await db.query(
      tableHealthScores,
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Get health scores for a specific time range
  Future<List<Map<String, dynamic>>> getHealthScoresInRange(DateTime start, DateTime end) async {
    final db = await database;
    
    return await db.query(
      tableHealthScores,
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
  }

  /// Get unsynced records for cloud synchronization
  Future<List<Map<String, dynamic>>> getUnsyncedBiometrics({int limit = 100}) async {
    final db = await database;
    
    return await db.query(
      tableBiometrics,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }

  /// Mark records as synced
  Future<void> markAsSynced(String tableName, List<int> ids) async {
    if (ids.isEmpty) return;
    
    final db = await database;
    final batch = db.batch();
    
    for (final id in ids) {
      batch.update(
        tableName,
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    
    await batch.commit(noResult: true);
    debugPrint('Marked ${ids.length} records as synced in $tableName');
  }

  /// Get sync queue items
  Future<List<Map<String, dynamic>>> getSyncQueueItems({int limit = 50}) async {
    final db = await database;
    
    return await db.query(
      tableSyncQueue,
      where: 'retry_count < ?',
      whereArgs: [3], // Max 3 retries
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Remove items from sync queue
  Future<void> removeSyncQueueItems(List<int> ids) async {
    if (ids.isEmpty) return;
    
    final db = await database;
    
    await db.delete(
      tableSyncQueue,
      where: 'id IN (${ids.map((_) => '?').join(',')})',
      whereArgs: ids,
    );
  }

  /// Clear all data (for testing purposes)
  Future<void> clearAllData() async {
    final db = await database;
    
    await db.delete(tableBiometrics);
    await db.delete(tableHealthScores);
    await db.delete(tableSyncQueue);
    
    debugPrint('All database tables cleared');
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    
    final biometricsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableBiometrics')
    ) ?? 0;
    
    final scoresCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableHealthScores')
    ) ?? 0;
    
    final unsyncedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableBiometrics WHERE is_synced = 0')
    ) ?? 0;
    
    final syncQueueCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableSyncQueue')
    ) ?? 0;

    return {
      'biometrics': biometricsCount,
      'scores': scoresCount,
      'unsynced': unsyncedCount,
      'sync_queue': syncQueueCount,
    };
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}