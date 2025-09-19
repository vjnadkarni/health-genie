import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/healthkit_service.dart';
import '../services/database_service.dart';
import '../services/health_score_service.dart';
import '../services/long_term_health_score_service.dart';
import '../services/calorie_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../models/user_profile.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final HealthKitService _healthKit = HealthKitService();
  final DatabaseService _database = DatabaseService();
  final HealthScoreService _scoreService = HealthScoreService();
  final LongTermHealthScoreService _longTermScoreService = LongTermHealthScoreService();
  final SupabaseAuthService _authService = SupabaseAuthService();
  final CloudSyncService _syncService = CloudSyncService();

  Map<String, double> _currentScores = {
    'overall': 0,
    'cardiovascular': 0,
    'sleep': 0,
    'activity': 0,
    'recovery': 0,
    'stress': 0,
  };

  Map<String, dynamic> _longTermScores = {};
  double _scoreConfidence = 0.0;

  Map<String, dynamic> _latestBiometrics = {};
  bool _isLoading = true;
  bool _isWatchConnected = false;
  Timer? _refreshTimer;

  // Profile data
  UserProfile _profile = UserProfile();
  bool _showProfile = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Track current cardiovascular metric display
  int _currentCardioMetric = 0; // 0: HR, 1: HR Range, 2: Resting HR, 3: HRV/Stress
  final List<String> _cardioMetricNames = [
    'Heart Rate',
    'HR Range',
    'Resting HR',
    'HRV/Stress',
  ];

  // Track current blood oxygen metric display
  int _currentSpO2Metric = 0; // 0: Current SpO2, 1: SpO2 Range

  // Track current activity metric display
  int _currentActivityMetric = 0; // 0: Steps, 1: Calories, 2: Current Activity

  // Track refresh states for on-demand refresh buttons
  final Map<String, bool> _isRefreshing = {};
  final Map<String, DateTime> _lastRefreshTime = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initializeServices();
    // Refresh UI every 10 seconds to show updated metrics
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateMetricsFromHealthKit();
    });
  }

  Future<void> _initializeServices() async {
    // Initialize HealthKit
    final initialized = await _healthKit.initialize();
    if (initialized) {
      // Start multi-tier data collection
      _healthKit.startDataCollection();
      
      // Check watch connection
      _isWatchConnected = await _healthKit.isWatchConnected();
      
      // Load latest data
      await _loadLatestData();
    } else {
      // Show permission error
      _showError('HealthKit permissions not granted');
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadLatestData() async {
    // Get latest biometrics from database
    final biometrics = await _database.getRecentBiometrics(limit: 1);
    if (biometrics.isNotEmpty) {
      _latestBiometrics = biometrics.first;

      // Debug: Log the actual biometric values
      debugPrint('Loaded biometrics: heart_rate=${_latestBiometrics['heart_rate']}, blood_oxygen=${_latestBiometrics['blood_oxygen']}');

      // Calculate instant health scores (for comparison/fallback)
      _currentScores = _scoreService.calculateHealthScore(_latestBiometrics);

      // Calculate long-term health scores
      final longTermResult = await _longTermScoreService.calculateLongTermHealthScore();
      _longTermScores = longTermResult['scores'] != null
          ? Map<String, double>.from(longTermResult['scores'] as Map)
          : {};
      _scoreConfidence = longTermResult['confidence'] ?? 0.0;

      // Use long-term scores if confidence is sufficient, otherwise fall back to instant scores
      if (_scoreConfidence >= 0.5) {
        _currentScores = Map<String, double>.from(_longTermScores);
        debugPrint('Using long-term scores with confidence: $_scoreConfidence');
      } else {
        debugPrint('Low confidence in long-term data ($_scoreConfidence), using instant scores');
      }

      debugPrint('Calculated scores: overall=${_currentScores['overall']}');
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _updateMetricsFromHealthKit() {
    // Get live data from HealthKit service
    final liveData = _healthKit.latestHealthData;

    // Merge live data with existing biometrics
    if (liveData.isNotEmpty) {
      // Create a new mutable map from the database data
      _latestBiometrics = Map<String, dynamic>.from(_latestBiometrics);
      _latestBiometrics.addAll(liveData);

      // Recalculate scores with updated data
      _currentScores = _scoreService.calculateHealthScore(_latestBiometrics);

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Health Genie'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cloud sync status
            if (_authService.isLoggedIn) ...[
              Icon(
                _syncService.isSyncing
                    ? CupertinoIcons.arrow_2_circlepath
                    : CupertinoIcons.cloud_upload,
                color: _syncService.isSyncing
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.activeGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            // Watch connection status
            Icon(
              _isWatchConnected ? CupertinoIcons.device_phone_portrait : CupertinoIcons.exclamationmark_triangle,
              color: _isWatchConnected ? CupertinoColors.activeGreen : CupertinoColors.systemOrange,
              size: 20,
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.refresh),
              onPressed: _loadLatestData,
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cloud sync banner
                    if (!_authService.isLoggedIn)
                      _buildSyncPromptBanner(),

                    // Overall Health Score Card
                    _buildOverallScoreCard(),
                    const SizedBox(height: 20),
                    
                    // Category Scores
                    _buildCategoryScores(),
                    const SizedBox(height: 20),
                    
                    // Current Vitals
                    _buildVitalsSection(),
                    const SizedBox(height: 20),
                    
                    // Activity Summary
                    _buildActivitySection(),
                    const SizedBox(height: 20),
                    
                    // Recommendations
                    _buildRecommendations(),
                    const SizedBox(height: 20),

                    // Profile Section
                    _buildProfileSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOverallScoreCard() {
    final score = _currentScores['overall'] ?? 0;
    final status = _scoreService.getHealthStatus(score);
    final color = _scoreService.getScoreColor(score);

    // Determine data quality label based on confidence
    String dataQuality;
    Color dataQualityColor;
    if (_scoreConfidence >= 0.8) {
      dataQuality = 'High Quality Data';
      dataQualityColor = Colors.green;
    } else if (_scoreConfidence >= 0.5) {
      dataQuality = 'Good Data';
      dataQualityColor = Colors.lightGreen;
    } else if (_scoreConfidence >= 0.3) {
      dataQuality = 'Limited Data';
      dataQualityColor = Colors.orange;
    } else {
      dataQuality = 'Insufficient Data';
      dataQualityColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall Health Score',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_scoreConfidence > 0) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _scoreConfidence >= 0.5
                        ? CupertinoIcons.checkmark_seal_fill
                        : CupertinoIcons.exclamationmark_triangle_fill,
                      color: dataQualityColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dataQuality,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Column(
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  if (_scoreConfidence >= 0.5) const SizedBox(height: 4),
                  if (_scoreConfidence >= 0.5) Text(
                    '24-hour average',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryScores() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Container(
              width: double.infinity, // Full width
              height: 120, // Fixed height for all boxes
              child: _buildCategoryCard('Cardiovascular', _currentScores['cardiovascular'] ?? 0, CupertinoIcons.heart_fill),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity, // Full width
              height: 120, // Fixed height for all boxes
              child: _buildCategoryCard('Blood Oxygen', _currentScores['sleep'] ?? 0, CupertinoIcons.drop_fill),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity, // Full width
              height: 120, // Fixed height for all boxes
              child: _buildCategoryCard('Activity', _currentScores['activity'] ?? 0, CupertinoIcons.flame_fill),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, double score, IconData icon) {
    // Special handling for Cardiovascular card
    if (title == 'Cardiovascular') {
      return GestureDetector(
        onTap: () {
          setState(() {
            _currentCardioMetric = (_currentCardioMetric + 1) % _cardioMetricNames.length;
          });
        },
        child: _buildCardiovascularCard(),
      );
    }

    // Special handling for Blood Oxygen card
    if (title == 'Blood Oxygen') {
      return GestureDetector(
        onTap: () {
          setState(() {
            _currentSpO2Metric = (_currentSpO2Metric + 1) % 2; // Toggle between 0 and 1
          });
        },
        child: _buildBloodOxygenCard(),
      );
    }

    // Special handling for Activity card
    if (title == 'Activity') {
      return GestureDetector(
        onTap: () {
          setState(() {
            _currentActivityMetric = (_currentActivityMetric + 1) % 3;
          });
        },
        child: _buildActivityMetricCard(),
      );
    }

    // Default card for other categories
    final color = _scoreService.getScoreColor(score);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardiovascularCard() {
    String displayValue = '--';
    String subtitle = _cardioMetricNames[_currentCardioMetric];
    Color valueColor = CupertinoColors.label;
    String? stressLevel;
    bool showRefreshButton = false;
    String refreshKey = '';

    switch (_currentCardioMetric) {
      case 0: // Current Heart Rate
        final hr = _latestBiometrics['heart_rate'];
        if (hr != null) {
          displayValue = '${hr.toStringAsFixed(0)} bpm';
          valueColor = _getHeartRateColor(hr.toDouble());
        }
        showRefreshButton = true;
        refreshKey = 'heart_rate';
        break;

      case 1: // HR Range
        final minHr = _latestBiometrics['heart_rate_min'];
        final maxHr = _latestBiometrics['heart_rate_max'];
        if (minHr != null && maxHr != null) {
          displayValue = '${minHr.toStringAsFixed(0)}-${maxHr.toStringAsFixed(0)}';
        }
        break;

      case 2: // Resting Heart Rate (use session minimum)
        final minHr = _latestBiometrics['heart_rate_min'];
        if (minHr != null) {
          displayValue = '${minHr.toStringAsFixed(0)} bpm';
        }
        break;

      case 3: // HRV/Stress
        final hrv = _latestBiometrics['heart_rate_variability'];
        if (hrv != null) {
          displayValue = '${hrv.toStringAsFixed(0)} ms';
          valueColor = _getHRVColor(hrv.toDouble());
          stressLevel = _getStressLevel(hrv.toDouble());
        }
        showRefreshButton = true;
        refreshKey = 'hrv';
        break;
    }

    return Stack(
      children: [
        Container(
          width: double.infinity, // Ensure full width
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.heart_fill, color: valueColor, size: 24),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: _currentCardioMetric == 1 ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
              if (stressLevel != null) ...[
                Text(
                  stressLevel,
                  style: TextStyle(
                    fontSize: 11,
                    color: valueColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showRefreshButton)
          _buildRefreshButton(refreshKey),
      ],
    );
  }

  Color _getHeartRateColor(double hr) {
    if (hr >= 42 && hr <= 85) {
      return CupertinoColors.systemGreen;
    } else if (hr >= 86 && hr <= 140) {
      return CupertinoColors.systemOrange;
    } else {
      return CupertinoColors.systemRed;
    }
  }

  Color _getHRVColor(double hrv) {
    if (hrv > 60) {
      return CupertinoColors.systemGreen;
    } else if (hrv >= 30 && hrv <= 60) {
      return CupertinoColors.systemOrange;
    } else {
      return CupertinoColors.systemRed;
    }
  }

  String _getStressLevel(double hrv) {
    if (hrv > 60) {
      return 'Low Stress';
    } else if (hrv >= 30 && hrv <= 60) {
      return 'Medium Stress';
    } else {
      return 'High Stress';
    }
  }

  Widget _buildBloodOxygenCard() {
    String displayValue = '--';
    String subtitle = _currentSpO2Metric == 0 ? 'Blood Oxygen' : 'SpO2 Range';
    Color valueColor = CupertinoColors.systemRed; // Default red for blood icon
    bool showRefreshButton = false;
    String refreshKey = '';

    switch (_currentSpO2Metric) {
      case 0: // Current Blood Oxygen
        final spO2 = _latestBiometrics['blood_oxygen'];
        if (spO2 != null) {
          displayValue = '${spO2.toStringAsFixed(0)}%';
          valueColor = _getSpO2Color(spO2.toDouble());
        }
        showRefreshButton = true;
        refreshKey = 'spo2';
        break;

      case 1: // SpO2 Range
        final minSpO2 = _latestBiometrics['blood_oxygen_min'];
        final maxSpO2 = _latestBiometrics['blood_oxygen_max'];
        if (minSpO2 != null && maxSpO2 != null) {
          displayValue = '${minSpO2.toStringAsFixed(0)}-${maxSpO2.toStringAsFixed(0)}%';
        }
        valueColor = CupertinoColors.systemRed; // Keep icon red for range
        break;
    }

    return Stack(
      children: [
        Container(
          width: double.infinity, // Ensure full width
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.drop_fill, color: CupertinoColors.systemRed, size: 24),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: _currentSpO2Metric == 1 ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: _currentSpO2Metric == 0 ? valueColor : CupertinoColors.label,
                ),
              ),
            ],
          ),
        ),
        if (showRefreshButton)
          _buildRefreshButton(refreshKey),
      ],
    );
  }

  Widget _buildActivityMetricCard() {
    // Calculate calories burned
    final caloriesBurned = CalorieService.calculateCaloriesBurned(
      profile: _profile,
      activeEnergyFromHealthKit: _latestBiometrics['active_energy']?.toDouble(),
      heartRate: _latestBiometrics['heart_rate']?.toDouble(),
      steps: _latestBiometrics['steps']?.toInt(),
      currentActivity: _latestBiometrics['current_activity'],
    );

    String displayValue = '--';
    String subtitle = '';
    IconData icon = CupertinoIcons.flame_fill;
    Color iconColor = CupertinoColors.systemOrange;
    Widget? progressBar;

    switch (_currentActivityMetric) {
      case 0: // Steps
        final steps = _latestBiometrics['steps']?.toInt() ?? 0;
        displayValue = steps.toString();
        subtitle = 'Steps Today';
        icon = CupertinoIcons.person_2;
        iconColor = CupertinoColors.systemGreen;
        // Add progress bar
        final progress = (steps / 10000).clamp(0.0, 1.0);
        progressBar = Container(
          height: 4,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
        break;

      case 1: // Calories
        displayValue = '${caloriesBurned.toStringAsFixed(0)}';
        subtitle = 'Calories Burned';
        icon = CupertinoIcons.flame_fill;
        iconColor = CupertinoColors.systemOrange;
        break;

      case 2: // Current Activity
        final activity = _latestBiometrics['current_activity'] ?? 'No activity';
        displayValue = activity == 'No activity' ? 'Rest' : activity;
        subtitle = 'Current Activity';
        icon = _getActivityIcon(activity);
        iconColor = activity != 'No activity'
            ? CupertinoColors.systemGreen
            : CupertinoColors.systemGrey;
        break;
    }

    bool showRefreshButton = _currentActivityMetric == 2; // Only for current activity

    return Stack(
      children: [
        Container(
          width: double.infinity, // Ensure full width
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: _currentActivityMetric == 2 ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                ),
              ),
              if (progressBar != null) progressBar,
            ],
          ),
        ),
        if (showRefreshButton)
          _buildRefreshButton('activity'),
      ],
    );
  }

  Color _getSpO2Color(double spO2) {
    if (spO2 >= 95) {
      return CupertinoColors.systemGreen;
    } else if (spO2 >= 91 && spO2 <= 94) {
      return CupertinoColors.systemOrange;
    } else {
      return CupertinoColors.systemRed;
    }
  }

  Widget _buildRefreshButton(String metricKey) {
    final isRefreshing = _isRefreshing[metricKey] ?? false;
    final canRefresh = _healthKit.canRefreshMetric(metricKey);

    return Positioned(
      top: 8,
      right: 8,
      child: Column(
        children: [
          GestureDetector(
            onTap: (isRefreshing || !canRefresh) ? null : () async {
              setState(() {
                _isRefreshing[metricKey] = true;
              });

              // Add a small delay to ensure spinner is visible
              await Future.delayed(const Duration(milliseconds: 300));

              // Perform refresh with proper timeout handling
              bool success = false;

              try {
                // Call refresh based on metric type
                switch (metricKey) {
                  case 'heart_rate':
                    success = await _healthKit.refreshHeartRate();
                    break;
                  case 'hrv':
                    success = await _healthKit.refreshHRV();
                    break;
                  case 'spo2':
                    success = await _healthKit.refreshSpO2();
                    break;
                  case 'activity':
                    success = await _healthKit.refreshActivity();
                    break;
                  case 'body_temp':
                    success = await _healthKit.refreshBodyTemperature();
                    break;
                }
              } catch (e) {
                debugPrint('Error during refresh: $e');
                success = false;
              }

              // Always update UI state when done
              if (!mounted) return;

              setState(() {
                _isRefreshing[metricKey] = false;
                _lastRefreshTime[metricKey] = DateTime.now();
                if (success) {
                  _latestBiometrics = _healthKit.latestHealthData;
                }
              });

              // Show appropriate message
              if (!success && mounted) {
                // Use context safely with a try-catch
                try {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No reading obtained'),
                        duration: Duration(seconds: 3),
                        backgroundColor: CupertinoColors.systemOrange,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Could not show snackbar: $e');
                }
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: isRefreshing
                    ? const CupertinoActivityIndicator(
                        radius: 10,
                        color: CupertinoColors.black,
                      )
                    : Icon(
                        CupertinoIcons.arrow_clockwise,
                        size: 18,
                        color: canRefresh
                            ? CupertinoColors.black
                            : CupertinoColors.black.withOpacity(0.3),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Vitals',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildVitalRow('Heart Rate', '${_latestBiometrics['heart_rate']?.toStringAsFixed(0) ?? '--'} bpm', CupertinoIcons.heart),
              const Divider(),
              _buildVitalRow('HRV', '${_latestBiometrics['heart_rate_variability']?.toStringAsFixed(0) ?? '--'} ms', CupertinoIcons.waveform),
              const Divider(),
              _buildVitalRow('Blood Oxygen', '${_latestBiometrics['blood_oxygen']?.toStringAsFixed(0) ?? '--'}%', CupertinoIcons.drop),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVitalRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CupertinoColors.systemGrey),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            setState(() {
              _currentActivityMetric = (_currentActivityMetric + 1) % 3;
            });
          },
          child: _buildActivityDisplay(),
        ),
      ],
    );
  }

  Widget _buildActivityDisplay() {
    // Calculate calories burned
    final caloriesBurned = CalorieService.calculateCaloriesBurned(
      profile: _profile,
      activeEnergyFromHealthKit: _latestBiometrics['active_energy']?.toDouble(),
      heartRate: _latestBiometrics['heart_rate']?.toDouble(),
      steps: _latestBiometrics['steps']?.toInt(),
      currentActivity: _latestBiometrics['current_activity'],
    );

    String title = '';
    String value = '';
    String subtitle = '';
    IconData icon = CupertinoIcons.flame;
    Color color = CupertinoColors.systemOrange;

    switch (_currentActivityMetric) {
      case 0: // Steps
        final steps = _latestBiometrics['steps']?.toInt() ?? 0;
        title = 'Steps Today';
        value = steps.toString();
        subtitle = 'Goal: 10,000';
        icon = CupertinoIcons.flame;
        color = CupertinoColors.systemOrange;

        // Add progress indicator
        final progress = (steps / 10000).clamp(0.0, 1.0);
        return _buildActivityCardWithProgress(
          title, value, subtitle, icon, color, progress
        );

      case 1: // Calories
        title = 'Calories Burned';
        value = caloriesBurned.toStringAsFixed(0);
        subtitle = 'Since midnight';
        icon = CupertinoIcons.flame_fill;
        color = CupertinoColors.systemRed;

        // Calculate progress against daily goal
        final dailyGoal = _profile.hasRequiredData
            ? CalorieService.calculateTDEE(_profile, 'moderate') * 0.3  // 30% of TDEE for active calories
            : 500.0;
        final progress = (caloriesBurned / dailyGoal).clamp(0.0, 1.0);
        return _buildActivityCardWithProgress(
          title, value, subtitle, icon, color, progress
        );

      case 2: // Current Activity
        final activity = _latestBiometrics['current_activity'] ?? 'No activity';
        title = 'Current Activity';
        value = activity;
        subtitle = activity != 'No activity' ? 'Active now' : 'Start a workout';
        icon = _getActivityIcon(activity);
        color = activity != 'No activity'
            ? CupertinoColors.systemGreen
            : CupertinoColors.systemGrey;
        return _buildActivityCardSimple(title, value, subtitle, icon, color);

      default:
        return const SizedBox();
    }
  }

  IconData _getActivityIcon(String? activity) {
    if (activity == null) return CupertinoIcons.circle;

    switch (activity.toLowerCase()) {
      case 'walking':
        return CupertinoIcons.person_fill;
      case 'running':
        return CupertinoIcons.hare_fill;
      case 'cycling':
        return CupertinoIcons.car_fill;
      case 'swimming':
        return CupertinoIcons.drop_fill;
      case 'elliptical':
      case 'rowing':
        return CupertinoIcons.arrow_right_arrow_left;
      case 'stairs':
        return CupertinoIcons.arrow_up_right;
      default:
        return CupertinoIcons.sportscourt_fill;
    }
  }

  Widget _buildActivityCardWithProgress(
    String title, String value, String subtitle,
    IconData icon, Color color, double progress
  ) {
    return Container(
      width: double.infinity, // Ensure full width
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: CupertinoColors.systemGrey5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCardSimple(
    String title, String value, String subtitle,
    IconData icon, Color color
  ) {
    return Container(
      width: double.infinity, // Ensure full width
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: value.length > 10 ? 24 : 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRecommendations() {
    final recommendations = _scoreService.getRecommendations(_currentScores);
    
    if (recommendations.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommendations',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...recommendations.map((rec) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.lightbulb,
                color: CupertinoColors.systemYellow,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(rec)),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        setState(() {
          _profile = UserProfile.fromJson(jsonDecode(profileJson));
          _nameController.text = _profile.name ?? '';
          _emailController.text = _profile.email ?? '';
          if (_profile.useImperialUnits) {
            _heightController.text = '${_profile.heightFeetInt ?? ''}\'${_profile.heightInchesRemainder ?? ''}"';
            _weightController.text = _profile.weightLbs?.toStringAsFixed(1) ?? '';
          } else {
            _heightController.text = _profile.heightCm?.toStringAsFixed(0) ?? '';
            _weightController.text = _profile.weightKg?.toStringAsFixed(1) ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    try {
      // Dismiss keyboard first
      FocusScope.of(context).unfocus();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', jsonEncode(_profile.toJson()));

      // Show success message
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: const Text('Profile saved successfully'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      _showError('Failed to save profile');
    }
  }

  Widget _buildProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showProfile = !_showProfile;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'User Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  _showProfile ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                  color: CupertinoColors.systemGrey,
                ),
              ],
            ),
          ),
        ),
        if (_showProfile) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildProfileField('Name', _nameController, (value) {
                  _profile.name = value;
                }),
                const Divider(),
                _buildProfileField('Email', _emailController, (value) {
                  _profile.email = value;
                }, keyboardType: TextInputType.emailAddress),
                const Divider(),
                _buildGenderSelector(),
                const Divider(),
                _buildDateOfBirthPicker(),
                const Divider(),
                _buildUnitToggle(),
                const Divider(),
                _buildProfileField(
                  _profile.useImperialUnits ? 'Height (ft\'in")' : 'Height (cm)',
                  _heightController,
                  (value) {
                    if (_profile.useImperialUnits) {
                      // Parse feet and inches
                      final parts = value.replaceAll('"', '').split('\'');
                      if (parts.length == 2) {
                        final feet = int.tryParse(parts[0]) ?? 0;
                        final inches = int.tryParse(parts[1]) ?? 0;
                        _profile.heightCm = (feet * 30.48) + (inches * 2.54);
                      }
                    } else {
                      _profile.heightCm = double.tryParse(value);
                    }
                  },
                ),
                const Divider(),
                _buildProfileField(
                  _profile.useImperialUnits ? 'Weight (lbs)' : 'Weight (kg)',
                  _weightController,
                  (value) {
                    if (_profile.useImperialUnits) {
                      final lbs = double.tryParse(value);
                      if (lbs != null) {
                        _profile.weightKg = lbs / 2.20462;
                      }
                    } else {
                      _profile.weightKg = double.tryParse(value);
                    }
                  },
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  child: const Text('Save Profile'),
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileField(String label, TextEditingController controller, Function(String) onChanged, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'Enter $label',
              keyboardType: keyboardType,
              onChanged: onChanged,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 100,
            child: Text('Gender'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoSegmentedControl<String>(
              groupValue: _profile.gender,
              children: const {
                'male': Text('Male'),
                'female': Text('Female'),
                'other': Text('Other'),
              },
              onValueChanged: (value) {
                setState(() {
                  _profile.gender = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateOfBirthPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 100,
            child: Text('Date of Birth'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _profile.dateOfBirth != null
                          ? '${_profile.dateOfBirth!.month}/${_profile.dateOfBirth!.day}/${_profile.dateOfBirth!.year}'
                          : 'Select date',
                      style: TextStyle(
                        color: _profile.dateOfBirth != null
                            ? CupertinoColors.label
                            : CupertinoColors.placeholderText,
                      ),
                    ),
                    const Icon(CupertinoIcons.calendar, size: 20),
                  ],
                ),
              ),
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => Container(
                    height: 216,
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: _profile.dateOfBirth ?? DateTime(1990, 1, 1),
                      maximumDate: DateTime.now(),
                      minimumDate: DateTime(1900),
                      onDateTimeChanged: (date) {
                        setState(() {
                          _profile.dateOfBirth = date;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 100,
            child: Text('Units'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoSegmentedControl<bool>(
              groupValue: _profile.useImperialUnits,
              children: const {
                false: Text('Metric'),
                true: Text('Imperial'),
              },
              onValueChanged: (value) {
                setState(() {
                  _profile.useImperialUnits = value ?? false;
                  // Update text fields with converted values
                  if (_profile.useImperialUnits) {
                    _heightController.text = '${_profile.heightFeetInt ?? ''}\'${_profile.heightInchesRemainder ?? ''}"';
                    _weightController.text = _profile.weightLbs?.toStringAsFixed(1) ?? '';
                  } else {
                    _heightController.text = _profile.heightCm?.toStringAsFixed(0) ?? '';
                    _weightController.text = _profile.weightKg?.toStringAsFixed(1) ?? '';
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncPromptBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemBlue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.cloud_upload,
            color: CupertinoColors.systemBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enable Cloud Sync',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Sign in to sync your health data across devices',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minSize: 0,
            color: CupertinoColors.systemBlue,
            borderRadius: BorderRadius.circular(8),
            onPressed: () async {
              // Navigate to login screen
              final result = await Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );

              if (result == true && mounted) {
                // Refresh the UI after successful login
                setState(() {});
                _syncService.startAutoSync();
              }
            },
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _healthKit.stopDataCollection();
    _refreshTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}