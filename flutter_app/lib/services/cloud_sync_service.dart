import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_service.dart';
import 'database_service.dart';

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseAuthService _auth = SupabaseAuthService();
  final DatabaseService _database = DatabaseService();

  Timer? _syncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Start automatic sync (when on WiFi)
  void startAutoSync() {
    // Sync every 15 minutes when on WiFi
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      syncIfOnWiFi();
    });

    // Initial sync
    syncIfOnWiFi();
  }

  /// Stop automatic sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Check if on WiFi and sync
  Future<void> syncIfOnWiFi() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      await syncHealthData();
    } else {
      debugPrint('Not on WiFi, skipping sync');
    }
  }

  /// Manual sync (user-triggered)
  Future<bool> syncHealthData() async {
    if (!_auth.isLoggedIn) {
      debugPrint('User not logged in, skipping sync');
      return false;
    }

    if (_isSyncing) {
      debugPrint('Sync already in progress');
      return false;
    }

    try {
      _isSyncing = true;
      debugPrint('Starting cloud sync...');

      // Upload local data
      await _uploadHealthScores();
      await _uploadBiometricSummaries();

      // Download remote data
      await _downloadHealthScores();
      await _downloadBiometricSummaries();

      _lastSyncTime = DateTime.now();
      debugPrint('Cloud sync completed successfully');
      return true;
    } catch (e) {
      debugPrint('Sync error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload health scores to cloud
  Future<void> _uploadHealthScores() async {
    final userId = _auth.currentUserId;
    if (userId == null) return;

    try {
      // Get unsynced health scores from local database
      final unsyncedScores = await _database.getUnsyncedHealthScores();

      if (unsyncedScores.isEmpty) {
        debugPrint('No unsynced health scores to upload');
        return;
      }

      // Prepare data for upload
      final deviceId = await _getDeviceId();
      final scoresToUpload = unsyncedScores.map((score) {
        return {
          'user_id': userId,
          'timestamp': score['timestamp'],
          'overall_score': score['overall_score'],
          'cardiovascular_score': score['cardiovascular_score'],
          'sleep_score': score['sleep_score'],
          'activity_score': score['activity_score'],
          'recovery_score': score['recovery_score'],
          'stress_score': score['stress_score'],
          'confidence_level': score['confidence_level'] ?? 0,
          'device_id': score['device_id'] ?? deviceId,
        };
      }).toList();

      // Upload to Supabase
      await _supabase.from('health_scores').upsert(
        scoresToUpload,
        onConflict: 'user_id,timestamp',
      );

      // Mark as synced in local database
      final syncedIds = unsyncedScores.map((s) => s['id'] as int).toList();
      await _database.markAsSynced('health_scores', syncedIds);

      debugPrint('Uploaded ${scoresToUpload.length} health scores');
    } catch (e) {
      debugPrint('Error uploading health scores: $e');
      rethrow;
    }
  }

  /// Upload biometric summaries to cloud
  Future<void> _uploadBiometricSummaries() async {
    final userId = _auth.currentUserId;
    if (userId == null) return;

    try {
      // Get today's biometric summary
      final today = DateTime.now();
      final summary = await _calculateDailySummary(today);

      if (summary == null) {
        debugPrint('No biometric data to summarize for today');
        return;
      }

      // Upload to Supabase
      await _supabase.from('biometric_summaries').upsert({
        'user_id': userId,
        'date': today.toIso8601String().split('T')[0],
        ...summary,
        'device_id': await _getDeviceId(),
      }, onConflict: 'user_id,date');

      debugPrint('Uploaded biometric summary for ${today.toIso8601String().split('T')[0]}');
    } catch (e) {
      debugPrint('Error uploading biometric summaries: $e');
      rethrow;
    }
  }

  /// Download health scores from cloud
  Future<void> _downloadHealthScores() async {
    final userId = _auth.currentUserId;
    if (userId == null) return;

    try {
      // Get last sync time or default to 30 days ago
      final fromDate = _lastSyncTime ?? DateTime.now().subtract(const Duration(days: 30));

      // Download scores from Supabase
      final response = await _supabase
          .from('health_scores')
          .select()
          .eq('user_id', userId)
          .gte('timestamp', fromDate.toIso8601String())
          .order('timestamp', ascending: false);

      final scores = List<Map<String, dynamic>>.from(response as List);

      if (scores.isEmpty) {
        debugPrint('No new health scores to download');
        return;
      }

      // Store in local database
      for (final score in scores) {
        await _database.insertHealthScore({
          ...score,
          'is_synced': 1, // Mark as already synced
        });
      }

      debugPrint('Downloaded ${scores.length} health scores');
    } catch (e) {
      debugPrint('Error downloading health scores: $e');
      rethrow;
    }
  }

  /// Download biometric summaries from cloud
  Future<void> _downloadBiometricSummaries() async {
    final userId = _auth.currentUserId;
    if (userId == null) return;

    try {
      // Get last 30 days of summaries
      final fromDate = DateTime.now().subtract(const Duration(days: 30));

      // Download summaries from Supabase
      final response = await _supabase
          .from('biometric_summaries')
          .select()
          .eq('user_id', userId)
          .gte('date', fromDate.toIso8601String().split('T')[0])
          .order('date', ascending: false);

      final summaries = List<Map<String, dynamic>>.from(response as List);

      if (summaries.isEmpty) {
        debugPrint('No biometric summaries to download');
        return;
      }

      // Store summaries for use in long-term calculations
      // (In production, you might want to store these in a separate table)
      debugPrint('Downloaded ${summaries.length} biometric summaries');
    } catch (e) {
      debugPrint('Error downloading biometric summaries: $e');
      rethrow;
    }
  }

  /// Calculate daily summary from local biometric data
  Future<Map<String, dynamic>?> _calculateDailySummary(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get biometrics for the day
    final biometrics = await _database.getBiometricsInRange(startOfDay, endOfDay);

    if (biometrics.isEmpty) return null;

    // Calculate aggregates
    double totalHeartRate = 0;
    double minHeartRate = double.infinity;
    double maxHeartRate = 0;
    double totalHRV = 0;
    double totalBloodOxygen = 0;
    int hrvCount = 0;
    int bloodOxygenCount = 0;

    double totalSteps = 0;
    double totalDistance = 0;
    double totalActiveEnergy = 0;

    for (final metric in biometrics) {
      // Heart rate
      if (metric['heart_rate'] != null) {
        final hr = (metric['heart_rate'] as num).toDouble();
        totalHeartRate += hr;
        if (hr < minHeartRate) minHeartRate = hr;
        if (hr > maxHeartRate) maxHeartRate = hr;
      }

      // HRV
      if (metric['heart_rate_variability'] != null) {
        totalHRV += (metric['heart_rate_variability'] as num).toDouble();
        hrvCount++;
      }

      // Blood oxygen
      if (metric['blood_oxygen'] != null) {
        totalBloodOxygen += (metric['blood_oxygen'] as num).toDouble();
        bloodOxygenCount++;
      }

      // Activity
      if (metric['steps'] != null) {
        totalSteps = (metric['steps'] as num).toDouble();
      }
      if (metric['distance'] != null) {
        totalDistance = (metric['distance'] as num).toDouble();
      }
      if (metric['active_energy'] != null) {
        totalActiveEnergy = (metric['active_energy'] as num).toDouble();
      }
    }

    return {
      'avg_heart_rate': biometrics.isNotEmpty ? totalHeartRate / biometrics.length : null,
      'min_heart_rate': minHeartRate != double.infinity ? minHeartRate : null,
      'max_heart_rate': maxHeartRate > 0 ? maxHeartRate : null,
      'avg_hrv': hrvCount > 0 ? totalHRV / hrvCount : null,
      'avg_blood_oxygen': bloodOxygenCount > 0 ? totalBloodOxygen / bloodOxygenCount : null,
      'total_steps': totalSteps.toInt(),
      'total_distance': totalDistance,
      'active_energy_burned': totalActiveEnergy,
      // Sleep data would come from sleep_analysis field
      'total_sleep_minutes': biometrics.last['sleep_total']?.toInt(),
      'deep_sleep_minutes': biometrics.last['sleep_deep']?.toInt(),
      'rem_sleep_minutes': biometrics.last['sleep_rem']?.toInt(),
      'light_sleep_minutes': biometrics.last['sleep_light']?.toInt(),
      'awake_minutes': biometrics.last['sleep_awake']?.toInt(),
    };
  }

  /// Get device ID
  Future<String> _getDeviceId() async {
    // In production, use device_info_plus package
    return 'iphone_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Delete all user data from cloud (for privacy)
  Future<void> deleteAllCloudData() async {
    final userId = _auth.currentUserId;
    if (userId == null) return;

    try {
      // Delete health scores
      await _supabase
          .from('health_scores')
          .delete()
          .eq('user_id', userId);

      // Delete biometric summaries
      await _supabase
          .from('biometric_summaries')
          .delete()
          .eq('user_id', userId);

      // Delete user profile
      await _supabase
          .from('user_profiles')
          .delete()
          .eq('id', userId);

      debugPrint('All cloud data deleted for user');
    } catch (e) {
      debugPrint('Error deleting cloud data: $e');
      rethrow;
    }
  }
}

// Extension to add unsynced methods to DatabaseService
extension SyncExtensions on DatabaseService {
  Future<List<Map<String, dynamic>>> getUnsyncedHealthScores() async {
    final db = await database;
    return await db.query(
      DatabaseService.tableHealthScores,
      where: 'is_synced = ?',
      whereArgs: [0],
      limit: 100,
    );
  }
}