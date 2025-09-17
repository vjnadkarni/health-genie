class UserProfile {
  String? name;
  String? gender; // 'male', 'female', 'other'
  String? email;
  DateTime? dateOfBirth;
  double? heightCm; // Store in cm, convert for display
  double? weightKg; // Store in kg, convert for display
  bool useImperialUnits; // For display preferences

  UserProfile({
    this.name,
    this.gender,
    this.email,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.useImperialUnits = false,
  });

  // Calculate age from date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  // Height conversions
  double? get heightFeet {
    if (heightCm == null) return null;
    return heightCm! / 30.48; // cm to feet
  }

  int? get heightFeetInt {
    if (heightFeet == null) return null;
    return heightFeet!.floor();
  }

  int? get heightInchesRemainder {
    if (heightFeet == null) return null;
    return ((heightFeet! - heightFeetInt!) * 12).round();
  }

  // Weight conversions
  double? get weightLbs {
    if (weightKg == null) return null;
    return weightKg! * 2.20462; // kg to lbs
  }

  // Convert from JSON (for SharedPreferences)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'],
      gender: json['gender'],
      email: json['email'],
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'])
          : null,
      heightCm: json['heightCm']?.toDouble(),
      weightKg: json['weightKg']?.toDouble(),
      useImperialUnits: json['useImperialUnits'] ?? false,
    );
  }

  // Convert to JSON (for SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender,
      'email': email,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'heightCm': heightCm,
      'weightKg': weightKg,
      'useImperialUnits': useImperialUnits,
    };
  }

  // Check if profile has minimum required data
  bool get hasRequiredData {
    return name != null &&
           gender != null &&
           dateOfBirth != null &&
           heightCm != null &&
           weightKg != null;
  }
}