import '../models/user_profile.dart';

class CalorieService {
  /// Calculate calories burned using the Mifflin-St Jeor equation and activity data
  static double calculateCaloriesBurned({
    required UserProfile profile,
    required double? activeEnergyFromHealthKit,
    double? heartRate,
    int? steps,
    String? currentActivity,
  }) {
    // If HealthKit provides active energy, use it directly
    if (activeEnergyFromHealthKit != null && activeEnergyFromHealthKit > 0) {
      return activeEnergyFromHealthKit;
    }

    // Otherwise calculate using profile data and activity
    if (!profile.hasRequiredData) {
      return 0.0;
    }

    // Calculate BMR (Basal Metabolic Rate)
    double bmr = calculateBMR(profile);

    // Get hours since midnight or app start
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final hoursSinceMidnight = now.difference(midnight).inMinutes / 60.0;

    // Base calories (BMR distributed across the day)
    double baseCalories = (bmr / 24) * hoursSinceMidnight;

    // Add activity calories based on steps
    double activityCalories = 0.0;
    if (steps != null && steps > 0) {
      // Rough estimate: 0.04 calories per step (varies by weight)
      double caloriesPerStep = 0.04 * (profile.weightKg ?? 70) / 70;
      activityCalories = steps * caloriesPerStep;
    }

    // Add extra calories for specific activities
    if (currentActivity != null) {
      activityCalories += calculateActivityCalories(
        activity: currentActivity,
        durationMinutes: 5, // Use 5 minute intervals
        weightKg: profile.weightKg ?? 70,
      );
    }

    return baseCalories + activityCalories;
  }

  /// Calculate Basal Metabolic Rate using Mifflin-St Jeor equation
  static double calculateBMR(UserProfile profile) {
    double weightKg = profile.weightKg ?? 70;
    double heightCm = profile.heightCm ?? 170;
    int age = profile.age ?? 30;

    double bmr;
    if (profile.gender == 'male') {
      // Men: BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age(years) + 5
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      // Women: BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age(years) - 161
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }

    return bmr;
  }

  /// Calculate calories burned for specific activities (MET values)
  static double calculateActivityCalories({
    required String activity,
    required double durationMinutes,
    required double weightKg,
  }) {
    // MET (Metabolic Equivalent of Task) values for activities
    double met = 1.0;

    switch (activity.toLowerCase()) {
      case 'walking':
        met = 3.5; // Moderate walking
        break;
      case 'running':
        met = 8.0; // Running at 6 mph
        break;
      case 'cycling':
        met = 7.5; // Moderate cycling
        break;
      case 'swimming':
        met = 8.0; // Moderate swimming
        break;
      case 'elliptical':
        met = 5.0; // Moderate effort
        break;
      case 'rowing':
        met = 7.0; // Moderate rowing
        break;
      case 'hiit':
        met = 8.0; // High intensity
        break;
      case 'stairs':
        met = 9.0; // Stair climbing
        break;
      default:
        met = 4.0; // General exercise
    }

    // Calories = MET × weight(kg) × time(hours)
    return met * weightKg * (durationMinutes / 60.0);
  }

  /// Calculate TDEE (Total Daily Energy Expenditure) based on activity level
  static double calculateTDEE(UserProfile profile, String activityLevel) {
    double bmr = calculateBMR(profile);
    double multiplier = 1.2; // Sedentary default

    switch (activityLevel) {
      case 'sedentary':
        multiplier = 1.2;
        break;
      case 'light':
        multiplier = 1.375;
        break;
      case 'moderate':
        multiplier = 1.55;
        break;
      case 'active':
        multiplier = 1.725;
        break;
      case 'very_active':
        multiplier = 1.9;
        break;
    }

    return bmr * multiplier;
  }
}