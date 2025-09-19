import 'dart:math';
import 'package:flutter/material.dart';
import 'database_service.dart';

/// Long-term health scoring service that uses rolling averages and personal baselines
class LongTermHealthScoreService {
  static final LongTermHealthScoreService _instance =
      LongTermHealthScoreService._internal();
  factory LongTermHealthScoreService() => _instance;
  LongTermHealthScoreService._internal();

  final DatabaseService _database = DatabaseService();

  // Score category weights (sum to 1.0)
  static const Map<String, double> categoryWeights = {
    'cardiovascular': 0.25,
    'sleep': 0.20,
    'activity': 0.20,
    'stress': 0.20,
    'readiness': 0.15,
  };

  /// Calculate comprehensive health score based on long-term data
  Future<Map<String, dynamic>> calculateLongTermHealthScore() async {
    final now = DateTime.now();

    // Get data for different time windows
    final last24Hours = await _database.getBiometricsInRange(
      now.subtract(const Duration(hours: 24)),
      now,
    );

    final last7Days = await _database.getBiometricsInRange(
      now.subtract(const Duration(days: 7)),
      now,
    );

    final last30Days = await _database.getBiometricsInRange(
      now.subtract(const Duration(days: 30)),
      now,
    );

    // Check data availability
    final dataQuality = _assessDataQuality(last24Hours, last7Days, last30Days);

    if (dataQuality['confidence'] < 0.3) {
      // Insufficient data for meaningful scoring
      return {
        'overall': 50.0,
        'cardiovascular': 50.0,
        'sleep': 50.0,
        'activity': 50.0,
        'stress': 50.0,
        'readiness': 50.0,
        'confidence': dataQuality['confidence'],
        'message': 'Insufficient data. Wear your watch more for accurate scoring.',
      };
    }

    // Calculate personal baselines from 30-day data
    final baselines = _calculateBaselines(last30Days);

    // Calculate weighted averages for recent data
    final recentMetrics = _calculateWeightedAverages(last24Hours, last7Days);

    // Score each component
    final scores = {
      'cardiovascular': _scoreCardiovascular(recentMetrics, baselines, last7Days),
      'sleep': _scoreSleep(last7Days),
      'activity': _scoreActivity(last7Days, baselines),
      'stress': _scoreStress(recentMetrics, baselines, last7Days),
      'readiness': _scoreReadiness(last24Hours, baselines),
    };

    // Calculate overall score
    double overallScore = 0.0;
    scores.forEach((key, value) {
      if (categoryWeights.containsKey(key)) {
        overallScore += value * categoryWeights[key]!;
      }
    });

    return {
      'overall': overallScore,
      ...scores,
      'confidence': dataQuality['confidence'],
      'dataHours': dataQuality['wearHours'],
      'baselines': baselines,
    };
  }

  /// Assess data quality and calculate confidence score
  Map<String, dynamic> _assessDataQuality(
    List<Map<String, dynamic>> last24Hours,
    List<Map<String, dynamic>> last7Days,
    List<Map<String, dynamic>> last30Days,
  ) {
    // Calculate wear time (assuming data point every 15 seconds when worn)
    final expectedDaily = 24 * 60 * 4; // 5760 points per day if worn 24/7
    final actual24h = last24Hours.length;
    final actual7d = last7Days.length;
    final actual30d = last30Days.length;

    final wearRatio24h = actual24h / expectedDaily;
    final wearRatio7d = actual7d / (expectedDaily * 7);
    final wearRatio30d = actual30d / (expectedDaily * 30);

    // Weighted confidence score
    final confidence = (wearRatio24h * 0.3) +
                       (wearRatio7d * 0.4) +
                       (wearRatio30d * 0.3);

    return {
      'confidence': min(1.0, confidence),
      'wearHours': (actual24h / 240).round(), // Convert to hours
      'coverage24h': wearRatio24h,
      'coverage7d': wearRatio7d,
      'coverage30d': wearRatio30d,
    };
  }

  /// Calculate personal baselines from 30-day data
  Map<String, double> _calculateBaselines(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _getDefaultBaselines();
    }

    // Calculate averages for baseline metrics
    double totalRHR = 0, totalHRV = 0, totalSteps = 0;
    int rhrCount = 0, hrvCount = 0, stepCount = 0;

    for (var record in data) {
      if (record['resting_heart_rate'] != null) {
        totalRHR += record['resting_heart_rate'];
        rhrCount++;
      }
      if (record['heart_rate_variability'] != null) {
        totalHRV += record['heart_rate_variability'];
        hrvCount++;
      }
      if (record['steps'] != null) {
        totalSteps += record['steps'];
        stepCount++;
      }
    }

    return {
      'resting_hr': rhrCount > 0 ? totalRHR / rhrCount : 65.0,
      'hrv': hrvCount > 0 ? totalHRV / hrvCount : 40.0,
      'daily_steps': stepCount > 0 ? totalSteps / stepCount : 7500.0,
      'sleep_hours': 7.5, // Default, will calculate from sleep data
    };
  }

  /// Get default baselines for new users
  Map<String, double> _getDefaultBaselines() {
    return {
      'resting_hr': 65.0,
      'hrv': 40.0,
      'daily_steps': 7500.0,
      'sleep_hours': 7.5,
    };
  }

  /// Calculate weighted averages (recent data weighted more heavily)
  Map<String, double> _calculateWeightedAverages(
    List<Map<String, dynamic>> last24Hours,
    List<Map<String, dynamic>> last7Days,
  ) {
    final metrics = <String, double>{};

    // Group by metric and calculate weighted average
    final metricsToAverage = [
      'heart_rate', 'resting_heart_rate', 'heart_rate_variability',
      'blood_oxygen', 'steps', 'active_energy', 'distance'
    ];

    for (String metric in metricsToAverage) {
      double weighted24h = _calculateAverage(last24Hours, metric) * 0.7;
      double weighted7d = _calculateAverage(last7Days, metric) * 0.3;
      metrics[metric] = weighted24h + weighted7d;
    }

    return metrics;
  }

  /// Calculate average for a specific metric
  double _calculateAverage(List<Map<String, dynamic>> data, String metric) {
    if (data.isEmpty) return 0.0;

    double total = 0;
    int count = 0;

    for (var record in data) {
      if (record[metric] != null) {
        // Skip exercise periods for resting metrics
        if (metric.contains('resting') || metric == 'heart_rate_variability') {
          final activity = record['current_activity'] as String?;
          if (activity != null && activity != 'No activity' &&
              activity.toLowerCase() != 'rest') {
            continue; // Skip this reading
          }
        }
        total += record[metric];
        count++;
      }
    }

    return count > 0 ? total / count : 0.0;
  }

  /// Score cardiovascular health based on long-term trends
  double _scoreCardiovascular(
    Map<String, double> metrics,
    Map<String, double> baselines,
    List<Map<String, dynamic>> weekData,
  ) {
    double score = 100.0;

    // Resting Heart Rate vs baseline
    final rhr = metrics['resting_heart_rate'] ?? baselines['resting_hr']!;
    final rhrBaseline = baselines['resting_hr']!;
    final rhrDeviation = ((rhr - rhrBaseline) / rhrBaseline * 100).abs();

    if (rhrDeviation <= 5) {
      // Within normal variation
    } else if (rhrDeviation <= 10) {
      score -= 10;
    } else if (rhrDeviation <= 15) {
      score -= 20;
    } else {
      score -= 30;
    }

    // HRV vs baseline (higher is better)
    final hrv = metrics['heart_rate_variability'] ?? baselines['hrv']!;
    final hrvBaseline = baselines['hrv']!;
    final hrvRatio = hrv / hrvBaseline;

    if (hrvRatio >= 1.0) {
      // At or above baseline - good
    } else if (hrvRatio >= 0.85) {
      score -= 10;
    } else if (hrvRatio >= 0.70) {
      score -= 20;
    } else {
      score -= 35;
    }

    // Blood oxygen average
    final spo2 = metrics['blood_oxygen'] ?? 97.0;
    if (spo2 >= 95) {
      // Normal
    } else if (spo2 >= 92) {
      score -= 15;
    } else {
      score -= 30;
    }

    // Calculate trend (improving/declining)
    final trend = _calculateTrend(weekData, 'resting_heart_rate');
    if (trend < -0.5) {
      score += 5; // Improving
    } else if (trend > 1.0) {
      score -= 10; // Declining
    }

    return max(0, min(100, score));
  }

  /// Score sleep quality based on 7-day patterns
  double _scoreSleep(List<Map<String, dynamic>> weekData) {
    double score = 100.0;

    // Group data by day and calculate nightly sleep
    final sleepByDay = <DateTime, double>{};

    for (var record in weekData) {
      final date = DateTime.parse(record['timestamp']);
      final dayKey = DateTime(date.year, date.month, date.day);

      final sleepTotal = record['sleep_total'] as double? ?? 0;
      if (sleepTotal > 0) {
        sleepByDay[dayKey] = sleepTotal;
      }
    }

    if (sleepByDay.isEmpty) {
      return 50.0; // No sleep data
    }

    // Calculate average sleep duration
    final avgSleep = sleepByDay.values.reduce((a, b) => a + b) /
                     sleepByDay.length / 60; // Convert to hours

    if (avgSleep >= 7 && avgSleep <= 9) {
      // Optimal
    } else if (avgSleep >= 6 && avgSleep < 7) {
      score -= 15;
    } else if (avgSleep >= 5 && avgSleep < 6) {
      score -= 30;
    } else if (avgSleep < 5) {
      score -= 45;
    } else if (avgSleep > 9) {
      score -= 10; // Oversleeping
    }

    // Calculate sleep consistency (standard deviation)
    if (sleepByDay.length > 2) {
      final sleepTimes = sleepByDay.values.toList();
      final mean = sleepTimes.reduce((a, b) => a + b) / sleepTimes.length;
      final variance = sleepTimes
          .map((x) => pow(x - mean, 2))
          .reduce((a, b) => a + b) / sleepTimes.length;
      final stdDev = sqrt(variance) / 60; // Convert to hours

      if (stdDev <= 0.5) {
        // Very consistent
      } else if (stdDev <= 1.0) {
        score -= 10;
      } else if (stdDev <= 1.5) {
        score -= 20;
      } else {
        score -= 30;
      }
    }

    return max(0, min(100, score));
  }

  /// Score activity levels and consistency
  double _scoreActivity(
    List<Map<String, dynamic>> weekData,
    Map<String, double> baselines,
  ) {
    double score = 100.0;

    // Group by day for daily totals
    final stepsByDay = <DateTime, double>{};
    final energyByDay = <DateTime, double>{};

    for (var record in weekData) {
      final date = DateTime.parse(record['timestamp']);
      final dayKey = DateTime(date.year, date.month, date.day);

      final steps = record['steps'] as double? ?? 0;
      final energy = record['active_energy'] as double? ?? 0;

      stepsByDay[dayKey] = (stepsByDay[dayKey] ?? 0) + steps;
      energyByDay[dayKey] = (energyByDay[dayKey] ?? 0) + energy;
    }

    if (stepsByDay.isEmpty) {
      return 50.0; // No activity data
    }

    // Average daily steps vs baseline
    final avgSteps = stepsByDay.values.reduce((a, b) => a + b) /
                     stepsByDay.length;
    final stepGoal = baselines['daily_steps'] ?? 7500;
    final stepRatio = avgSteps / stepGoal;

    if (stepRatio >= 1.0) {
      // Meeting or exceeding goal
    } else if (stepRatio >= 0.75) {
      score -= 15;
    } else if (stepRatio >= 0.50) {
      score -= 30;
    } else {
      score -= 45;
    }

    // Activity consistency (how many days active)
    final activeDays = stepsByDay.values.where((s) => s >= 5000).length;
    final activityRate = activeDays / 7;

    if (activityRate >= 0.85) {
      // Active most days
    } else if (activityRate >= 0.7) {
      score -= 10;
    } else if (activityRate >= 0.5) {
      score -= 20;
    } else {
      score -= 30;
    }

    return max(0, min(100, score));
  }

  /// Score stress levels based on HRV and HR patterns
  double _scoreStress(
    Map<String, double> metrics,
    Map<String, double> baselines,
    List<Map<String, dynamic>> weekData,
  ) {
    double score = 100.0;

    // HRV as primary stress indicator
    final hrv = metrics['heart_rate_variability'] ?? baselines['hrv']!;
    final hrvBaseline = baselines['hrv']!;
    final hrvRatio = hrv / hrvBaseline;

    if (hrvRatio >= 0.95) {
      // Low stress
    } else if (hrvRatio >= 0.80) {
      score -= 15;
    } else if (hrvRatio >= 0.65) {
      score -= 30;
    } else {
      score -= 45;
    }

    // Check for elevated resting HR (stress indicator)
    final rhr = metrics['resting_heart_rate'] ?? baselines['resting_hr']!;
    final rhrBaseline = baselines['resting_hr']!;

    if (rhr > rhrBaseline + 5) {
      score -= 20; // Elevated stress
    } else if (rhr > rhrBaseline + 3) {
      score -= 10;
    }

    // HRV trend (declining HRV indicates increasing stress)
    final hrvTrend = _calculateTrend(weekData, 'heart_rate_variability');
    if (hrvTrend < -2) {
      score -= 15; // Declining HRV
    } else if (hrvTrend > 2) {
      score += 5; // Improving HRV
    }

    return max(0, min(100, score));
  }

  /// Score readiness for today based on recent recovery
  double _scoreReadiness(
    List<Map<String, dynamic>> last24Hours,
    Map<String, double> baselines,
  ) {
    double score = 100.0;

    if (last24Hours.isEmpty) {
      return 50.0;
    }

    // Get most recent morning HRV and RHR
    final morningData = _getMorningData(last24Hours);

    if (morningData != null) {
      // Morning HRV vs baseline
      final morningHRV = morningData['heart_rate_variability'] as double?;
      if (morningHRV != null) {
        final hrvRatio = morningHRV / baselines['hrv']!;
        if (hrvRatio >= 1.0) {
          // Ready
        } else if (hrvRatio >= 0.85) {
          score -= 15;
        } else if (hrvRatio >= 0.70) {
          score -= 30;
        } else {
          score -= 45;
        }
      }

      // Morning RHR vs baseline
      final morningRHR = morningData['resting_heart_rate'] as double?;
      if (morningRHR != null) {
        final rhrDiff = morningRHR - baselines['resting_hr']!;
        if (rhrDiff <= 2) {
          // Normal
        } else if (rhrDiff <= 5) {
          score -= 15;
        } else {
          score -= 25;
        }
      }
    }

    // Check last night's sleep
    final sleepQuality = _getLastNightSleep(last24Hours);
    if (sleepQuality < 6) {
      score -= 20; // Poor sleep
    } else if (sleepQuality < 7) {
      score -= 10;
    }

    return max(0, min(100, score));
  }

  /// Get morning data (6-10 AM readings)
  Map<String, dynamic>? _getMorningData(List<Map<String, dynamic>> data) {
    final now = DateTime.now();
    final morning6am = DateTime(now.year, now.month, now.day, 6, 0);
    final morning10am = DateTime(now.year, now.month, now.day, 10, 0);

    for (var record in data.reversed) {
      final timestamp = DateTime.parse(record['timestamp']);
      if (timestamp.isAfter(morning6am) && timestamp.isBefore(morning10am)) {
        return record;
      }
    }

    return null;
  }

  /// Get last night's sleep duration
  double _getLastNightSleep(List<Map<String, dynamic>> data) {
    double maxSleep = 0;

    for (var record in data) {
      final sleep = record['sleep_total'] as double? ?? 0;
      if (sleep > maxSleep) {
        maxSleep = sleep;
      }
    }

    return maxSleep / 60; // Convert to hours
  }

  /// Calculate trend for a metric (positive = increasing, negative = decreasing)
  double _calculateTrend(List<Map<String, dynamic>> data, String metric) {
    if (data.length < 2) return 0.0;

    final values = <double>[];
    for (var record in data) {
      if (record[metric] != null) {
        values.add(record[metric].toDouble());
      }
    }

    if (values.length < 2) return 0.0;

    // Simple linear regression
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < values.length; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }

    final n = values.length;
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

    return slope;
  }

  /// Get health status from score
  String getHealthStatus(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 40) return 'Needs Attention';
    return 'Poor';
  }

  /// Get color for score visualization
  Color getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.yellow[700]!;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}