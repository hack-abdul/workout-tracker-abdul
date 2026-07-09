import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/workout.dart';
import '../services/firebase_service.dart';

class SettingsTab extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> preferences;
  final Function(Map<String, dynamic> newPrefs) onPreferencesChange;

  const SettingsTab({
    super.key,
    required this.userId,
    required this.preferences,
    required this.onPreferencesChange,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = true;
  Map<String, WorkoutPlan> _plan = {};
  String _selectedDay = "Mon";
  final _newExerciseController = TextEditingController();
  bool _newExerciseIsCardio = false;
  
  // Local state for prefs
  late String _unit;
  String _saveStatus = "idle"; // idle, saving, saved

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
    _unit = widget.preferences['weightUnit'] as String? ?? 'kg';
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    setState(() => _isLoading = true);
    try {
      final customPlan = await _firebaseService.loadCustomPlan();
      if (customPlan != null) {
        setState(() {
          _plan = customPlan;
        });
      } else {
        // Fallback to default
        final defaultMap = <String, WorkoutPlan>{};
        _defaultTitles.forEach((key, value) {
          defaultMap[key] = WorkoutPlan(
            title: value,
            exercises: (_defaultExercises[key] ?? [])
                .map((e) => PlanExercise(name: e, isCardio: false))
                .toList(),
          );
        });
        setState(() {
          _plan = defaultMap;
        });
      }
    } catch (e) {
      print("Error loading plan in settings: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saveStatus = "saving";
    });

    try {
      // 1. Save preferences
      await _firebaseService.savePreferences(60, _unit);
      widget.onPreferencesChange({
        'defaultRestDuration': 60,
        'weightUnit': _unit,
      });

      // 2. Save custom plan
      await _firebaseService.saveCustomPlan(_plan);
      
      setState(() {
        _saveStatus = "saved";
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _saveStatus = "idle");
        }
      });
    } catch (e) {
      print("Error saving settings: $e");
      setState(() => _saveStatus = "idle");
    }
  }

  void _updateTitle(String newTitle) {
    setState(() {
      final currentPlan = _plan[_selectedDay] ?? WorkoutPlan(title: "", exercises: []);
      _plan[_selectedDay] = WorkoutPlan(
        title: newTitle,
        exercises: currentPlan.exercises,
      );
    });
  }

  void _handleAddExercise() {
    final text = _newExerciseController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      final currentPlan = _plan[_selectedDay] ?? WorkoutPlan(title: "", exercises: []);
      _plan[_selectedDay] = WorkoutPlan(
        title: currentPlan.title,
        exercises: [...currentPlan.exercises, PlanExercise(name: text, isCardio: _newExerciseIsCardio)],
      );
      _newExerciseIsCardio = false;
    });
    _newExerciseController.clear();
  }

  void _handleDeleteExercise(int index) {
    setState(() {
      final currentPlan = _plan[_selectedDay] ?? WorkoutPlan(title: "", exercises: []);
      final list = [...currentPlan.exercises]..removeAt(index);
      _plan[_selectedDay] = WorkoutPlan(
        title: currentPlan.title,
        exercises: list,
      );
    });
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to sign out?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firebaseService.signOut();
    }
  }

  @override
  void dispose() {
    _newExerciseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB))),
      );
    }

    final activeDayPlan = _plan[_selectedDay] ?? WorkoutPlan(title: "Rest Day", exercises: []);
    final daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
      children: [
        const SizedBox(height: 16),
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SETTINGS",
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF60A5FA), fontWeight: FontWeight.w900),
                ),
                Text(
                  "App Configurations",
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                )
              ],
            ),
            ElevatedButton.icon(
              onPressed: _handleSignOut,
              icon: const Icon(Icons.logout, size: 14, color: Colors.redAccent),
              label: Text("Sign Out", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.08),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          ],
        ),
        const SizedBox(height: 20),

        // Preferences Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.4),
            border: Border.all(color: AppTheme.borderLight.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings, color: Color(0xFF60A5FA), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Preferences",
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Weight Unit selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Weight Unit", style: GoogleFonts.inter(color: Colors.grey[200], fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text("Pound or Kilogram metrics", style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _unit = 'kg'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _unit == 'kg' ? const Color(0xFF2563EB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "kg",
                              style: GoogleFonts.inter(
                                color: _unit == 'kg' ? Colors.white : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _unit = 'lbs'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _unit == 'lbs' ? const Color(0xFF2563EB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "lbs",
                              style: GoogleFonts.inter(
                                color: _unit == 'lbs' ? Colors.white : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Custom Routines Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.4),
            border: Border.all(color: AppTheme.borderLight.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Customize Routines",
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Day choice chips selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: daysOfWeek.map((day) {
                    final isSelected = _selectedDay == day;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(
                          day,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedDay = day);
                        },
                        selectedColor: const Color(0xFF7C3AED),
                        backgroundColor: AppTheme.background,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Routine Name Editor
              Text(
                "ROUTINE NAME",
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: ValueKey("name-$_selectedDay"),
                initialValue: activeDayPlan.title,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF7C3AED)),
                  ),
                ),
                onChanged: _updateTitle,
              ),
              const SizedBox(height: 20),

              // Exercises management list
              Text(
                "EXERCISES (${activeDayPlan.exercises.length})",
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              
              if (activeDayPlan.exercises.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text("No exercises in this day.", style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic)),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeDayPlan.exercises.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final currentPlan = _plan[_selectedDay] ?? WorkoutPlan(title: "", exercises: []);
                      final list = [...currentPlan.exercises];
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
                      _plan[_selectedDay] = WorkoutPlan(
                        title: currentPlan.title,
                        exercises: list,
                      );
                    });
                  },
                  itemBuilder: (context, idx) {
                    final ex = activeDayPlan.exercises[idx];
                    return Container(
                      key: ValueKey("reorder-${ex.name}"),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withOpacity(0.8),
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 18),
                              const SizedBox(width: 10),
                              Text(ex.name, style: GoogleFonts.inter(color: Colors.grey[200], fontSize: 12, fontWeight: FontWeight.bold)),
                              if (ex.isCardio) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withOpacity(0.15),
                                    border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Cardio",
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF60A5FA),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          GestureDetector(
                            onTap: () => _handleDeleteExercise(idx),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                          )
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),

              // Add Exercise Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newExerciseController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "Add new exercise...",
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF4B5563), fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF7C3AED)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _handleAddExercise,
                    icon: const Icon(Icons.add, color: Color(0xFF7C3AED)),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF7C3AED).withOpacity(0.08)),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "Workout Type: ",
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      "Strength",
                      style: GoogleFonts.inter(
                        color: !_newExerciseIsCardio ? Colors.white : Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: !_newExerciseIsCardio,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _newExerciseIsCardio = false;
                        });
                      }
                    },
                    selectedColor: const Color(0xFF7C3AED).withOpacity(0.2),
                    backgroundColor: AppTheme.background,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: !_newExerciseIsCardio ? const Color(0xFF7C3AED) : Colors.transparent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      "Cardio",
                      style: GoogleFonts.inter(
                        color: _newExerciseIsCardio ? Colors.white : Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: _newExerciseIsCardio,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _newExerciseIsCardio = true;
                        });
                      }
                    },
                    selectedColor: const Color(0xFF2563EB).withOpacity(0.2),
                    backgroundColor: AppTheme.background,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: _newExerciseIsCardio ? const Color(0xFF2563EB) : Colors.transparent,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Save Button
        ElevatedButton.icon(
          onPressed: _saveStatus == "saving" ? null : _saveSettings,
          icon: Icon(
            _saveStatus == "saved"
                ? Icons.check
                : _saveStatus == "saving"
                    ? Icons.loop_rounded
                    : Icons.save,
            color: Colors.white,
          ),
          label: Text(
            _saveStatus == "saved"
                ? "Saved!"
                : _saveStatus == "saving"
                    ? "Saving..."
                    : "Save Configurations",
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _saveStatus == "saved"
                ? const Color(0xFF10B981)
                : _saveStatus == "saving"
                    ? Colors.grey
                    : const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        )
      ],
    );
  }
}
