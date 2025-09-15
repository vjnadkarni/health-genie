import 'dart:async';
import 'package:health/health.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';

class HealthKitService {
  static final HealthKitService _instance = HealthKitService._internal();
  factory HealthKitService() => _instance;
  HealthKitService._internal();

  final HealthFactory _health = HealthFactory();
  final DatabaseService _database = DatabaseService();
  bool _isInitialized = false;
  Timer? _dataCollectionTimer;
  Map<String, dynamic> _latestHealthData = {};
  
  // Define the health data types we want to read
  static const List<HealthDataType> dataTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BODY_TEMPERATURE,
  ];

  // Define permissions (read-only for now)
  static const List<HealthDataAccess> permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  /// Initialize HealthKit and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Configure Health
      // Configure is no longer needed in newer versions
      
      // Check if HealthKit is available on this device
      // Note: We'll proceed directly to requesting permissions
      // since HealthKit availability is platform-specific
      
      // Request authorization for the data types
      bool authorized = await _health.requestAuthorization(
        dataTypes,
        permissions: permissions,
      );

      if (authorized) {
        _isInitialized = true;
        debugPrint('HealthKit initialized successfully');
        return true;
      } else {
        debugPrint('HealthKit authorization denied');
        return false;
      }
    } catch (e) {
      debugPrint('Error initializing HealthKit: $e');
      return false;
    }
  }

  /// Start collecting health data at regular intervals
  void startDataCollection({Duration interval = const Duration(seconds: 15)}) {
    if (!_isInitialized) {
      debugPrint('HealthKit not initialized. Call initialize() first.');
      return;
    }

    stopDataCollection(); // Stop any existing timer
    
    // Collect data immediately
    _collectHealthData();
    
    // Set up periodic collection
    _dataCollectionTimer = Timer.periodic(interval, (_) {
      _collectHealthData();
    });
    
    debugPrint('Started health data collection with ${interval.inSeconds}s interval');
  }

  /// Stop collecting health data
  void stopDataCollection() {
    _dataCollectionTimer?.cancel();
    _dataCollectionTimer = null;
    debugPrint('Stopped health data collection');
  }

  /// Get the latest collected health data
  Map<String, dynamic> get latestHealthData => _latestHealthData;

  /// Collect all health data
  Future<Map<String, dynamic>> _collectHealthData() async {
    Map<String, dynamic> healthData = {};
    
    // Get data from today (since midnight)
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day, 0, 0, 0);

    try {
      // Fetch health data points
      List<HealthDataPoint> healthDataPoints = await _health.getHealthDataFromTypes(
        todayMidnight,
        now,
        dataTypes,
      );

      // Process and organize the data
      healthData = _processHealthData(healthDataPoints, now);
      
      // Store the latest data
      _latestHealthData = healthData;
      
      // Save to database if we have data
      if (healthData.isNotEmpty) {
        await _database.insertBiometrics(healthData);
        debugPrint('Saved health data to database');
      }
      
      // Log collection with details
      debugPrint('Collected ${healthDataPoints.length} health data points');
      debugPrint('Latest heart rate: ${healthData['heart_rate']}');
      debugPrint('Steps today: ${healthData['steps']}');
      debugPrint('Distance: ${healthData['distance']}m');
      
      // Here you would typically save to local database
      // For now, we'll just return the data
      
    } catch (e) {
      debugPrint('Error collecting health data: $e');
    }

    return healthData;
  }

  /// Process raw health data points into organized structure
  Map<String, dynamic> _processHealthData(List<HealthDataPoint> points, DateTime timestamp) {
    // Get blood oxygen as percentage (it comes as fraction 0-1)
    var bloodOxygen = _getLatestValue(points, HealthDataType.BLOOD_OXYGEN);
    if (bloodOxygen != null && bloodOxygen <= 1.0) {
      bloodOxygen = bloodOxygen * 100; // Convert to percentage
    }
    
    Map<String, dynamic> processedData = {
      'timestamp': timestamp.toIso8601String(),
      'heart_rate': _getLatestValue(points, HealthDataType.HEART_RATE),
      'heart_rate_variability': _getLatestValue(points, HealthDataType.HEART_RATE_VARIABILITY_SDNN),
      'resting_heart_rate': _getLatestValue(points, HealthDataType.RESTING_HEART_RATE),
      'steps': _getTotalValue(points, HealthDataType.STEPS),
      'distance': _getTotalValue(points, HealthDataType.DISTANCE_WALKING_RUNNING),
      'active_energy': _getTotalValue(points, HealthDataType.ACTIVE_ENERGY_BURNED),
      'blood_oxygen': bloodOxygen,
      'body_temperature': _getLatestValue(points, HealthDataType.BODY_TEMPERATURE),
    };

    return processedData;
  }

  /// Get the latest value for a specific health data type
  double? _getLatestValue(List<HealthDataPoint> points, HealthDataType type) {
    final filteredPoints = points.where((p) => p.type == type).toList();
    if (filteredPoints.isEmpty) {
      debugPrint('No data points found for type: $type');
      return null;
    }
    
    filteredPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
    var value = filteredPoints.first.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return 0.0;
  }

  /// Get the total value for a cumulative health data type
  double _getTotalValue(List<HealthDataPoint> points, HealthDataType type) {
    final filteredPoints = points.where((p) => p.type == type);
    if (filteredPoints.isEmpty) return 0.0;
    
    return filteredPoints.fold(0.0, (sum, point) {
      var value = point.value;
      if (value is NumericHealthValue) {
        return sum + value.numericValue.toDouble();
      }
      return sum;
    });
  }

  /// Process sleep data
  Map<String, dynamic> _getSleepData(List<HealthDataPoint> points) {
    final sleepPoints = points.where((p) => p.type == HealthDataType.SLEEP_ASLEEP).toList();
    
    Map<String, dynamic> sleepData = {
      'total_sleep_time': 0.0,
      'deep_sleep': 0.0,
      'light_sleep': 0.0,
      'rem_sleep': 0.0,
      'awake': 0.0,
    };

    for (var point in sleepPoints) {
      final duration = point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
      
      // Note: The actual sleep stage values depend on the health package implementation
      // This is a simplified version
      switch (point.value.toString()) {
        case 'SLEEP_DEEP':
          sleepData['deep_sleep'] = (sleepData['deep_sleep'] ?? 0) + duration;
          break;
        case 'SLEEP_LIGHT':
          sleepData['light_sleep'] = (sleepData['light_sleep'] ?? 0) + duration;
          break;
        case 'SLEEP_REM':
          sleepData['rem_sleep'] = (sleepData['rem_sleep'] ?? 0) + duration;
          break;
        case 'SLEEP_AWAKE':
          sleepData['awake'] = (sleepData['awake'] ?? 0) + duration;
          break;
      }
    }

    sleepData['total_sleep_time'] = sleepData['deep_sleep']! + 
                                    sleepData['light_sleep']! + 
                                    sleepData['rem_sleep']!;

    return sleepData;
  }

  /// Get real-time heart rate (for monitoring screen)
  Stream<double?> get heartRateStream {
    return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
      if (!_isInitialized) return null;
      
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
      
      try {
        final points = await _health.getHealthDataFromTypes(
          oneMinuteAgo,
          now,
          [HealthDataType.HEART_RATE],
        );
        
        if (points.isNotEmpty) {
          points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          var value = points.first.value;
          if (value is NumericHealthValue) {
            return value.numericValue.toDouble();
          }
          return 0.0;
        }
      } catch (e) {
        debugPrint('Error getting heart rate: $e');
      }
      
      return null;
    });
  }

  /// Check if Apple Watch is connected
  Future<bool> isWatchConnected() async {
    // The health package doesn't directly provide watch connection status
    // We infer it by trying to get recent data
    try {
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      
      final points = await _health.getHealthDataFromTypes(
        fiveMinutesAgo,
        now,
        [HealthDataType.HEART_RATE],
      );
      
      // If we have recent heart rate data, watch is likely connected
      return points.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}