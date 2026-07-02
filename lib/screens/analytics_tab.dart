import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/workout.dart';
import '../services/firebase_service.dart';
import 'report_card_screen.dart';

class AnalyticsTab extends StatefulWidget {
  final String userId;

  const AnalyticsTab({super.key, required this.userId});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final FirebaseService _firebaseService = FirebaseService();

  List<WorkoutLog> _logs = [];
  bool _isLoading = true;
  
  // Multi-tier filter states
  String _selectedBodyPart = "All"; // "All", "Chest", "Back", "Legs", "Shoulders", "Biceps", "Triceps", "Abs"
  String _selectedExercise = "";
  String _selectedTimeRange = "30 Days"; // "7 Days", "30 Days", "This Month", "This Year", "All Time"
  String _overallChartMetric = "Volume"; // "Volume" or "Workouts"

  List<String> _exerciseOptions = []; // All completed exercises from history

  // Mapping of default exercises to body parts
  static const Map<String, String> _exerciseToBodyPart = {
    // Back
    "Deadlift": "Back",
    "Pull up": "Back",
    "Wide Grip lat pull down": "Back",
    "Close grip lat pull down": "Back",
    "Standing cable pull down": "Back",
    "Barbell bent over row": "Back",
    "T bar": "Back",
    "Machine Rowing": "Back",
    
    // Biceps
    "Barbell curl on rod": "Biceps",
    "Preacher curl on machine": "Biceps",
    "Hammer with dumbbells": "Biceps",
    
    // Chest
    "Flat barbell press": "Chest",
    "Incline barbell press": "Chest",
    "Incline dumbbell fly": "Chest",
    "Decline Push ups": "Chest",
    "Decline dumbbell press": "Chest",
    "Dips / Decline Cable": "Chest",
    "Cable Fly": "Chest",
    
    // Triceps
    "Close grip Barbell press": "Triceps",
    "Close grip barbell press": "Triceps",
    "Overhead Dumbbell press": "Triceps",
    "Tricep Pushdowns on Cables": "Triceps",
    "Kick Back dumbbell": "Triceps",
    "Tricep Pushdown": "Triceps",
    
    // Shoulders
    "Barbell shoulder press": "Shoulders",
    "Lateral Raise": "Shoulders",
    "Dumbbell Shoulder press": "Shoulders",
    "Front Raise": "Shoulders",
    "Face pulls with ropes": "Shoulders",
    "Barbell Traps": "Shoulders",
    
    // Abs
    "Kneeling Cable Crunch Upper abs": "Abs",
    "V ups Middle abs": "Abs",
    "Hanging Leg Raises Lower abs": "Abs",
    
    // Legs
    "Barbell Squat": "Legs",
    "Legpress": "Legs",
    "Leg Extensions": "Legs",
    "Leg curl": "Legs",
    "Calf Raise": "Legs",
    "Steam": "Legs",
  };

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final history = await _firebaseService.loadHistoryLogs();
      // Sort oldest first for chronological charts
      history.sort((a, b) => a.date.compareTo(b.date));
      
      final exercisesSet = <String>{};
      for (var log in history) {
        log.exercises.forEach((ex, sets) {
          if (sets.any((s) => s.completed)) {
            exercisesSet.add(ex);
          }
        });
      }

      final options = exercisesSet.toList()..sort();

      setState(() {
        _logs = history;
        _exerciseOptions = options;
        _autoSelectExercise();
      });
    } catch (e) {
      print("Error loading analytics: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _autoSelectExercise() {
    final filtered = _getFilteredExerciseOptions();
    if (filtered.isNotEmpty) {
      if (!filtered.contains(_selectedExercise)) {
        _selectedExercise = filtered.first;
      }
    } else {
      _selectedExercise = "";
    }
  }

  List<String> _getFilteredExerciseOptions() {
    if (_selectedBodyPart == "All") {
      return _exerciseOptions;
    }
    return _exerciseOptions.where((ex) {
      final part = _exerciseToBodyPart[ex] ?? "Other";
      return part.toLowerCase() == _selectedBodyPart.toLowerCase();
    }).toList();
  }

  // Calculate stats grouped by month for the last 6 calendar months
  List<MonthlyStatPoint> _getMonthlyStats() {
    final now = DateTime.now();
    final stats = <MonthlyStatPoint>[];
    
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(monthDate);
      final monthLabel = DateFormat('MMM').format(monthDate); // e.g. Jun
      
      double volume = 0;
      int workoutsCount = 0;
      
      for (var log in _logs) {
        if (log.date.startsWith(monthKey)) {
          workoutsCount++;
          log.exercises.forEach((_, sets) {
            for (var set in sets) {
              if (set.completed) {
                volume += set.weight * set.reps;
              }
            }
          });
        }
      }
      
      stats.add(MonthlyStatPoint(
        label: monthLabel,
        volume: volume,
        workouts: workoutsCount,
      ));
    }
    
    return stats;
  }

  List<ChartDataPoint> _getFilteredChartPoints() {
    final chartPoints = <ChartDataPoint>[];
    if (_selectedExercise.isEmpty) return chartPoints;

    final now = DateTime.now();
    DateTime? limitDate;
    
    switch (_selectedTimeRange) {
      case "7 Days":
        limitDate = now.subtract(const Duration(days: 7));
        break;
      case "30 Days":
        limitDate = now.subtract(const Duration(days: 30));
        break;
      case "This Month":
        limitDate = DateTime(now.year, now.month, 1);
        break;
      case "This Year":
        limitDate = DateTime(now.year, 1, 1);
        break;
      case "All Time":
      default:
        limitDate = null;
        break;
    }

    for (var log in _logs) {
      final logDate = DateTime.tryParse(log.date);
      if (logDate == null) continue;
      
      // Apply time filter
      if (limitDate != null && logDate.isBefore(limitDate)) continue;

      if (log.exercises.containsKey(_selectedExercise)) {
        final completedSets = log.exercises[_selectedExercise]!.where((s) => s.completed).toList();
        if (completedSets.isNotEmpty) {
          final maxWeight = completedSets.map((s) => s.weight).reduce(math.max);
          final volume = completedSets.fold<double>(0.0, (prev, s) => prev + s.weight * s.reps);
          chartPoints.add(ChartDataPoint(
            date: log.date.substring(5), // MM-DD
            maxWeight: maxWeight,
            volume: volume,
          ));
        }
      }
    }
    return chartPoints;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB))),
      );
    }

    // Lifetime metrics
    final totalWorkouts = _logs.length;
    double totalVolume = 0;
    for (var log in _logs) {
      log.exercises.forEach((_, sets) {
        for (var set in sets) {
          if (set.completed) {
            totalVolume += set.weight * set.reps;
          }
        }
      });
    }

    final monthlyStats = _getMonthlyStats();
    final chartPoints = _getFilteredChartPoints();
    final filteredExercises = _getFilteredExerciseOptions();

    final bodyParts = ["All", "Chest", "Back", "Legs", "Shoulders", "Biceps", "Triceps", "Abs"];
    final timeRanges = ["7 Days", "30 Days", "This Month", "This Year", "All Time"];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const SizedBox(height: 16),
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ANALYTICS",
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF60A5FA), fontWeight: FontWeight.w900),
              ),
              Text(
                "Strength & Frequency",
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 16),
          // Report Card Banner
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportCardScreen(userId: widget.userId),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.12),
                    const Color(0xFF111827),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Monthly Report Card",
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Compare intended targets vs actual completion & view your grade.",
                          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 1. Lifetime Summary Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937).withOpacity(0.15),
                    border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Color(0xFF60A5FA), size: 18),
                      const SizedBox(height: 8),
                      Text("$totalWorkouts", style: GoogleFonts.shareTechMono(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 1),
                      Text("Total Workouts", style: GoogleFonts.inter(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937).withOpacity(0.15),
                    border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 18),
                      const SizedBox(height: 8),
                      Text(
                        totalVolume >= 1000 ? "${(totalVolume / 1000).toStringAsFixed(1)}k" : "${totalVolume.toInt()}",
                        style: GoogleFonts.shareTechMono(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 1),
                      Text("Total Volume (kg)", style: GoogleFonts.inter(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Overall View - Monthly Volume/Frequency Bar Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withOpacity(0.4),
              border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "OVERALL PROGRESS",
                      style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF60A5FA), fontWeight: FontWeight.w900),
                    ),
                    // Toggle Metric Selector
                    Container(
                      height: 24,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF030712).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: ["Volume", "Workouts"].map((metric) {
                          final isSel = _overallChartMetric == metric;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _overallChartMetric = metric;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                metric,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? Colors.white : Colors.grey,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),

                // Custom Paint Bar Chart
                SizedBox(
                  height: 140,
                  child: CustomPaint(
                    painter: BarChartPainter(
                      points: monthlyStats,
                      metric: _overallChartMetric,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section Title
          Text(
            "EXERCISE TRENDS",
            style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF60A5FA), fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),

          // 3. Body Part Filter Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bodyParts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final part = bodyParts[index];
                final isSelected = _selectedBodyPart == part;
                return ChoiceChip(
                  label: Text(
                    part,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[400],
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedBodyPart = part;
                        _autoSelectExercise();
                      });
                    }
                  },
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: const Color(0xFF111827).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF374151).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 4. Dynamic Exercise Dropdown Selector & Time Range Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withOpacity(0.4),
              border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: filteredExercises.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      "No completed exercises in this category.",
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedExercise.isNotEmpty && filteredExercises.contains(_selectedExercise)
                          ? _selectedExercise
                          : null,
                      dropdownColor: const Color(0xFF111827),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      isExpanded: true,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      onChanged: (String? val) {
                        if (val != null) {
                          setState(() {
                            _selectedExercise = val;
                          });
                        }
                      },
                      items: filteredExercises.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // 5. Time Range Filter Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: timeRanges.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final range = timeRanges[index];
                final isSelected = _selectedTimeRange == range;
                return ChoiceChip(
                  label: Text(
                    range,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[400],
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTimeRange = range;
                      });
                    }
                  },
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: const Color(0xFF111827).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF374151).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 6. Dynamic Strength Progression Line Chart Card
          if (_selectedExercise.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF374151).withOpacity(0.2)),
              ),
              child: Text(
                "Choose a completed exercise to view strength metrics.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withOpacity(0.4),
                border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.show_chart_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 6),
                      Text("Strength Progression", style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Custom Line Painter
                  if (chartPoints.length < 2)
                    Container(
                      height: 160,
                      alignment: Alignment.center,
                      child: Text(
                        chartPoints.isEmpty
                            ? "No workouts logged for this time range."
                            : "Log this exercise across at least 2 sessions to generate a progress chart.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 160,
                      child: CustomPaint(
                        painter: ChartPainter(points: chartPoints),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // History table detail
                    Text(
                      "HISTORY DETAILS",
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      decoration: BoxDecoration(
                        color: const Color(0xFF030712).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: chartPoints.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF1F2937)),
                          itemBuilder: (context, index) {
                            final idx = chartPoints.length - 1 - index;
                            final item = chartPoints[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.date,
                                    style: GoogleFonts.shareTechMono(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        "Volume: ",
                                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                                      ),
                                      Text(
                                        "${item.volume.toInt()}kg",
                                        style: GoogleFonts.shareTechMono(color: Colors.grey[300], fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        "Max: ",
                                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                                      ),
                                      Text(
                                        "${item.maxWeight.toInt()}kg",
                                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  ]
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}

class ChartDataPoint {
  final String date;
  final double maxWeight;
  final double volume;

  ChartDataPoint({required this.date, required this.maxWeight, required this.volume});
}

class ChartPainter extends CustomPainter {
  final List<ChartDataPoint> points;

  ChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final weights = points.map((p) => p.maxWeight).toList();
    final minW = math.max(0.0, weights.reduce(math.min) - 5);
    final maxW = weights.reduce(math.max) + 5;
    final wDiff = maxW - minW == 0 ? 1.0 : maxW - minW;

    final paddingLeft = 30.0;
    final paddingRight = 10.0;
    final paddingTop = 25.0;
    final paddingBottom = 20.0;

    final drawWidth = size.width - paddingLeft - paddingRight;
    final drawHeight = size.height - paddingTop - paddingBottom;
    final xStep = drawWidth / (points.length - 1);

    // Coordinate mapping
    final mappedPoints = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = paddingLeft + i * xStep;
      final ratio = (points[i].maxWeight - minW) / wDiff;
      final y = size.height - paddingBottom - ratio * drawHeight;
      mappedPoints.add(Offset(x, y));
    }

    // Draw Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(paddingLeft, paddingTop), Offset(size.width - paddingRight, paddingTop), gridPaint);
    canvas.drawLine(
        Offset(paddingLeft, paddingTop + drawHeight / 2), Offset(size.width - paddingRight, paddingTop + drawHeight / 2), gridPaint);
    canvas.drawLine(Offset(paddingLeft, size.height - paddingBottom), Offset(size.width - paddingRight, size.height - paddingBottom),
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..strokeWidth = 1.5);

    // Draw Gradient Area
    final areaPath = Path()
      ..moveTo(mappedPoints.first.dx, size.height - paddingBottom);
    for (var pt in mappedPoints) {
      areaPath.lineTo(pt.dx, pt.dy);
    }
    areaPath.lineTo(mappedPoints.last.dx, size.height - paddingBottom);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF2563EB).withOpacity(0.18), const Color(0xFF2563EB).withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(paddingLeft, paddingTop, size.width - paddingRight, size.height - paddingBottom));
    canvas.drawPath(areaPath, areaPaint);

    // Draw Line
    final linePath = Path()..moveTo(mappedPoints.first.dx, mappedPoints.first.dy);
    for (int i = 1; i < mappedPoints.length; i++) {
      linePath.lineTo(mappedPoints[i].dx, mappedPoints[i].dy);
    }

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF10B981)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromPoints(mappedPoints.first, mappedPoints.last))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Draw Dots and Labels
    final dotPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotInnerPaint = Paint()
      ..color = const Color(0xFF030712)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < mappedPoints.length; i++) {
      final pt = mappedPoints[i];
      
      // Draw point circle
      canvas.drawCircle(pt, 5, dotInnerPaint);
      canvas.drawCircle(pt, 5, dotPaint);

      // Value label text
      textPainter.text = TextSpan(
        text: "${points[i].maxWeight.toInt()}",
        style: GoogleFonts.shareTechMono(color: Colors.grey[400], fontSize: 9, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, pt.dy - 16));

      // Date label text
      textPainter.text = TextSpan(
        text: points[i].date,
        style: GoogleFonts.shareTechMono(color: Colors.grey[600], fontSize: 8, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, size.height - paddingBottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MonthlyStatPoint {
  final String label;
  final double volume;
  final int workouts;

  MonthlyStatPoint({required this.label, required this.volume, required this.workouts});
}

class BarChartPainter extends CustomPainter {
  final List<MonthlyStatPoint> points;
  final String metric;

  BarChartPainter({required this.points, required this.metric});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = points.map((p) => metric == "Volume" ? p.volume : p.workouts.toDouble()).reduce(math.max);
    final scaleMax = maxVal == 0 ? 1.0 : maxVal * 1.15; // 15% head room

    final paddingLeft = 35.0;
    final paddingRight = 10.0;
    final paddingTop = 25.0;
    final paddingBottom = 20.0;

    final drawWidth = size.width - paddingLeft - paddingRight;
    final drawHeight = size.height - paddingTop - paddingBottom;
    
    final colWidth = drawWidth / (points.length * 2 - 1); // Column width is same as space width
    final paintLine = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    canvas.drawLine(Offset(paddingLeft, paddingTop), Offset(size.width - paddingRight, paddingTop), paintLine);
    canvas.drawLine(Offset(paddingLeft, paddingTop + drawHeight / 2), Offset(size.width - paddingRight, paddingTop + drawHeight / 2), paintLine);
    canvas.drawLine(Offset(paddingLeft, size.height - paddingBottom), Offset(size.width - paddingRight, size.height - paddingBottom), 
      Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..strokeWidth = 1.5
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < points.length; i++) {
      final val = metric == "Volume" ? points[i].volume : points[i].workouts.toDouble();
      final ratio = val / scaleMax;
      final colHeight = ratio * drawHeight;
      
      final x = paddingLeft + (i * 2) * colWidth;
      final y = size.height - paddingBottom - colHeight;

      // Draw Bar
      final rect = Rect.fromLTWH(x, y, colWidth, colHeight);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      final barPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF2563EB)], // Purple-600 to Blue-600
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect);

      canvas.drawRRect(rrect, barPaint);

      // Draw Label Value on top of bar
      String valStr = metric == "Volume"
          ? (val >= 1000 ? "${(val / 1000).toStringAsFixed(1)}k" : "${val.toInt()}")
          : "${val.toInt()}";
      
      textPainter.text = TextSpan(
        text: valStr,
        style: GoogleFonts.shareTechMono(
          color: val > 0 ? Colors.white : Colors.grey[600],
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (colWidth - textPainter.width) / 2, y - 11));

      // Draw Month Label at the bottom
      textPainter.text = TextSpan(
        text: points[i].label,
        style: GoogleFonts.shareTechMono(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (colWidth - textPainter.width) / 2, size.height - paddingBottom + 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
