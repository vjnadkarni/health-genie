import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/healthkit_service.dart';
import '../services/database_service.dart';
import '../services/health_score_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final HealthKitService _healthKit = HealthKitService();
  final DatabaseService _database = DatabaseService();
  final HealthScoreService _scoreService = HealthScoreService();

  Map<String, double> _currentScores = {
    'overall': 0,
    'cardiovascular': 0,
    'sleep': 0,
    'activity': 0,
    'recovery': 0,
    'stress': 0,
  };

  Map<String, dynamic> _latestBiometrics = {};
  bool _isLoading = true;
  bool _isWatchConnected = false;
  Timer? _refreshTimer;

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

  @override
  void initState() {
    super.initState();
    _initializeServices();
    // Refresh UI every 5 minutes to show new data
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _loadLatestData();
    });
  }

  Future<void> _initializeServices() async {
    // Initialize HealthKit
    final initialized = await _healthKit.initialize();
    if (initialized) {
      // Start data collection
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
      
      // Calculate health scores
      _currentScores = _scoreService.calculateHealthScore(_latestBiometrics);
      debugPrint('Calculated scores: overall=${_currentScores['overall']}');
    }
    
    if (mounted) {
      setState(() {});
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
          const Text(
            'Overall Health Score',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildCategoryCard('Cardiovascular', _currentScores['cardiovascular'] ?? 0, CupertinoIcons.heart_fill),
            _buildCategoryCard('Blood Oxygen', _currentScores['sleep'] ?? 0, CupertinoIcons.drop_fill),
            _buildCategoryCard('Activity', _currentScores['activity'] ?? 0, CupertinoIcons.flame_fill),
            _buildCategoryCard('Recovery', _currentScores['recovery'] ?? 0, CupertinoIcons.battery_100),
            _buildCategoryCard('Stress', _currentScores['stress'] ?? 0, CupertinoIcons.waveform_path),
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

    switch (_currentCardioMetric) {
      case 0: // Current Heart Rate
        final hr = _latestBiometrics['heart_rate'];
        if (hr != null) {
          displayValue = '${hr.toStringAsFixed(0)} bpm';
          valueColor = _getHeartRateColor(hr.toDouble());
        }
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
        break;
    }

    return Container(
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

    switch (_currentSpO2Metric) {
      case 0: // Current Blood Oxygen
        final spO2 = _latestBiometrics['blood_oxygen'];
        if (spO2 != null) {
          displayValue = '${spO2.toStringAsFixed(0)}%';
          valueColor = _getSpO2Color(spO2.toDouble());
        }
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

    return Container(
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
              const Divider(),
              _buildVitalRow('Body Temp', '${_latestBiometrics['body_temperature']?.toStringAsFixed(1) ?? '--'}°C', CupertinoIcons.thermometer),
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
          'Today\'s Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActivityCard(
                'Steps',
                _latestBiometrics['steps']?.toStringAsFixed(0) ?? '0',
                '10,000',
                CupertinoIcons.flame,
                CupertinoColors.systemOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActivityCard(
                'Distance',
                '${((_latestBiometrics['distance'] ?? 0) / 1000).toStringAsFixed(1)} km',
                '8 km',
                CupertinoIcons.location,
                CupertinoColors.systemBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActivityCard(
                'Calories',
                _latestBiometrics['active_energy']?.toStringAsFixed(0) ?? '0',
                '500',
                CupertinoIcons.flame,
                CupertinoColors.systemRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityCard(String title, String value, String goal, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'of $goal',
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
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

  @override
  void dispose() {
    _healthKit.stopDataCollection();
    _refreshTimer?.cancel();
    super.dispose();
  }
}