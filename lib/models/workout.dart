class SetLog {
  double weight;
  int reps;
  bool completed;
  String? sprintDuration;
  String? sprintSpeed;
  String? runDuration;

  SetLog({
    required this.weight,
    required this.reps,
    this.completed = false,
    this.sprintDuration,
    this.sprintSpeed,
    this.runDuration,
  });

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'reps': reps,
        'completed': completed,
        if (sprintDuration != null) 'sprintDuration': sprintDuration,
        if (sprintSpeed != null) 'sprintSpeed': sprintSpeed,
        if (runDuration != null) 'runDuration': runDuration,
      };

  factory SetLog.fromJson(Map<String, dynamic> json) => SetLog(
        weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
        reps: json['reps'] as int? ?? 0,
        completed: json['completed'] as bool? ?? false,
        sprintDuration: json['sprintDuration'] as String?,
        sprintSpeed: json['sprintSpeed'] as String?,
        runDuration: json['runDuration'] as String?,
      );
}

class WorkoutLog {
  final String date; // YYYY-MM-DD
  final String dayOfWeek;
  final String title;
  final Map<String, List<SetLog>> exercises;
  final bool completed;

  WorkoutLog({
    required this.date,
    required this.dayOfWeek,
    required this.title,
    required this.exercises,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'dayOfWeek': dayOfWeek,
        'title': title,
        'exercises': exercises.map((key, value) =>
            MapEntry(key, value.map((s) => s.toJson()).toList())),
        'completed': completed,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> json, String docId) {
    final rawExercises = json['exercises'] as Map? ?? {};
    final parsedExercises = <String, List<SetLog>>{};
    
    rawExercises.forEach((key, value) {
      if (value is List) {
        parsedExercises[key.toString()] = value
            .map((item) => SetLog.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    });

    return WorkoutLog(
      date: docId,
      dayOfWeek: json['dayOfWeek'] as String? ?? '',
      title: json['title'] as String? ?? '',
      exercises: parsedExercises,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

class PlanExercise {
  final String name;
  final bool isCardio;

  PlanExercise({required this.name, this.isCardio = false});

  Map<String, dynamic> toJson() => {
        'name': name,
        'isCardio': isCardio,
      };

  factory PlanExercise.fromJson(dynamic json) {
    if (json is String) {
      return PlanExercise(name: json, isCardio: false);
    } else if (json is Map) {
      return PlanExercise(
        name: json['name'] as String? ?? '',
        isCardio: json['isCardio'] as bool? ?? false,
      );
    }
    return PlanExercise(name: '');
  }
}

class WorkoutPlan {
  final String title;
  final List<PlanExercise> exercises;

  WorkoutPlan({required this.title, required this.exercises});

  Map<String, dynamic> toJson() => {
        'title': title,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'] as List? ?? [];
    return WorkoutPlan(
      title: json['title'] as String? ?? '',
      exercises: rawExercises.map((e) => PlanExercise.fromJson(e)).toList(),
    );
  }
}
