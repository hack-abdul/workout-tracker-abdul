import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/nutrition.dart';
import '../models/workout.dart';
import '../services/firebase_service.dart';

class ReportCardScreen extends StatefulWidget {
  final String userId;

  const ReportCardScreen({super.key, required this.userId});

  @override
  State<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends State<ReportCardScreen> {
  final FirebaseService _service = FirebaseService();
  bool _isLoading = true;

  Map<String, WorkoutPlan>? _routine;
  List<WorkoutLog> _workoutLogs = [];
  List<DailyNutritionLog> _nutritionLogs = [];
  NutritionPlan? _nutritionPlan;

  // Calculated metrics
  int _expectedWorkouts = 0;
  int _completedWorkouts = 0;
  double _workoutScore = 0;

  double _avgCalories = 0;
  double _caloriePrecision = 0;
  double _calorieScore = 0;
  int _calorieLoggedDays = 0;

  double _avgProtein = 0;
  double _proteinScore = 0;
  int _proteinLoggedDays = 0;
  int _proteinGoalHitDays = 0;

  double _overallScore = 0;
  String _grade = 'F';
  String _gradeTitle = 'Needs Focus';
  String _gradeMessage = '';
  Color _gradeColor = Colors.redAccent;
  String _adviceTip = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _service.loadCustomPlan(),
      _service.loadHistoryLogs(),
      _service.loadNutritionLogs(),
      _service.loadNutritionPlan(),
    ]);

    _routine = results[0] as Map<String, WorkoutPlan>?;
    _workoutLogs = results[1] as List<WorkoutLog>;
    _nutritionLogs = results[2] as List<DailyNutritionLog>;
    _nutritionPlan = results[3] as NutritionPlan?;

    _runCalculations();

    setState(() => _isLoading = false);
  }

  void _runCalculations() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // 1. Workout Adherence calculation
    int scheduledPerWeek = 0;
    if (_routine != null) {
      _routine!.forEach((day, plan) {
        if (plan.exercises.isNotEmpty) {
          scheduledPerWeek++;
        }
      });
    }
    // Intended workouts in 30 days (4.28 weeks)
    _expectedWorkouts = (30 / 7 * scheduledPerWeek).round();

    // Actual workouts in last 30 days
    _completedWorkouts = 0;
    for (final log in _workoutLogs) {
      try {
        final logDate = DateTime.parse(log.date);
        if (logDate.isAfter(thirtyDaysAgo) && log.completed) {
          _completedWorkouts++;
        }
      } catch (_) {}
    }

    if (_expectedWorkouts > 0) {
      _workoutScore = (_completedWorkouts / _expectedWorkouts * 100).clamp(0.0, 100.0);
    } else if (_completedWorkouts > 0) {
      _workoutScore = 100.0; // Handled scheduled routine is empty but completed workouts exist
      _expectedWorkouts = _completedWorkouts;
    } else {
      _workoutScore = 0.0;
    }

    // 2. Calorie Adherence calculation
    double totalCalories = 0;
    double totalCalorieDeviation = 0;
    _calorieLoggedDays = 0;
    final calorieTarget = _nutritionPlan?.dailyCalorieTarget ?? 2000.0;

    for (final log in _nutritionLogs) {
      try {
        final logDate = DateTime.parse(log.date);
        if (logDate.isAfter(thirtyDaysAgo)) {
          if (log.caloriesConsumed > 0) {
            totalCalories += log.caloriesConsumed;
            final dev = (log.caloriesConsumed - calorieTarget).abs() / calorieTarget;
            totalCalorieDeviation += dev;
            _calorieLoggedDays++;
          }
        }
      } catch (_) {}
    }

    if (_calorieLoggedDays > 0) {
      _avgCalories = totalCalories / _calorieLoggedDays;
      final avgDeviation = totalCalorieDeviation / _calorieLoggedDays;
      _caloriePrecision = (100 - (avgDeviation * 100)).clamp(0.0, 100.0);
      _calorieScore = _caloriePrecision;
    } else {
      _avgCalories = 0;
      _caloriePrecision = 0;
      _calorieScore = 0;
    }

    // 3. Protein Adherence calculation
    double totalProtein = 0;
    _proteinLoggedDays = 0;
    _proteinGoalHitDays = 0;
    final proteinTarget = _nutritionPlan?.dailyProteinGoalG ?? 130.0;

    for (final log in _nutritionLogs) {
      try {
        final logDate = DateTime.parse(log.date);
        if (logDate.isAfter(thirtyDaysAgo)) {
          if (log.proteinConsumed > 0) {
            totalProtein += log.proteinConsumed;
            _proteinLoggedDays++;
            // Success defined as meeting at least 90% of protein target
            if (log.proteinConsumed >= (proteinTarget * 0.9)) {
              _proteinGoalHitDays++;
            }
          }
        }
      } catch (_) {}
    }

    if (_proteinLoggedDays > 0) {
      _avgProtein = totalProtein / _proteinLoggedDays;
      _proteinScore = (_proteinGoalHitDays / _proteinLoggedDays * 100).clamp(0.0, 100.0);
    } else {
      _avgProtein = 0;
      _proteinScore = 0;
    }

    // 4. Overall Score calculation
    int activeMetrics = 0;
    if (_expectedWorkouts > 0 || _completedWorkouts > 0) activeMetrics++;
    if (_calorieLoggedDays > 0) activeMetrics++;
    if (_proteinLoggedDays > 0) activeMetrics++;

    if (activeMetrics == 0) {
      _overallScore = 0.0;
    } else {
      double sum = 0;
      double totalWeight = 0;

      if (_expectedWorkouts > 0 || _completedWorkouts > 0) {
        sum += _workoutScore * 0.4;
        totalWeight += 0.4;
      }
      if (_calorieLoggedDays > 0) {
        sum += _calorieScore * 0.3;
        totalWeight += 0.3;
      }
      if (_proteinLoggedDays > 0) {
        sum += _proteinScore * 0.3;
        totalWeight += 0.3;
      }

      _overallScore = sum / totalWeight;
    }

    // Map Overall Score to Letter Grade
    if (_overallScore >= 95) {
      _grade = 'A+';
      _gradeTitle = 'Elite Athlete';
      _gradeMessage = 'Phenomenal consistency and precision! You are executing your plan flawlessly.';
      _gradeColor = const Color(0xFF10B981); // Emerald
    } else if (_overallScore >= 90) {
      _grade = 'A';
      _gradeTitle = 'Dedicated Lifter';
      _gradeMessage = 'Excellent work! You are highly consistent and hitting your targets regularly.';
      _gradeColor = const Color(0xFF34D399); // Light Emerald
    } else if (_overallScore >= 80) {
      _grade = 'B';
      _gradeTitle = 'Consistent Builder';
      _gradeMessage = 'Great job! You\'re building strong habits. Minor adjustments will push you to A grade.';
      _gradeColor = const Color(0xFF60A5FA); // Blue
    } else if (_overallScore >= 70) {
      _grade = 'C';
      _gradeTitle = 'Maintenance Mode';
      _gradeMessage = 'Good effort, but there is room to improve consistency in your workouts or diet.';
      _gradeColor = const Color(0xFFF59E0B); // Amber
    } else if (_overallScore >= 60) {
      _grade = 'D';
      _gradeTitle = 'Getting Started';
      _gradeMessage = 'You\'re on the board, but consistency is key. Set daily reminders to log your training.';
      _gradeColor = const Color(0xFFF97316); // Orange
    } else {
      _grade = 'F';
      _gradeTitle = 'Needs Focus';
      _gradeMessage = 'Keep showing up! Building a routine takes time. Focus on logging daily to build the habit.';
      _gradeColor = Colors.redAccent;
    }

    // 5. Dynamic improvement tips
    if (activeMetrics > 0) {
      final scores = {
        'workouts': _workoutScore,
        'calories': _calorieLoggedDays > 0 ? _calorieScore : 999.0,
        'protein': _proteinLoggedDays > 0 ? _proteinScore : 999.0,
      };

      final lowestMetric = scores.entries.reduce((a, b) => a.value < b.value ? a : b).key;

      if (lowestMetric == 'workouts' && _workoutScore < 90) {
        _adviceTip = 'Your workout consistency is your biggest opportunity. Try setting a fixed workout time or reducing session duration to keep it manageable.';
      } else if (lowestMetric == 'calories' && _calorieScore < 90) {
        _adviceTip = 'Your calorie precision is fluctuating. Try planning and tracking your meals in the app in advance to reduce spontaneous snacking.';
      } else if (lowestMetric == 'protein' && _proteinScore < 90) {
        _adviceTip = 'You are missing your daily protein target. Consider lean snacks (Greek yogurt, boiled eggs) or a shake to hit your target of ${proteinTarget.toStringAsFixed(0)}g.';
      } else {
        _adviceTip = 'Excellent consistency! Keep tracking daily. You are perfectly positioned to revise targets at your next 30-day scale check.';
      }
    } else {
      _adviceTip = 'Start logging your daily exercises and meal targets to receive dynamic performance optimization tips here.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNoData = _expectedWorkouts == 0 && _calorieLoggedDays == 0 && _proteinLoggedDays == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF030712), // Zinc-950
      appBar: AppBar(
        backgroundColor: const Color(0xFF030712),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Monthly Report Card',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1))))
          : hasNoData
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // 1. Grade Card
                    _buildGradeCard(),
                    const SizedBox(height: 16),

                    // Advice Header
                    _buildAdviceTipCard(),
                    const SizedBox(height: 20),

                    // Metrics Heading
                    Text(
                      'METRICS BREAKDOWN',
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. Workout Card
                    _buildWorkoutMetricCard(),
                    const SizedBox(height: 12),

                    // 3. Calorie Adherence
                    _buildCalorieMetricCard(),
                    const SizedBox(height: 12),

                    // 4. Protein Adherence
                    _buildProteinMetricCard(),
                    const SizedBox(height: 40),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
              ),
              child: const Icon(Icons.stars_rounded, color: Colors.grey, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'No Report Data Yet',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Log your daily workouts and nutrition logs in the Cut tab to generate your report card and receive your performance grade.',
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _gradeColor.withOpacity(0.12),
            const Color(0xFF111827),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gradeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Circular grade badge
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF030712),
              border: Border.all(color: _gradeColor, width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: _gradeColor.withOpacity(0.25),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Center(
              child: Text(
                _grade,
                style: GoogleFonts.outfit(
                  color: _gradeColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Rating details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _gradeTitle.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: _gradeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Score: ${_overallScore.toStringAsFixed(0)}/100',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _gradeMessage,
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAdviceTipCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _adviceTip,
              style: GoogleFonts.inter(
                color: Colors.grey[300],
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutMetricCard() {
    final intended = _expectedWorkouts;
    final done = _completedWorkouts;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, color: Color(0xFF60A5FA), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Workout Consistency',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF60A5FA).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_workoutScore.toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(color: const Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricDetailItem('Intended Target', '$intended sessions'),
              _metricDetailItem('Actual Completed', '$done sessions'),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_workoutScore / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF1F2937),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieMetricCard() {
    final target = _nutritionPlan?.dailyCalorieTarget ?? 2000.0;
    final precision = _caloriePrecision;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Calorie Precision Adherence',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${precision.toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricDetailItem('Intended Budget', '${target.toStringAsFixed(0)} kcal'),
              _metricDetailItem(
                'Average Actual',
                _calorieLoggedDays > 0 ? '${_avgCalories.toStringAsFixed(0)} kcal' : 'Not logged',
              ),
            ],
          ),
          if (_calorieLoggedDays > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (precision / 100).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF1F2937),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                minHeight: 6,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              '⚠ No calories logged in the last 30 days.',
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildProteinMetricCard() {
    final target = _nutritionPlan?.dailyProteinGoalG ?? 130.0;
    final hitRate = _proteinScore;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.egg_alt_rounded, color: Color(0xFFEC4899), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Protein Goal Hit Rate',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${hitRate.toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(color: const Color(0xFFEC4899), fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricDetailItem('Intended Target', '${target.toStringAsFixed(0)}g'),
              _metricDetailItem(
                'Average Intake',
                _proteinLoggedDays > 0 ? '${_avgProtein.toStringAsFixed(0)}g' : 'Not logged',
              ),
            ],
          ),
          if (_proteinLoggedDays > 0) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hit Goal: $_proteinGoalHitDays / $_proteinLoggedDays tracked days',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (hitRate / 100).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF1F2937),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                minHeight: 6,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              '⚠ No protein logs in the last 30 days.',
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11),
            )
          ]
        ],
      ),
    );
  }

  Widget _metricDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
