import 'dart:math';
import 'package:flutter/material.dart';

class HealthScoreService {
  static final HealthScoreService _instance = HealthScoreService._internal();
  factory HealthScoreService() => _instance;
  HealthScoreService._internal();

  // Score category weights (sum to 1.0)
  static const Map<String, double> categoryWeights = {
    'cardiovascular': 0.25,
    'sleep': 0.20,
    'activity': 0.20,
    'recovery': 0.20,
    'stress': 0.15,
  };

  /// Calculate overall health score from biometric data
  Map<String, double> calculateHealthScore(Map<String, dynamic> biometrics) {
    // Calculate individual category scores
    final cardiovascularScore = _calculateCardiovascularScore(biometrics);
    final sleepScore = _calculateSleepScore(biometrics);
    final activityScore = _calculateActivityScore(biometrics);
    final recoveryScore = _calculateRecoveryScore(biometrics);
    final stressScore = _calculateStressScore(biometrics);

    // Calculate weighted overall score
    final overallScore = (cardiovascularScore * categoryWeights['cardiovascular']!) +
                        (sleepScore * categoryWeights['sleep']!) +
                        (activityScore * categoryWeights['activity']!) +
                        (recoveryScore * categoryWeights['recovery']!) +
                        (stressScore * categoryWeights['stress']!);

    return {
      'overall': overallScore,
      'cardiovascular': cardiovascularScore,
      'sleep': sleepScore,
      'activity': activityScore,
      'recovery': recoveryScore,
      'stress': stressScore,
    };
  }

  /// Calculate cardiovascular health score (0-100)
  double _calculateCardiovascularScore(Map<String, dynamic> data) {
    double score = 100.0;
    
    // Heart Rate scoring
    final heartRate = data['heart_rate'] as double?;
    if (heartRate != null) {
      // Optimal resting heart rate: 60-80 bpm
      if (heartRate >= 60 && heartRate <= 80) {
        // Perfect range
      } else if (heartRate >= 50 && heartRate < 60) {
        score -= 5; // Athletic range
      } else if (heartRate > 80 && heartRate <= 90) {
        score -= 10; // Slightly elevated
      } else if (heartRate > 90 && heartRate <= 100) {
        score -= 20; // Elevated
      } else if (heartRate > 100) {
        score -= 30; // High
      } else if (heartRate < 50) {
        score -= 15; // Very low
      }
    } else {
      score -= 10; // No data penalty
    }

    // Heart Rate Variability scoring
    final hrv = data['heart_rate_variability'] as double?;
    if (hrv != null) {
      // Higher HRV is generally better (in ms)
      if (hrv >= 50) {
        // Excellent
      } else if (hrv >= 40) {
        score -= 5;
      } else if (hrv >= 30) {
        score -= 10;
      } else if (hrv >= 20) {
        score -= 20;
      } else {
        score -= 30;
      }
    } else {
      score -= 10; // No data penalty
    }

    // Blood Oxygen scoring
    final bloodOxygen = data['blood_oxygen'] as double?;
    if (bloodOxygen != null) {
      // Normal SpO2: 95-100%
      if (bloodOxygen >= 95) {
        // Normal
      } else if (bloodOxygen >= 92) {
        score -= 15;
      } else if (bloodOxygen >= 88) {
        score -= 30;
      } else {
        score -= 50; // Critical
      }
    } else {
      score -= 5; // No data penalty (less critical)
    }

    return max(0, min(100, score));
  }

  /// Calculate sleep quality score (0-100)
  double _calculateSleepScore(Map<String, dynamic> data) {
    double score = 100.0;
    
    // Check if sleep data exists
    final sleepData = data['sleep_analysis'] as Map<String, dynamic>?;
    if (sleepData == null) {
      return 50.0; // Default if no sleep data
    }

    final totalSleep = sleepData['total_sleep_time'] as double? ?? 0;
    final deepSleep = sleepData['deep_sleep'] as double? ?? 0;
    final remSleep = sleepData['rem_sleep'] as double? ?? 0;
    final awakeTime = sleepData['awake'] as double? ?? 0;

    // Total sleep duration (in minutes)
    // Optimal: 420-540 minutes (7-9 hours)
    if (totalSleep >= 420 && totalSleep <= 540) {
      // Optimal range
    } else if (totalSleep >= 360 && totalSleep < 420) {
      score -= 10; // 6-7 hours
    } else if (totalSleep > 540 && totalSleep <= 600) {
      score -= 10; // 9-10 hours
    } else if (totalSleep < 360) {
      score -= 30; // Less than 6 hours
    } else {
      score -= 20; // More than 10 hours
    }

    // Deep sleep percentage (should be 15-20% of total)
    if (totalSleep > 0) {
      final deepSleepPercent = (deepSleep / totalSleep) * 100;
      if (deepSleepPercent >= 15 && deepSleepPercent <= 20) {
        // Optimal
      } else if (deepSleepPercent >= 10 && deepSleepPercent < 15) {
        score -= 10;
      } else if (deepSleepPercent > 20 && deepSleepPercent <= 25) {
        score -= 5;
      } else {
        score -= 20;
      }

      // REM sleep percentage (should be 20-25% of total)
      final remSleepPercent = (remSleep / totalSleep) * 100;
      if (remSleepPercent >= 20 && remSleepPercent <= 25) {
        // Optimal
      } else if (remSleepPercent >= 15 && remSleepPercent < 20) {
        score -= 10;
      } else if (remSleepPercent > 25 && remSleepPercent <= 30) {
        score -= 5;
      } else {
        score -= 15;
      }

      // Wake time during sleep
      final awakePercent = (awakeTime / (totalSleep + awakeTime)) * 100;
      if (awakePercent <= 5) {
        // Minimal disruption
      } else if (awakePercent <= 10) {
        score -= 10;
      } else if (awakePercent <= 15) {
        score -= 20;
      } else {
        score -= 30;
      }
    }

    return max(0, min(100, score));
  }

  /// Calculate activity level score (0-100)
  double _calculateActivityScore(Map<String, dynamic> data) {
    double score = 100.0;
    
    // Steps scoring
    final steps = data['steps'] as double? ?? 0;
    if (steps >= 10000) {
      // Excellent
    } else if (steps >= 7500) {
      score -= 10;
    } else if (steps >= 5000) {
      score -= 20;
    } else if (steps >= 2500) {
      score -= 35;
    } else {
      score -= 50;
    }

    // Distance scoring (in meters)
    final distance = data['distance'] as double? ?? 0;
    if (distance >= 8000) {
      // About 5 miles
    } else if (distance >= 6000) {
      score -= 10;
    } else if (distance >= 4000) {
      score -= 20;
    } else if (distance >= 2000) {
      score -= 30;
    } else {
      score -= 40;
    }

    // Active energy burned (in kcal)
    final activeEnergy = data['active_energy'] as double? ?? 0;
    if (activeEnergy >= 500) {
      // Good activity level
    } else if (activeEnergy >= 350) {
      score -= 10;
    } else if (activeEnergy >= 200) {
      score -= 20;
    } else if (activeEnergy >= 100) {
      score -= 30;
    } else {
      score -= 40;
    }

    // Average the penalties
    return max(0, min(100, score));
  }

  /// Calculate recovery score (0-100)
  double _calculateRecoveryScore(Map<String, dynamic> data) {
    double score = 100.0;
    
    // Resting heart rate (lower is generally better for recovery)
    final restingHR = data['resting_heart_rate'] as double?;
    if (restingHR != null) {
      if (restingHR <= 60) {
        // Excellent recovery
      } else if (restingHR <= 70) {
        score -= 10;
      } else if (restingHR <= 80) {
        score -= 20;
      } else {
        score -= 35;
      }
    } else {
      score -= 15;
    }

    // HRV is a good indicator of recovery
    final hrv = data['heart_rate_variability'] as double?;
    if (hrv != null) {
      if (hrv >= 60) {
        // Excellent recovery
      } else if (hrv >= 45) {
        score -= 10;
      } else if (hrv >= 30) {
        score -= 25;
      } else {
        score -= 40;
      }
    } else {
      score -= 15;
    }

    // Body temperature (deviation from normal)
    final bodyTemp = data['body_temperature'] as double?;
    if (bodyTemp != null) {
      // Normal range: 36.5-37.5°C (97.7-99.5°F)
      if (bodyTemp >= 36.5 && bodyTemp <= 37.5) {
        // Normal
      } else if ((bodyTemp >= 36.0 && bodyTemp < 36.5) || 
                 (bodyTemp > 37.5 && bodyTemp <= 38.0)) {
        score -= 15;
      } else {
        score -= 30;
      }
    } else {
      score -= 10;
    }

    return max(0, min(100, score));
  }

  /// Calculate stress score (0-100, higher is better/less stressed)
  double _calculateStressScore(Map<String, dynamic> data) {
    double score = 100.0;
    
    // HRV is a primary indicator of stress
    final hrv = data['heart_rate_variability'] as double?;
    if (hrv != null) {
      if (hrv >= 50) {
        // Low stress
      } else if (hrv >= 35) {
        score -= 15;
      } else if (hrv >= 25) {
        score -= 30;
      } else {
        score -= 45;
      }
    } else {
      score -= 20;
    }

    // Elevated resting heart rate can indicate stress
    final restingHR = data['resting_heart_rate'] as double?;
    if (restingHR != null) {
      final heartRate = data['heart_rate'] as double? ?? restingHR;
      final hrElevation = heartRate - restingHR;
      
      if (hrElevation <= 5) {
        // Minimal elevation
      } else if (hrElevation <= 10) {
        score -= 10;
      } else if (hrElevation <= 20) {
        score -= 25;
      } else {
        score -= 35;
      }
    } else {
      score -= 15;
    }

    // Poor sleep quality increases stress
    final sleepData = data['sleep_analysis'] as Map<String, dynamic>?;
    if (sleepData != null) {
      final totalSleep = sleepData['total_sleep_time'] as double? ?? 0;
      if (totalSleep < 360) { // Less than 6 hours
        score -= 20;
      } else if (totalSleep < 420) { // Less than 7 hours
        score -= 10;
      }
    }

    return max(0, min(100, score));
  }

  /// Get health status from score
  String getHealthStatus(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 40) return 'Poor';
    return 'Critical';
  }

  /// Get color for score visualization
  Color getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.yellow[700]!;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  /// Get recommendations based on scores
  List<String> getRecommendations(Map<String, double> scores) {
    List<String> recommendations = [];

    // Cardiovascular recommendations
    if (scores['cardiovascular']! < 75) {
      recommendations.add('Consider cardiovascular exercises to improve heart health');
    }

    // Sleep recommendations
    if (scores['sleep']! < 75) {
      recommendations.add('Aim for 7-9 hours of quality sleep per night');
    }

    // Activity recommendations
    if (scores['activity']! < 75) {
      recommendations.add('Try to reach 10,000 steps daily');
    }

    // Recovery recommendations
    if (scores['recovery']! < 75) {
      recommendations.add('Include rest days and recovery activities');
    }

    // Stress recommendations
    if (scores['stress']! < 75) {
      recommendations.add('Practice stress management techniques like meditation');
    }

    return recommendations;
  }
}