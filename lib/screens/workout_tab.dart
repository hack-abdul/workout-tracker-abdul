import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../services/firebase_service.dart';
import '../widgets/exercise_card.dart';

class WorkoutTab extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> preferences;

  const WorkoutTab({
    super.key,
    required this.userId,
    required this.preferences,
  });

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  final FirebaseService _firebaseService = FirebaseService();
  
  late String _selectedDate;
  bool _isLoading = true;
  WorkoutLog? _sessionLog;
  Map<String, WorkoutPlan>? _customPlan;
  Map<String, List<SetLog>> _lastSessions = {};

  static final Map<String, List<String>> _defaultExercises = {
    "Mon": [
      "Deadlift", "Pull up", "Wide Grip lat pull down", "Close grip lat pull down", 
      "Standing cable pull down", "Barbell curl on rod", "Preacher curl on machine", "Hammer with dumbbells"
    ],
    "Tue": [
      "Flat barbell press", "Incline barbell press", "Incline dumbbell fly", "Decline Push ups", 
      "Close grip Barbell press", "Overhead Dumbbell press", "Tricep Pushdowns on Cables"
    ],
    "Wed": [
      "Barbell shoulder press", "Lateral Raise", "Dumbbell Shoulder press", "Front Raise", 
      "Face pulls with ropes", "Barbell Traps", "Kneeling Cable Crunch Upper abs", 
      "V ups Middle abs", "Hanging Leg Raises Lower abs"
    ],
    "Thu": [
      "Barbell bent over row", "T bar", "Machine Rowing", "Standing cable pull down", 
      "Barbell curl on rod", "Preacher curl on machine", "Hammer with dumbbells"
    ],
    "Fri": [
      "Flat barbell press", "Decline dumbbell press", "Dips / Decline Cable", "Cable Fly", 
      "Close grip barbell press", "Kick Back dumbbell", "Tricep Pushdown"
    ],
    "Sat": [
      "Barbell Squat", "Legpress", "Leg Extensions", "Leg curl", "Calf Raise", "Steam"
    ],
    "Sun": [],
  };

  static final Map<String, String> _defaultTitles = {
    "Mon": "Back (wide back) & Bicep",
    "Tue": "Chest (upper) & Tricep",
    "Wed": "Shoulder (front and mid) & Abs",
    "Thu": "Back (thick back) & Bicep",
    "Fri": "Chest (lower chest) & Tricep",
    "Sat": "Legs",
    "Sun": "Rest Day",
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  int _getDefaultSetsCount(String exerciseName) {
    const bicepTricepList = [
      "Barbell curl on rod",
      "Preacher curl on machine",
      "Hammer with dumbbells",
      "Close grip Barbell press",
      "Overhead Dumbbell press",
      "Tricep Pushdowns on Cables",
      "Close grip barbell press",
      "Kick Back dumbbell",
      "Tricep... (Tricep Pushdown)",
      "Tricep Pushdown"
    ];
    if (bicepTricepList.contains(exerciseName)) {
      return 2;
    }
    return 3;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load custom plan
      _customPlan = await _firebaseService.loadCustomPlan();

      // 2. Load daily log
      final log = await _firebaseService.loadDailyLog(_selectedDate);
      final dayName = DateFormat('E').format(DateTime.parse("$_selectedDate 00:00:00")); // e.g. Mon

      if (log != null) {
        _sessionLog = log;
      } else {
        // Build blank log from templates
        final activeTitle = _customPlan?[dayName]?.title ?? _defaultTitles[dayName] ?? "Rest Day";
        final activeExercises = _customPlan?[dayName]?.exercises ?? [];
        final defaultExercises = _defaultExercises[dayName] ?? [];
        
        final exercisesMap = <String, List<SetLog>>{};
        if (activeExercises.isNotEmpty) {
          for (var ex in activeExercises) {
            final name = ex.name;
            if (ex.isCardio) {
              exercisesMap[name] = [SetLog(weight: 0, reps: 0, sprintDuration: '', sprintSpeed: '', runDuration: '')];
            } else {
              final count = _getDefaultSetsCount(name);
              exercisesMap[name] = List.generate(count, (_) => SetLog(weight: 0, reps: 0));
            }
          }
        } else {
          for (var ex in defaultExercises) {
            final count = _getDefaultSetsCount(ex);
            exercisesMap[ex] = List.generate(count, (_) => SetLog(weight: 0, reps: 0));
          }
        }

        _sessionLog = WorkoutLog(
          date: _selectedDate,
          dayOfWeek: dayName,
          title: activeTitle,
          exercises: exercisesMap,
          completed: false,
        );
      }

      // 3. Fetch progressive overload helpers from history
      final history = await _firebaseService.loadHistoryLogs();
      final resolvedLastSets = <String, List<SetLog>>{};
      
      final activeExerciseNames = _customPlan?[dayName]?.exercises.map((e) => e.name).toList() 
          ?? _defaultExercises[dayName] 
          ?? [];
          
      for (var exName in activeExerciseNames) {
        // Find most recent log where exercise has completed sets
        final matchedLog = history.firstWhere(
          (h) => h.date != _selectedDate && h.exercises.containsKey(exName) && h.exercises[exName]!.any((s) => s.completed),
          orElse: () => WorkoutLog(date: '', dayOfWeek: '', title: '', exercises: {}, completed: false),
        );
        if (matchedLog.date.isNotEmpty) {
          resolvedLastSets[exName] = matchedLog.exercises[exName]!.where((s) => s.completed).toList();
        }
      }
      
      setState(() {
        _lastSessions = resolvedLastSets;
      });
    } catch (e) {
      print("Error loading workout screen data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _shiftDate(int days) {
    final current = DateTime.parse("$_selectedDate 00:00:00");
    final next = current.add(Duration(days: days));
    setState(() {
      _selectedDate = DateFormat('yyyy-MM-dd').format(next);
    });
    _loadData();
  }

  void _saveSession() {
    if (_sessionLog == null) return;
    _firebaseService.saveDailyLog(_sessionLog!);
  }

  void _handleAddSet(String exercise) {
    if (_sessionLog == null) return;
    
    // Auto preset values for new set from previous
    double defaultWeight = 0;
    int defaultReps = 0;
    final currentSets = _sessionLog!.exercises[exercise] ?? [];
    
    if (currentSets.isNotEmpty) {
      defaultWeight = currentSets.last.weight;
      defaultReps = currentSets.last.reps;
    } else if (_lastSessions.containsKey(exercise) && _lastSessions[exercise]!.isNotEmpty) {
      defaultWeight = _lastSessions[exercise]!.first.weight;
      defaultReps = _lastSessions[exercise]!.first.reps;
    }

    setState(() {
      _sessionLog!.exercises[exercise] = [
        ...currentSets,
        SetLog(weight: defaultWeight, reps: defaultReps)
      ];
    });
    _saveSession();
  }

  void _handleUpdateSet(String exercise, int index, String field, dynamic value) {
    if (_sessionLog == null) return;
    final list = _sessionLog!.exercises[exercise];
    if (list == null || list.length <= index) return;

    setState(() {
      if (field == 'weight') {
        list[index].weight = (value as num).toDouble();
      } else if (field == 'reps') {
        list[index].reps = value as int;
      } else if (field == 'completed') {
        list[index].completed = value as bool;
      } else if (field == 'sprintDuration') {
        list[index].sprintDuration = value as String?;
      } else if (field == 'sprintSpeed') {
        list[index].sprintSpeed = value as String?;
      } else if (field == 'runDuration') {
        list[index].runDuration = value as String?;
      }
    });
    _saveSession();
  }

  void _handleDeleteSet(String exercise, int index) {
    if (_sessionLog == null) return;
    final list = _sessionLog!.exercises[exercise];
    if (list == null || list.length <= index) return;

    setState(() {
      list.removeAt(index);
    });
    _saveSession();
  }

  void _finishWorkout() {
    if (_sessionLog == null) return;
    setState(() {
      _sessionLog = WorkoutLog(
        date: _sessionLog!.date,
        dayOfWeek: _sessionLog!.dayOfWeek,
        title: _sessionLog!.title,
        exercises: _sessionLog!.exercises,
        completed: true,
      );
    });
    _saveSession();
    _showTrophyDialog();
  }

  void _showTrophyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 48, color: Color(0xFFFBBF24)),
            ),
            const SizedBox(height: 16),
            Text(
              "Workout Completed!",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Incredible effort! Consistency is key. Rest up and prep for your next session.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Let's Go!",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  bool _isCardioExercise(String exerciseName) {
    if (_customPlan == null) return false;
    for (var plan in _customPlan!.values) {
      final matched = plan.exercises.firstWhere(
        (e) => e.name == exerciseName,
        orElse: () => PlanExercise(name: ''),
      );
      if (matched.name.isNotEmpty) {
        return matched.isCardio;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB))),
      );
    }

    if (_sessionLog == null) {
      return const Center(child: Text("Session could not be loaded", style: TextStyle(color: Colors.white)));
    }

    final exercises = _sessionLog!.exercises.keys.toList();
    final dayName = _sessionLog!.dayOfWeek;
    
    final activeExerciseNames = _customPlan?[dayName]
            ?.exercises
            .map((e) => e.name)
            .toList() ??
        _defaultExercises[dayName] ??
        [];
    
    exercises.sort((a, b) {
      final idxA = activeExerciseNames.indexOf(a);
      final idxB = activeExerciseNames.indexOf(b);
      if (idxA != -1 && idxB != -1) {
        return idxA.compareTo(idxB);
      }
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return a.compareTo(b);
    });

    final isToday = _selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      children: [
        // Date Switcher Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withOpacity(0.4),
            border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _shiftDate(-1),
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
              ),
              Column(
                children: [
                  Text(
                    DateFormat('E, MMM dd').format(DateTime.parse("$_selectedDate 00:00:00")),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isToday ? "Today" : "Past Session",
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                  )
                ],
              ),
              IconButton(
                onPressed: () => _shiftDate(1),
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ROUTINE",
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF60A5FA), fontWeight: FontWeight.w900),
                  ),
                  Text(
                    _sessionLog!.title,
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  )
                ],
              ),
            ),
            if (_sessionLog!.completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Completed",
                      style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              )
          ],
        ),
        const SizedBox(height: 20),

        // Exercises list
        if (exercises.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF374151).withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.spa_rounded, size: 48, color: const Color(0xFF10B981).withOpacity(0.5)),
                const SizedBox(height: 12),
                Text(
                  "Rest Day",
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  "Muscle recovery happens during rest. Enjoy the day off or edit exercises in Settings!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                )
              ],
            ),
          )
        else ...[
          ...exercises.map((ex) => ExerciseCard(
                key: ValueKey("$_selectedDate-$ex"),
                exerciseName: ex,
                sets: _sessionLog!.exercises[ex] ?? [],
                lastSessionSets: _lastSessions[ex],
                onAddSet: () => _handleAddSet(ex),
                onUpdateSet: (idx, field, val) => _handleUpdateSet(ex, idx, field, val),
                onDeleteSet: (idx) => _handleDeleteSet(ex, idx),
                isCardio: _isCardioExercise(ex),
              )),
          
          if (!_sessionLog!.completed) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _finishWorkout,
              icon: const Icon(Icons.done_all_rounded, color: Colors.white),
              label: Text("Finish Workout", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981), // Emerald-500
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ]
        ],
      ],
    );
  }
}
