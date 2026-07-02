class NutritionProfile {
  final String gender; // 'male' | 'female'
  final int age;
  final double heightCm;
  final double currentWeightKg;
  final double goalWeightKg;
  final String activityLevel; // 'sedentary' | 'light' | 'moderate' | 'active' | 'extra'
  final String unit; // 'kg' | 'lbs'

  NutritionProfile({
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.currentWeightKg,
    required this.goalWeightKg,
    required this.activityLevel,
    this.unit = 'kg',
  });

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'age': age,
        'heightCm': heightCm,
        'currentWeightKg': currentWeightKg,
        'goalWeightKg': goalWeightKg,
        'activityLevel': activityLevel,
        'unit': unit,
      };

  factory NutritionProfile.fromJson(Map<String, dynamic> json) => NutritionProfile(
        gender: json['gender'] as String? ?? 'male',
        age: json['age'] as int? ?? 25,
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170.0,
        currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble() ?? 70.0,
        goalWeightKg: (json['goalWeightKg'] as num?)?.toDouble() ?? 65.0,
        activityLevel: json['activityLevel'] as String? ?? 'moderate',
        unit: json['unit'] as String? ?? 'kg',
      );

  /// Mifflin-St Jeor BMR
  double get bmr {
    final base = 10 * currentWeightKg + 6.25 * heightCm - 5 * age;
    return gender == 'male' ? base + 5 : base - 161;
  }

  double get activityMultiplier {
    switch (activityLevel) {
      case 'sedentary':
        return 1.2;
      case 'light':
        return 1.375;
      case 'moderate':
        return 1.55;
      case 'active':
        return 1.725;
      case 'extra':
        return 1.9;
      default:
        return 1.55;
    }
  }

  double get tdee => bmr * activityMultiplier;

  double get goalWeightLbs => goalWeightKg * 2.2046;

  /// Protein goal: 2g per kg of goal weight
  double get dailyProteinGoalG => goalWeightKg * 2.0;
}

class NutritionPlan {
  final int deficitPercent;
  final double maintenanceCalories;
  final double dailyCalorieTarget;
  final double dailyProteinGoalG;
  final String startDate; // YYYY-MM-DD
  final double startWeightKg;
  final double goalWeightKg;
  final int estimatedWeeks;

  NutritionPlan({
    required this.deficitPercent,
    required this.maintenanceCalories,
    required this.dailyCalorieTarget,
    required this.dailyProteinGoalG,
    required this.startDate,
    required this.startWeightKg,
    required this.goalWeightKg,
    required this.estimatedWeeks,
  });

  Map<String, dynamic> toJson() => {
        'deficitPercent': deficitPercent,
        'maintenanceCalories': maintenanceCalories,
        'dailyCalorieTarget': dailyCalorieTarget,
        'dailyProteinGoalG': dailyProteinGoalG,
        'startDate': startDate,
        'startWeightKg': startWeightKg,
        'goalWeightKg': goalWeightKg,
        'estimatedWeeks': estimatedWeeks,
      };

  factory NutritionPlan.fromJson(Map<String, dynamic> json) => NutritionPlan(
        deficitPercent: json['deficitPercent'] as int? ?? 20,
        maintenanceCalories: (json['maintenanceCalories'] as num?)?.toDouble() ?? 2000.0,
        dailyCalorieTarget: (json['dailyCalorieTarget'] as num?)?.toDouble() ?? 1600.0,
        dailyProteinGoalG: (json['dailyProteinGoalG'] as num?)?.toDouble() ?? 140.0,
        startDate: json['startDate'] as String? ?? '',
        startWeightKg: (json['startWeightKg'] as num?)?.toDouble() ?? 70.0,
        goalWeightKg: (json['goalWeightKg'] as num?)?.toDouble() ?? 65.0,
        estimatedWeeks: json['estimatedWeeks'] as int? ?? 10,
      );

  /// Compute the target weight for a given day index (0 = start)
  double projectedWeightAtDay(int dayIndex) {
    if (estimatedWeeks == 0) return goalWeightKg;
    final totalDays = estimatedWeeks * 7.0;
    final progress = (dayIndex / totalDays).clamp(0.0, 1.0);
    return startWeightKg - (startWeightKg - goalWeightKg) * progress;
  }
}

class DailyNutritionLog {
  final String date; // YYYY-MM-DD
  final double caloriesConsumed;
  final double proteinConsumed;

  DailyNutritionLog({
    required this.date,
    required this.caloriesConsumed,
    required this.proteinConsumed,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'caloriesConsumed': caloriesConsumed,
        'proteinConsumed': proteinConsumed,
      };

  factory DailyNutritionLog.fromJson(Map<String, dynamic> json, String docId) => DailyNutritionLog(
        date: docId,
        caloriesConsumed: (json['caloriesConsumed'] as num?)?.toDouble() ?? 0.0,
        proteinConsumed: (json['proteinConsumed'] as num?)?.toDouble() ?? 0.0,
      );
}

class WeightLog {
  final String date; // YYYY-MM-DD
  final double weightKg;

  WeightLog({required this.date, required this.weightKg});

  Map<String, dynamic> toJson() => {
        'date': date,
        'weightKg': weightKg,
      };

  factory WeightLog.fromJson(Map<String, dynamic> json, String docId) => WeightLog(
        date: docId,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      );
}
