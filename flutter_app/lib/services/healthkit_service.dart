import 'dart:async';
import 'package:health/health.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';

class HealthKitService {
  static final HealthKitService _instance = HealthKitService._internal();
  factory HealthKitService() => _instance;
  HealthKitService._internal();

  final Health _health = Health();
  final DatabaseService _database = DatabaseService();
  bool _isInitialized = false;

  // Multi-tier timers for different refresh intervals
  Timer? _fastMetricsTimer;    // Steps, Distance, Active Energy (10 sec)
  Timer? _standardMetricsTimer; // HR, Workout (30 sec)
  Timer? _slowMetricsTimer;     // HRV, SpO2, Resting HR (3 min)
  Timer? _backgroundTimer;      // Body temp, Sleep (1 hour)

  Map<String, dynamic> _latestHealthData = {};

  // Track last refresh times for on-demand refresh cooldown
  final Map<String, DateTime> _lastRefreshTimes = {};
  static const Duration _refreshCooldown = Duration(seconds: 30);

  // Track HR range since app started (not placeholders)
  double? _sessionMinHr;
  double? _sessionMaxHr;
  DateTime? _sessionStartTime;

  // Track Blood Oxygen range since app started
  double? _sessionMinSpO2;
  double? _sessionMaxSpO2;
  
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

  /// Start collecting health data with multi-tier intervals
  void startDataCollection() {
    if (!_isInitialized) {
      debugPrint('HealthKit not initialized. Call initialize() first.');
      return;
    }

    stopDataCollection(); // Stop any existing timers

    // Initialize session tracking
    _sessionStartTime = DateTime.now();
    _sessionMinHr = null;
    _sessionMaxHr = null;
    _sessionMinSpO2 = null;
    _sessionMaxSpO2 = null;

    // Collect all data immediately
    _collectFastMetrics();
    _collectStandardMetrics();
    _collectSlowMetrics();
    _collectBackgroundMetrics();

    // Set up multi-tier periodic collection
    _fastMetricsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _collectFastMetrics();
    });

    _standardMetricsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _collectStandardMetrics();
    });

    _slowMetricsTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _collectSlowMetrics();
    });

    _backgroundTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _collectBackgroundMetrics();
    });

    debugPrint('Started multi-tier health data collection');
    debugPrint('- Fast metrics: 10 seconds');
    debugPrint('- Standard metrics: 30 seconds');
    debugPrint('- Slow metrics: 3 minutes');
    debugPrint('- Background metrics: 1 hour');
  }

  /// Stop collecting health data
  void stopDataCollection() {
    _fastMetricsTimer?.cancel();
    _standardMetricsTimer?.cancel();
    _slowMetricsTimer?.cancel();
    _backgroundTimer?.cancel();
    _fastMetricsTimer = null;
    _standardMetricsTimer = null;
    _slowMetricsTimer = null;
    _backgroundTimer = null;
    debugPrint('Stopped all health data collection timers');
  }

  /// Get the latest collected health data
  Map<String, dynamic> get latestHealthData => _latestHealthData;

  /// Collect fast metrics (10 second interval): Steps, Distance, Active Energy
  Future<void> _collectFastMetrics() async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day, 0, 0, 0);

    try {
      final points = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.STEPS,
          HealthDataType.DISTANCE_WALKING_RUNNING,
          HealthDataType.ACTIVE_ENERGY_BURNED,
        ],
        startTime: todayMidnight,
        endTime: now,
      );

      // Debug: Show how many data points we got
      final stepPoints = points.where((p) => p.type == HealthDataType.STEPS).toList();
      debugPrint('Got ${stepPoints.length} step data points from HealthKit');
      if (stepPoints.isNotEmpty) {
        debugPrint('Latest step point: ${stepPoints.last.value} at ${stepPoints.last.dateTo}');
      }

      // Update latest data
      _latestHealthData['steps'] = _getTotalValue(points, HealthDataType.STEPS);
      _latestHealthData['distance'] = _getTotalValue(points, HealthDataType.DISTANCE_WALKING_RUNNING);
      _latestHealthData['active_energy'] = _getTotalValue(points, HealthDataType.ACTIVE_ENERGY_BURNED);
      _latestHealthData['timestamp'] = now.toIso8601String();

      debugPrint('Fast metrics updated: Steps=${_latestHealthData['steps']}, Distance=${_latestHealthData['distance']}, Energy=${_latestHealthData['active_energy']}');
    } catch (e) {
      debugPrint('Error collecting fast metrics: $e');
    }
  }

  /// Collect standard metrics (30 second interval): Heart Rate, Workout
  Future<void> _collectStandardMetrics() async {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    try {
      final points = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.HEART_RATE,
          HealthDataType.WORKOUT,
        ],
        startTime: oneHourAgo,
        endTime: now,
      );

      // Update heart rate
      final currentHr = _getLatestValue(points, HealthDataType.HEART_RATE);
      _latestHealthData['heart_rate'] = currentHr;

      // Update session HR range
      if (currentHr != null && currentHr >= 25 && currentHr <= 250) {
        if (_sessionMinHr == null || currentHr < _sessionMinHr!) {
          _sessionMinHr = currentHr;
        }
        if (_sessionMaxHr == null || currentHr > _sessionMaxHr!) {
          _sessionMaxHr = currentHr;
        }
        _latestHealthData['heart_rate_min'] = _sessionMinHr;
        _latestHealthData['heart_rate_max'] = _sessionMaxHr;
      }

      // Update current activity
      _latestHealthData['current_activity'] = _getCurrentActivity(points);
      _latestHealthData['timestamp'] = now.toIso8601String();

      debugPrint('Standard metrics updated: HR=${currentHr}, Activity=${_latestHealthData['current_activity']}');
    } catch (e) {
      debugPrint('Error collecting standard metrics: $e');
    }
  }

  /// Collect slow metrics (3 minute interval): HRV, SpO2, Resting HR
  Future<void> _collectSlowMetrics() async {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    try {
      final points = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.HEART_RATE_VARIABILITY_SDNN,
          HealthDataType.BLOOD_OXYGEN,
          HealthDataType.RESTING_HEART_RATE,
        ],
        startTime: last24Hours,
        endTime: now,
      );

      // Update HRV
      final hrv = _getLatestValue(points, HealthDataType.HEART_RATE_VARIABILITY_SDNN);
      _latestHealthData['heart_rate_variability'] = hrv;
      if (hrv != null) {
        debugPrint('HRV measured: ${hrv.toStringAsFixed(1)} ms');
      }

      // Update SpO2
      var bloodOxygen = _getLatestValue(points, HealthDataType.BLOOD_OXYGEN);
      if (bloodOxygen != null) {
        if (bloodOxygen <= 1.0) {
          bloodOxygen = bloodOxygen * 100;
        }
        _latestHealthData['blood_oxygen'] = bloodOxygen;

        // Update session SpO2 range
        if (bloodOxygen >= 70 && bloodOxygen <= 100) {
          if (_sessionMinSpO2 == null || bloodOxygen < _sessionMinSpO2!) {
            _sessionMinSpO2 = bloodOxygen;
          }
          if (_sessionMaxSpO2 == null || bloodOxygen > _sessionMaxSpO2!) {
            _sessionMaxSpO2 = bloodOxygen;
          }
          _latestHealthData['blood_oxygen_min'] = _sessionMinSpO2;
          _latestHealthData['blood_oxygen_max'] = _sessionMaxSpO2;
        }
      }

      // Update resting HR
      _latestHealthData['resting_heart_rate'] = _getLatestValue(points, HealthDataType.RESTING_HEART_RATE);
      _latestHealthData['timestamp'] = now.toIso8601String();

      // Save to database periodically (filter out sleep data for now)
      if (_latestHealthData.isNotEmpty) {
        // Create a copy without sleep data fields (which have mismatched column names)
        final dataToSave = Map<String, dynamic>.from(_latestHealthData);
        dataToSave.remove('total_sleep_time');
        dataToSave.remove('deep_sleep');
        dataToSave.remove('light_sleep');
        dataToSave.remove('rem_sleep');
        dataToSave.remove('awake');
        await _database.insertBiometrics(dataToSave);
        debugPrint('Saved health data to database');
      }

      debugPrint('Slow metrics updated: HRV=${hrv}, SpO2=${bloodOxygen}, RestingHR=${_latestHealthData['resting_heart_rate']}');
    } catch (e) {
      debugPrint('Error collecting slow metrics: $e');
    }
  }

  /// Collect background metrics (1 hour interval): Body Temperature, Sleep
  Future<void> _collectBackgroundMetrics() async {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    try {
      final points = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.BODY_TEMPERATURE,
          HealthDataType.SLEEP_ASLEEP,
        ],
        startTime: last24Hours,
        endTime: now,
      );

      // Update body temperature
      final bodyTemp = _getLatestValue(points, HealthDataType.BODY_TEMPERATURE);
      _latestHealthData['body_temperature'] = bodyTemp;

      // Process sleep data
      final sleepData = _getSleepData(points);
      // Store sleep data with correct column names for database
      _latestHealthData['sleep_total'] = sleepData['total_sleep_time'];
      _latestHealthData['sleep_deep'] = sleepData['deep_sleep'];
      _latestHealthData['sleep_light'] = sleepData['light_sleep'];
      _latestHealthData['sleep_rem'] = sleepData['rem_sleep'];
      _latestHealthData['sleep_awake'] = sleepData['awake'];
      _latestHealthData['timestamp'] = now.toIso8601String();

      debugPrint('Background metrics updated: BodyTemp=${bodyTemp}, SleepTotal=${sleepData['total_sleep_time']}');
    } catch (e) {
      debugPrint('Error collecting background metrics: $e');
    }
  }

  /// Check if a metric can be refreshed (cooldown period)
  bool canRefreshMetric(String metricType) {
    final lastRefresh = _lastRefreshTimes[metricType];
    if (lastRefresh == null) return true;
    return DateTime.now().difference(lastRefresh) > _refreshCooldown;
  }

  /// Refresh heart rate on demand
  Future<bool> refreshHeartRate() async {
    if (!canRefreshMetric('heart_rate')) {
      debugPrint('Heart rate refresh on cooldown');
      return false;
    }

    final now = DateTime.now();

    // Try multiple time windows to find heart rate data
    final timeWindows = [
      const Duration(minutes: 15),
      const Duration(hours: 1),
      const Duration(hours: 6),
      const Duration(hours: 24),
    ];

    for (final window in timeWindows) {
      final startTime = now.subtract(window);
      debugPrint('Trying to get HR from last ${window.inMinutes} minutes');

      try {
        // Add timeout to prevent hanging
        final points = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: startTime,
          endTime: now,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('HR request timed out for window: ${window.inMinutes} minutes');
            return [];
          },
        );

        debugPrint('Found ${points.length} HR points in last ${window.inMinutes} minutes');

        if (points.isNotEmpty) {
          final currentHr = _getLatestValue(points, HealthDataType.HEART_RATE);
          if (currentHr != null && currentHr >= 30 && currentHr <= 220) {
            _latestHealthData['heart_rate'] = currentHr;
            _latestHealthData['timestamp'] = now.toIso8601String();
            _lastRefreshTimes['heart_rate'] = now;

            // Update session min/max
            if (_sessionMinHr == null || currentHr < _sessionMinHr!) {
              _sessionMinHr = currentHr;
            }
            if (_sessionMaxHr == null || currentHr > _sessionMaxHr!) {
              _sessionMaxHr = currentHr;
            }
            _latestHealthData['heart_rate_min'] = _sessionMinHr;
            _latestHealthData['heart_rate_max'] = _sessionMaxHr;

            debugPrint('Heart rate refreshed: $currentHr bpm (from ${window.inMinutes} minute window)');
            return true;
          }
        }
      } catch (e) {
        debugPrint('Error getting HR for ${window.inMinutes} minute window: $e');
      }
    }

    debugPrint('No heart rate data found in any time window');
    return false;
  }

  /// Refresh HRV on demand
  Future<bool> refreshHRV() async {
    if (!canRefreshMetric('hrv')) {
      debugPrint('HRV refresh on cooldown');
      return false;
    }

    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    try {
      // Add timeout to prevent hanging
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        startTime: last24Hours,
        endTime: now,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('HRV refresh timed out after 30 seconds');
          throw TimeoutException('HRV refresh timed out');
        },
      );

      final hrv = _getLatestValue(points, HealthDataType.HEART_RATE_VARIABILITY_SDNN);
      if (hrv != null) {
        _latestHealthData['heart_rate_variability'] = hrv;
        _latestHealthData['timestamp'] = now.toIso8601String();
        _lastRefreshTimes['hrv'] = now;
        debugPrint('HRV refreshed: ${hrv.toStringAsFixed(1)} ms');
        return true;
      }
    } catch (e) {
      debugPrint('Error refreshing HRV: $e');
    }
    return false;
  }

  /// Refresh SpO2 on demand
  Future<bool> refreshSpO2() async {
    if (!canRefreshMetric('spo2')) {
      debugPrint('SpO2 refresh on cooldown');
      return false;
    }

    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    try {
      // Add timeout to prevent hanging
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_OXYGEN],
        startTime: last24Hours,
        endTime: now,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('SpO2 refresh timed out after 30 seconds');
          throw TimeoutException('SpO2 refresh timed out');
        },
      );

      var bloodOxygen = _getLatestValue(points, HealthDataType.BLOOD_OXYGEN);
      if (bloodOxygen != null) {
        if (bloodOxygen <= 1.0) {
          bloodOxygen = bloodOxygen * 100;
        }
        _latestHealthData['blood_oxygen'] = bloodOxygen;
        _latestHealthData['timestamp'] = now.toIso8601String();
        _lastRefreshTimes['spo2'] = now;
        debugPrint('SpO2 refreshed: $bloodOxygen%');
        return true;
      }
    } catch (e) {
      debugPrint('Error refreshing SpO2: $e');
    }
    return false;
  }

  /// Refresh current activity on demand
  Future<bool> refreshActivity() async {
    if (!canRefreshMetric('activity')) {
      debugPrint('Activity refresh on cooldown');
      return false;
    }

    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    try {
      // Add timeout to prevent hanging
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: oneHourAgo,
        endTime: now,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Activity refresh timed out after 30 seconds');
          throw TimeoutException('Activity refresh timed out');
        },
      );

      final activity = _getCurrentActivity(points);
      _latestHealthData['current_activity'] = activity;
      _latestHealthData['timestamp'] = now.toIso8601String();
      _lastRefreshTimes['activity'] = now;
      debugPrint('Activity refreshed: $activity');
      return true;
    } catch (e) {
      debugPrint('Error refreshing activity: $e');
    }
    return false;
  }

  /// Refresh body temperature on demand
  Future<bool> refreshBodyTemperature() async {
    if (!canRefreshMetric('body_temp')) {
      debugPrint('Body temperature refresh on cooldown');
      return false;
    }

    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    try {
      // Add timeout to prevent hanging
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BODY_TEMPERATURE],
        startTime: last24Hours,
        endTime: now,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Body temperature refresh timed out after 30 seconds');
          throw TimeoutException('Body temperature refresh timed out');
        },
      );

      final bodyTemp = _getLatestValue(points, HealthDataType.BODY_TEMPERATURE);
      if (bodyTemp != null) {
        _latestHealthData['body_temperature'] = bodyTemp;
        _latestHealthData['timestamp'] = now.toIso8601String();
        _lastRefreshTimes['body_temp'] = now;
        debugPrint('Body temperature refreshed: $bodyTemp°');
        return true;
      }
    } catch (e) {
      debugPrint('Error refreshing body temperature: $e');
    }
    return false;
  }

  /// Collect all health data (legacy method for compatibility)
  Future<Map<String, dynamic>> _collectHealthData() async {
    Map<String, dynamic> healthData = {};

    // Get data from today for totals, but recent for real-time values
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final last24Hours = now.subtract(const Duration(hours: 24));

    try {
      // Fetch health data points from midnight for totals
      List<HealthDataPoint> healthDataPoints = await _health.getHealthDataFromTypes(
        types: dataTypes,
        startTime: todayMidnight,
        endTime: now,
      );

      // Also try to get SpO2 from last 24 hours if not found
      if (!healthDataPoints.any((p) => p.type == HealthDataType.BLOOD_OXYGEN)) {
        debugPrint('No SpO2 today, checking last 24 hours...');
        try {
          final spO2Points = await _health.getHealthDataFromTypes(
            types: [HealthDataType.BLOOD_OXYGEN],
            startTime: last24Hours,
            endTime: now,
          );
          if (spO2Points.isNotEmpty) {
            healthDataPoints.addAll(spO2Points);
            debugPrint('Found ${spO2Points.length} SpO2 measurements in last 24h');
          }
        } catch (e) {
          debugPrint('Error fetching SpO2: $e');
        }
      }

      debugPrint('Raw health data points collected: ${healthDataPoints.length}');

      // Log data types found
      Set<HealthDataType> foundTypes = {};
      for (var point in healthDataPoints) {
        foundTypes.add(point.type);
      }
      debugPrint('Data types found: ${foundTypes.map((t) => t.toString()).join(', ')}');

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
      debugPrint('=== Health Data Collection Summary ===');
      debugPrint('Total data points: ${healthDataPoints.length}');
      debugPrint('Heart rate: ${healthData['heart_rate']} bpm');
      debugPrint('HRV: ${healthData['heart_rate_variability']} ms');
      debugPrint('SpO2: ${healthData['blood_oxygen']}%');
      debugPrint('Steps today: ${healthData['steps']}');
      debugPrint('Distance: ${healthData['distance']}m');
      debugPrint('Active energy: ${healthData['active_energy']} kcal');
      debugPrint('Current activity: ${healthData['current_activity']}');
      debugPrint('=====================================');
      
      // Here you would typically save to local database
      // For now, we'll just return the data
      
    } catch (e) {
      debugPrint('Error collecting health data: $e');
    }

    return healthData;
  }

  /// Process raw health data points into organized structure
  Map<String, dynamic> _processHealthData(List<HealthDataPoint> points, DateTime timestamp) {
    // Get blood oxygen as percentage (it comes as fraction 0-1 or percentage)
    var bloodOxygen = _getLatestValue(points, HealthDataType.BLOOD_OXYGEN);
    if (bloodOxygen != null) {
      // If value is between 0 and 1, it's a fraction - convert to percentage
      if (bloodOxygen <= 1.0) {
        bloodOxygen = bloodOxygen * 100;
      }
      debugPrint('SpO2 raw value: $bloodOxygen%');
    } else {
      debugPrint('No SpO2 data available from HealthKit');
    }

    // Update session SpO2 range with actual measurements only
    if (bloodOxygen != null && bloodOxygen >= 70 && bloodOxygen <= 100) {
      if (_sessionMinSpO2 == null || bloodOxygen < _sessionMinSpO2!) {
        _sessionMinSpO2 = bloodOxygen;
      }
      if (_sessionMaxSpO2 == null || bloodOxygen > _sessionMaxSpO2!) {
        _sessionMaxSpO2 = bloodOxygen;
      }
    }

    // Get current heart rate
    final currentHr = _getLatestValue(points, HealthDataType.HEART_RATE);

    // Update session HR range with actual measurements only
    if (currentHr != null && currentHr >= 25 && currentHr <= 250) {
      if (_sessionMinHr == null || currentHr < _sessionMinHr!) {
        _sessionMinHr = currentHr;
      }
      if (_sessionMaxHr == null || currentHr > _sessionMaxHr!) {
        _sessionMaxHr = currentHr;
      }
    }

    // Get actual resting heart rate from HealthKit
    final restingHr = _getLatestValue(points, HealthDataType.RESTING_HEART_RATE);

    // Get HRV with debug logging
    final hrv = _getLatestValue(points, HealthDataType.HEART_RATE_VARIABILITY_SDNN);
    if (hrv != null) {
      debugPrint('HRV measured: ${hrv.toStringAsFixed(1)} ms');
    }

    // Get current workout/activity
    final currentActivity = _getCurrentActivity(points);

    Map<String, dynamic> processedData = {
      'timestamp': timestamp.toIso8601String(),
      'heart_rate': currentHr,
      'heart_rate_variability': hrv,
      'resting_heart_rate': restingHr,
      'heart_rate_min': _sessionMinHr,
      'heart_rate_max': _sessionMaxHr,
      'steps': _getTotalValue(points, HealthDataType.STEPS),
      'distance': _getTotalValue(points, HealthDataType.DISTANCE_WALKING_RUNNING),
      'active_energy': _getTotalValue(points, HealthDataType.ACTIVE_ENERGY_BURNED),
      'blood_oxygen': bloodOxygen,
      'blood_oxygen_min': _sessionMinSpO2,
      'blood_oxygen_max': _sessionMaxSpO2,
      'body_temperature': _getLatestValue(points, HealthDataType.BODY_TEMPERATURE),
      'current_activity': currentActivity,
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


  /// Get the current activity from workout data
  String? _getCurrentActivity(List<HealthDataPoint> points) {
    final workoutPoints = points.where((p) => p.type == HealthDataType.WORKOUT).toList();
    if (workoutPoints.isEmpty) return null;

    // Sort by date to get the most recent
    workoutPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    // Check if the most recent workout is currently active (within last 10 minutes)
    final mostRecent = workoutPoints.first;
    final now = DateTime.now();
    if (now.difference(mostRecent.dateTo).inMinutes <= 10) {
      // Parse the workout type from the value
      final workoutValue = mostRecent.value;
      if (workoutValue is WorkoutHealthValue) {
        return _mapWorkoutType(workoutValue.workoutActivityType);
      }
    }

    return null;
  }

  /// Map HealthKit workout types to readable activity names
  String _mapWorkoutType(HealthWorkoutActivityType? type) {
    if (type == null) return 'Unknown';

    switch (type) {
      case HealthWorkoutActivityType.WALKING:
        return 'Walking';
      case HealthWorkoutActivityType.RUNNING:
        return 'Running';
      case HealthWorkoutActivityType.ELLIPTICAL:
        return 'Elliptical';
      case HealthWorkoutActivityType.ROWING:
        return 'Rowing';
      default:
        return 'Exercise';
    }
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
          types: [HealthDataType.HEART_RATE],
          startTime: oneMinuteAgo,
          endTime: now,
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
        types: [HealthDataType.HEART_RATE],
        startTime: fiveMinutesAgo,
        endTime: now,
      );
      
      // If we have recent heart rate data, watch is likely connected
      return points.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}