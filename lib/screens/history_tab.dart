import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../services/firebase_service.dart';

class HistoryTab extends StatefulWidget {
  final String userId;

  const HistoryTab({super.key, required this.userId});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final FirebaseService _firebaseService = FirebaseService();
  
  List<WorkoutLog> _logs = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String? _expandedDate;

  // New Filter and Heatmap state variables
  String _selectedFilter = "All"; // "All", "7 Days", "30 Days", "This Month", "Last Month", "Custom"
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  DateTime _heatmapMonth = DateTime.now();
  DateTime? _selectedDayFilter;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _firebaseService.loadHistoryLogs();
      setState(() {
        _logs = history;
      });
    } catch (e) {
      print("Error loading history: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteLog(String date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text("Delete Log", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete the workout log for $date?", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firebaseService.deleteDailyLog(date);
        setState(() {
          _logs.removeWhere((log) => log.date == date);
          if (_expandedDate == date) _expandedDate = null;
        });
      } catch (e) {
        print("Error deleting log: $e");
      }
    }
  }

  Future<void> _selectCustomDateRange() async {
    final initialRange = _customStartDate != null && _customEndDate != null
        ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
        : DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          );

    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              surface: Color(0xFF111827),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _customStartDate = pickedRange.start;
        _customEndDate = pickedRange.end;
        _selectedFilter = "Custom";
        _selectedDayFilter = null; // Clear specific day filter
      });
    }
  }

  Widget _buildHeatmap() {
    final year = _heatmapMonth.year;
    final month = _heatmapMonth.month;
    final firstDay = DateTime(year, month, 1);
    final totalDays = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDay.weekday; // Monday = 1, Sunday = 7
    final offset = firstWeekday - 1; // Number of empty cells before day 1

    final daysOfWeek = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Calculate consistency metrics for the currently displayed month
    int workoutDaysCount = 0;
    for (int d = 1; d <= totalDays; d++) {
      final dateStr = "$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
      final hasWorkout = _logs.any((log) => log.date == dateStr && log.exercises.values.any((sets) => sets.any((s) => s.completed)));
      if (hasWorkout) workoutDaysCount++;
    }
    final consistencyPercent = totalDays > 0 ? (workoutDaysCount / totalDays * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.15),
        border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Heatmap Header (Month and Navigation)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CONSISTENCY",
                style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF60A5FA), fontWeight: FontWeight.w900),
              ),
              Row(
                children: [
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _heatmapMonth = DateTime(_heatmapMonth.year, _heatmapMonth.month - 1);
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMMM yyyy').format(_heatmapMonth),
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _heatmapMonth = DateTime(_heatmapMonth.year, _heatmapMonth.month + 1);
                      });
                    },
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          
          // Days of Week Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: daysOfWeek.map((day) => Container(
              width: 28,
              alignment: Alignment.center,
              child: Text(
                day,
                style: GoogleFonts.shareTechMono(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            )).toList(),
          ),
          const SizedBox(height: 6),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: offset + totalDays,
            itemBuilder: (context, index) {
              if (index < offset) {
                return const SizedBox.shrink();
              }
              final dayNum = index - offset + 1;
              final currentDay = DateTime(year, month, dayNum);
              final dateStr = "$year-${month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}";
              
              final hasWorkout = _logs.any((log) => log.date == dateStr && log.exercises.values.any((sets) => sets.any((s) => s.completed)));
              final isSelectedDay = _selectedDayFilter != null &&
                  _selectedDayFilter!.year == year &&
                  _selectedDayFilter!.month == month &&
                  _selectedDayFilter!.day == dayNum;

              // Grid square styling
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelectedDay) {
                      _selectedDayFilter = null;
                    } else {
                      _selectedDayFilter = currentDay;
                      // Clear standard date range filters to avoid conflicts
                      _selectedFilter = "All";
                    }
                  });
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasWorkout
                        ? null
                        : isSelectedDay
                            ? const Color(0xFF2563EB).withOpacity(0.2)
                            : const Color(0xFF111827).withOpacity(0.4),
                    gradient: hasWorkout
                        ? LinearGradient(
                            colors: [
                              const Color(0xFF2563EB).withOpacity(isSelectedDay ? 1.0 : 0.75),
                              const Color(0xFF10B981).withOpacity(isSelectedDay ? 1.0 : 0.75),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelectedDay
                          ? const Color(0xFFFBBF24) // Yellow border for selection
                          : hasWorkout
                              ? Colors.transparent
                              : const Color(0xFF374151).withOpacity(0.2),
                      width: isSelectedDay ? 2 : 1,
                    ),
                    boxShadow: hasWorkout
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    "$dayNum",
                    style: GoogleFonts.shareTechMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasWorkout
                          ? Colors.white
                          : isSelectedDay
                              ? const Color(0xFF60A5FA)
                              : Colors.grey[400],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Heatmap Footer Stats Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withOpacity(0.4),
              border: Border.all(color: const Color(0xFF374151).withOpacity(0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 4),
                    Text(
                      "Consistency Score",
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  "$workoutDaysCount / $totalDays active days ($consistencyPercent%)",
                  style: GoogleFonts.shareTechMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: consistencyPercent > 30 ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ["All", "7 Days", "30 Days", "This Month", "Last Month", "Custom"];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter && _selectedDayFilter == null;

          String labelText = filter;
          if (filter == "Custom" && _customStartDate != null && _customEndDate != null) {
            final start = DateFormat('MM/dd').format(_customStartDate!);
            final end = DateFormat('MM/dd').format(_customEndDate!);
            labelText = "$start - $end";
          }

          return ChoiceChip(
            label: Text(
              labelText,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[400],
              ),
            ),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                if (filter == "Custom") {
                  _selectCustomDateRange();
                } else {
                  setState(() {
                    _selectedFilter = filter;
                    _selectedDayFilter = null; // Clear day specific filter
                  });
                }
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB))),
      );
    }

    // Filter processing
    final filteredLogs = _logs.where((log) {
      // 1. Search Query Filter
      final query = _searchQuery.toLowerCase();
      final titleMatch = log.title.toLowerCase().contains(query);
      final dateMatch = log.date.contains(query);
      final exMatch = log.exercises.keys.any((ex) => ex.toLowerCase().contains(query));
      final matchesSearch = titleMatch || dateMatch || exMatch;
      if (!matchesSearch) return false;

      // 2. Day-specific Heatmap Filter
      if (_selectedDayFilter != null) {
        final dayStr = DateFormat('yyyy-MM-dd').format(_selectedDayFilter!);
        return log.date == dayStr;
      }

      // 3. Pre-made Date Range Filter
      final logDate = DateTime.tryParse(log.date);
      if (logDate == null) return true; // Fail-safe

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      switch (_selectedFilter) {
        case "7 Days":
          final diff = todayStart.difference(logDate).inDays;
          return diff >= 0 && diff < 7;
        case "30 Days":
          final diff = todayStart.difference(logDate).inDays;
          return diff >= 0 && diff < 30;
        case "This Month":
          return logDate.year == now.year && logDate.month == now.month;
        case "Last Month":
          final prevMonth = now.month == 1 ? 12 : now.month - 1;
          final prevYear = now.month == 1 ? now.year - 1 : now.year;
          return logDate.year == prevYear && logDate.month == prevMonth;
        case "Custom":
          if (_customStartDate != null && _customEndDate != null) {
            final start = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
            final end = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);
            return logDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
                logDate.isBefore(end.add(const Duration(seconds: 1)));
          }
          return true;
        case "All":
        default:
          return true;
      }
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "HISTORY",
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF60A5FA), fontWeight: FontWeight.w900),
              ),
              Text(
                "Workout Logs",
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
              hintText: "Search by exercise or routine...",
              hintStyle: GoogleFonts.inter(color: const Color(0xFF6B7280), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF111827).withOpacity(0.4),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: const Color(0xFF374151).withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const SizedBox(height: 12),

          // Scrollable area for heatmap, filters and list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadHistory,
              color: const Color(0xFF2563EB),
              backgroundColor: const Color(0xFF111827),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // 1. Heatmap Grid
                  _buildHeatmap(),
                  const SizedBox(height: 16),

                  // 2. Filter Chips row
                  _buildFilterChips(),
                  const SizedBox(height: 16),

                  // 3. Day-filter Info Banner
                  if (_selectedDayFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Logs for ${DateFormat('yyyy-MM-dd').format(_selectedDayFilter!)}",
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFFBBF24), fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedDayFilter = null;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              "Clear Day Filter",
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF60A5FA), fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),
                    ),

                  // 4. Workout Logs List
                  filteredLogs.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 64),
                          alignment: Alignment.center,
                          child: Text(
                            _selectedDayFilter != null
                                ? "No workouts logged on this day."
                                : _searchQuery.isNotEmpty
                                    ? "No matching logs found."
                                    : "No workout sessions in this range.",
                            style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: filteredLogs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            final isExpanded = _expandedDate == log.date;
                            final exerciseNames = log.exercises.keys.toList();
                            final totalSets = log.exercises.values.fold<int>(
                                0, (prev, list) => prev + list.where((s) => s.completed).length);

                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F2937).withOpacity(0.25),
                                border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Header Summary Row
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF111827).withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
                                      ),
                                      child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF60A5FA), size: 20),
                                    ),
                                    title: Text(
                                      log.title,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${log.date} (${log.dayOfWeek}) • ${exerciseNames.length} exercises • $totalSets sets",
                                      style: GoogleFonts.shareTechMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () => _handleDeleteLog(log.date),
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                                        ),
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _expandedDate = isExpanded ? null : log.date;
                                      });
                                    },
                                  ),

                                  // Expanded List
                                  if (isExpanded)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF030712).withOpacity(0.2),
                                        border: Border(
                                          top: BorderSide(color: const Color(0xFF374151).withOpacity(0.3)),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: exerciseNames.map((ex) {
                                          final completedSets = log.exercises[ex]!.where((s) => s.completed).toList();
                                          if (completedSets.isEmpty) return const SizedBox.shrink();

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ex,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.grey[300],
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: List.generate(completedSets.length, (idx) {
                                                    final set = completedSets[idx];
                                                    final isCardioSet = (set.sprintDuration != null && set.sprintDuration!.isNotEmpty) ||
                                                                        (set.sprintSpeed != null && set.sprintSpeed!.isNotEmpty) ||
                                                                        (set.runDuration != null && set.runDuration!.isNotEmpty);

                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF111827).withOpacity(0.6),
                                                        border: Border.all(color: const Color(0xFF374151).withOpacity(0.3)),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            "${idx + 1}",
                                                            style: const TextStyle(
                                                              fontSize: 9,
                                                              color: Color(0xFF60A5FA),
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            isCardioSet
                                                                ? "Sprint: ${set.sprintDuration ?? ''} @ ${set.sprintSpeed ?? ''} | Run: ${set.runDuration ?? ''}"
                                                                : "${set.weight.toStringAsFixed(0)}kg x ${set.reps}",
                                                            style: GoogleFonts.shareTechMono(
                                                              fontSize: 10,
                                                              color: Colors.grey,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                )
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    )
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
