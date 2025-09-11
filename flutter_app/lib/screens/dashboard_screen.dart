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

  @override
  void initState() {
    super.initState();
    _initializeServices();
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
      
      // Calculate health scores
      _currentScores = _scoreService.calculateHealthScore(_latestBiometrics);
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
            _buildCategoryCard('Sleep', _currentScores['sleep'] ?? 0, CupertinoIcons.moon_fill),
            _buildCategoryCard('Activity', _currentScores['activity'] ?? 0, CupertinoIcons.flame_fill),
            _buildCategoryCard('Recovery', _currentScores['recovery'] ?? 0, CupertinoIcons.battery_100),
            _buildCategoryCard('Stress', _currentScores['stress'] ?? 0, CupertinoIcons.waveform_path),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, double score, IconData icon) {
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
    super.dispose();
  }
}