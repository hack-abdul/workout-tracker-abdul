import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/nutrition.dart';
import '../services/firebase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NutritionDiaryScreen — Day-wise calorie & protein log with one-liners
// ─────────────────────────────────────────────────────────────────────────────
class NutritionDiaryScreen extends StatefulWidget {
  final String userId;
  final NutritionPlan plan;
  final List<DailyNutritionLog> nutritionLogs;

  const NutritionDiaryScreen({
    super.key,
    required this.userId,
    required this.plan,
    required this.nutritionLogs,
  });

  @override
  State<NutritionDiaryScreen> createState() => _NutritionDiaryScreenState();
}

class _NutritionDiaryScreenState extends State<NutritionDiaryScreen> {
  final FirebaseService _service = FirebaseService();
  late List<DailyNutritionLog> _logs;
  DateTime? _editingDate;
  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _logs = List.from(widget.nutritionLogs);
  }

  @override
  void dispose() {
    _calCtrl.dispose();
    _protCtrl.dispose();
    super.dispose();
  }

  // One-liner smart comment based on performance
  String _oneLiner(DailyNutritionLog log) {
    final calTarget = widget.plan.dailyCalorieTarget;
    final protTarget = widget.plan.dailyProteinGoalG;
    final calPct = log.caloriesConsumed / calTarget;
    final protPct = log.proteinConsumed / protTarget;

    if (calPct > 1.1 && protPct < 0.8) return '🔴 Too many calories & low protein — adjust next day';
    if (calPct > 1.1) return '🔴 Over calorie target — trim portions tomorrow';
    if (calPct < 0.7) return '⚠️ Too few calories — avoid extreme deficits';
    if (protPct < 0.7) return '⚠️ Protein low — add a high-protein meal or shake';
    if (protPct < 0.9 && calPct <= 1.05) return '🟡 Decent day — boost protein slightly';
    if (calPct <= 1.0 && protPct >= 0.9) return '✅ On target — great discipline!';
    if (calPct <= 1.05 && protPct >= 1.0) return '🟢 Perfect day — crushing it!';
    return '✅ Good going — stay consistent!';
  }

  Color _oneLinerColor(DailyNutritionLog log) {
    final calPct = log.caloriesConsumed / widget.plan.dailyCalorieTarget;
    final protPct = log.proteinConsumed / widget.plan.dailyProteinGoalG;
    if (calPct > 1.1 || calPct < 0.7) return const Color(0xFFEF4444);
    if (protPct < 0.9) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  Future<void> _saveEntry(String dateStr) async {
    final cal = double.tryParse(_calCtrl.text);
    final prot = double.tryParse(_protCtrl.text);
    if (cal == null || prot == null) return;

    setState(() => _isSaving = true);
    final log = DailyNutritionLog(date: dateStr, caloriesConsumed: cal, proteinConsumed: prot);
    await _service.saveDailyNutritionLog(log);

    final idx = _logs.indexWhere((l) => l.date == dateStr);
    setState(() {
      if (idx >= 0) {
        _logs[idx] = log;
      } else {
        _logs.add(log);
        _logs.sort((a, b) => b.date.compareTo(a.date));
      }
      _editingDate = null;
      _isSaving = false;
    });
    _calCtrl.clear();
    _protCtrl.clear();
  }

  void _startEdit(String dateStr, {DailyNutritionLog? existing}) {
    setState(() {
      _editingDate = DateTime.parse(dateStr);
      _calCtrl.text = existing?.caloriesConsumed.toStringAsFixed(0) ?? '';
      _protCtrl.text = existing?.proteinConsumed.toStringAsFixed(0) ?? '';
    });
  }

  // Build the last 30 days entries (today down to 30 days ago)
  List<DateTime> _buildDateRange() {
    final today = DateTime.now();
    final start = DateTime.parse(widget.plan.startDate);
    final days = <DateTime>[];
    for (int i = 0; i <= today.difference(start).inDays && i < 60; i++) {
      days.add(DateTime(today.year, today.month, today.day - i));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildDateRange();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calorie Diary', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            Text('Day-wise intake log', style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Text(
                '${widget.plan.dailyCalorieTarget.toStringAsFixed(0)} kcal target',
                style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final isToday = dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());
          final log = _logs.firstWhere((l) => l.date == dateStr, orElse: () => DailyNutritionLog(date: dateStr, caloriesConsumed: -1, proteinConsumed: -1));
          final hasLog = log.caloriesConsumed >= 0;
          final isEditing = _editingDate != null && DateFormat('yyyy-MM-dd').format(_editingDate!) == dateStr;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.5),
              border: Border.all(
                color: isToday
                    ? const Color(0xFF10B981).withOpacity(0.4)
                    : AppTheme.borderLight.withOpacity(0.25),
                width: isToday ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Row: date info + values
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Date label
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isToday ? 'Today' : DateFormat('EEE').format(date),
                                style: GoogleFonts.outfit(
                                  color: isToday ? const Color(0xFF10B981) : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                DateFormat('d MMM').format(date),
                                style: GoogleFonts.inter(color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Values or placeholder
                          if (hasLog) ...[
                            _statPill(
                              icon: Icons.local_fire_department_rounded,
                              value: '${log.caloriesConsumed.toStringAsFixed(0)}',
                              target: widget.plan.dailyCalorieTarget.toStringAsFixed(0),
                              color: log.caloriesConsumed > widget.plan.dailyCalorieTarget * 1.1
                                  ? const Color(0xFFEF4444)
                                  : log.caloriesConsumed >= widget.plan.dailyCalorieTarget * 0.7
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 8),
                            _statPill(
                              icon: Icons.egg_alt_rounded,
                              value: '${log.proteinConsumed.toStringAsFixed(0)}g',
                              target: '${widget.plan.dailyProteinGoalG.toStringAsFixed(0)}g',
                              color: log.proteinConsumed >= widget.plan.dailyProteinGoalG * 0.9
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 8),
                          ] else ...[
                            Text('No entry', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
                            const SizedBox(width: 8),
                          ],
                          // Edit / Add button
                          GestureDetector(
                            onTap: () => _startEdit(dateStr, existing: hasLog ? log : null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.border,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Row(children: [
                                Icon(
                                  hasLog ? Icons.edit_rounded : Icons.add_rounded,
                                  size: 12,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  hasLog ? 'Edit' : 'Add',
                                  style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      // One-liner comment
                      if (hasLog && !isEditing) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _oneLinerColor(log).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _oneLinerColor(log).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _oneLiner(log),
                                  style: GoogleFonts.inter(
                                    color: _oneLinerColor(log),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Inline edit form
                      if (isEditing) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _inlineField(ctrl: _calCtrl, hint: 'Calories')),
                          const SizedBox(width: 8),
                          Expanded(child: _inlineField(ctrl: _protCtrl, hint: 'Protein (g)')),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : () => _saveEntry(dateStr),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isSaving
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() {
                              _editingDate = null;
                              _calCtrl.clear();
                              _protCtrl.clear();
                            }),
                            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statPill({required IconData icon, required String value, required String target, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(value, style: GoogleFonts.outfit(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
          Text('/$target', style: GoogleFonts.inter(color: color.withOpacity(0.6), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _inlineField({required TextEditingController ctrl, required String hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
        filled: true,
        fillColor: AppTheme.border,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.borderLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Color(0xFF10B981), width: 1.5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nutrition30DayReportScreen — 30-day performance slab analysis
// ─────────────────────────────────────────────────────────────────────────────
class Nutrition30DayReportScreen extends StatefulWidget {
  final String userId;
  final NutritionPlan plan;
  final List<DailyNutritionLog> nutritionLogs;
  final List<WeightLog> weightLogs;

  const Nutrition30DayReportScreen({
    super.key,
    required this.userId,
    required this.plan,
    required this.nutritionLogs,
    required this.weightLogs,
  });

  @override
  State<Nutrition30DayReportScreen> createState() => _Nutrition30DayReportScreenState();
}

class _Nutrition30DayReportScreenState extends State<Nutrition30DayReportScreen> {
  int _selectedSlab = 0; // 0 = latest slab, 1 = previous, etc.

  List<_SlabData> _buildSlabs() {
    final start = DateTime.parse(widget.plan.startDate);
    final today = DateTime.now();
    final totalDays = today.difference(start).inDays;
    final slabs = <_SlabData>[];

    // Build 30-day slabs from start date
    int slabIndex = 0;
    while (true) {
      final slabStart = start.add(Duration(days: slabIndex * 30));
      if (slabStart.isAfter(today)) break;
      final slabEnd = slabStart.add(const Duration(days: 29));
      final clampedEnd = slabEnd.isAfter(today) ? today : slabEnd;

      // Find logs in range
      final logsInRange = widget.nutritionLogs.where((l) {
        final d = DateTime.parse(l.date);
        return !d.isBefore(slabStart) && !d.isAfter(clampedEnd);
      }).toList();

      final daysInSlab = clampedEnd.difference(slabStart).inDays + 1;

      slabs.add(_SlabData(
        index: slabIndex,
        start: slabStart,
        end: clampedEnd,
        daysInSlab: daysInSlab,
        logs: logsInRange,
        plan: widget.plan,
        weightLogs: widget.weightLogs,
      ));
      slabIndex++;
    }

    return slabs.reversed.toList(); // Most recent first
  }

  @override
  Widget build(BuildContext context) {
    final slabs = _buildSlabs();
    final today = DateTime.now();
    final start = DateTime.parse(widget.plan.startDate);
    final daysSinceStart = today.difference(start).inDays;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('30-Day Reports', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            Text('Performance slabs', style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
      body: daysSinceStart < 7
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Slab selector chips
                if (slabs.length > 1) ...[
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: slabs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final isSelected = _selectedSlab == i;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedSlab = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF6366F1) : AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? const Color(0xFF6366F1) : AppTheme.borderLight),
                            ),
                            child: Text(
                              i == 0 ? 'Latest' : 'Period ${slabs.length - i}',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Slab report
                _SlabReport(slab: slabs[_selectedSlab], plan: widget.plan),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderLight.withOpacity(0.4)),
              ),
              child: const Icon(Icons.hourglass_empty_rounded, size: 48, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            Text('Keep Building Your Data', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              'The 30-day report needs at least 7 days of data to generate meaningful insights. Log your daily intake consistently and come back in a few days!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF818CF8)),
                const SizedBox(width: 8),
                Text(
                  'Started: ${DateFormat('d MMM yyyy').format(DateTime.parse(widget.plan.startDate))}',
                  style: GoogleFonts.inter(color: const Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlabData {
  final int index;
  final DateTime start;
  final DateTime end;
  final int daysInSlab;
  final List<DailyNutritionLog> logs;
  final NutritionPlan plan;
  final List<WeightLog> weightLogs;

  _SlabData({
    required this.index,
    required this.start,
    required this.end,
    required this.daysInSlab,
    required this.logs,
    required this.plan,
    required this.weightLogs,
  });

  int get loggedDays => logs.length;
  double get logRatePct => daysInSlab > 0 ? (loggedDays / daysInSlab) * 100 : 0;

  double get avgCalories => logs.isEmpty ? 0 : logs.map((l) => l.caloriesConsumed).reduce((a, b) => a + b) / logs.length;
  double get avgProtein => logs.isEmpty ? 0 : logs.map((l) => l.proteinConsumed).reduce((a, b) => a + b) / logs.length;

  double get calAdherencePct {
    if (logs.isEmpty) return 0;
    final onTarget = logs.where((l) {
      final r = l.caloriesConsumed / plan.dailyCalorieTarget;
      return r >= 0.85 && r <= 1.1;
    }).length;
    return (onTarget / logs.length) * 100;
  }

  double get proteinHitRatePct {
    if (logs.isEmpty) return 0;
    final hit = logs.where((l) => l.proteinConsumed >= plan.dailyProteinGoalG * 0.9).length;
    return (hit / logs.length) * 100;
  }

  double get totalDeficit {
    return logs.fold(0.0, (sum, l) => sum + (plan.dailyCalorieTarget - l.caloriesConsumed));
  }

  double get impliedWeightLossKg => totalDeficit / 7700;

  double get score {
    if (logs.isEmpty) return 0;
    return (logRatePct * 0.3) + (calAdherencePct * 0.4) + (proteinHitRatePct * 0.3);
  }

  String get grade {
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B+';
    if (score >= 60) return 'B';
    if (score >= 50) return 'C';
    if (score >= 35) return 'D';
    return 'F';
  }

  Color get gradeColor {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 60) return const Color(0xFF6366F1);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get verdict {
    if (logs.isEmpty) return 'No data logged in this period. Start tracking daily to see your performance!';
    if (score >= 90) return '🏆 Outstanding! You nailed the plan this period — consistency like this will produce real results.';
    if (score >= 80) return '⭐ Excellent work! Nearly perfect adherence. Keep this up to hit your goal weight.';
    if (score >= 70) return '💪 Solid performance! A few inconsistent days held you back — tighten up the off-days.';
    if (score >= 60) return '🟡 Decent effort. You\'re broadly on plan but leaving some progress on the table.';
    if (score >= 50) return '⚠️ Mixed results. Too many missed logs or calorie overshoots. Recommit this period.';
    return '🔴 Tough period. Logging gaps and calorie misses stacked up. Restart fresh — every day is a new chance.';
  }
}

class _SlabReport extends StatelessWidget {
  final _SlabData slab;
  final NutritionPlan plan;

  const _SlabReport({required this.slab, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [slab.gradeColor.withOpacity(0.15), AppTheme.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: slab.gradeColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${DateFormat('d MMM').format(slab.start)} – ${DateFormat('d MMM yyyy').format(slab.end)}',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  slab.daysInSlab < 30 ? '${slab.daysInSlab} days (ongoing)' : '30-Day Period',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ]),
              const Spacer(),
              Column(children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: slab.gradeColor.withOpacity(0.15),
                    border: Border.all(color: slab.gradeColor, width: 2),
                  ),
                  child: Center(
                    child: Text(slab.grade, style: GoogleFonts.outfit(color: slab.gradeColor, fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Grade', style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Metrics grid
        Row(children: [
          Expanded(child: _metricCard('Days Logged', '${slab.loggedDays}/${slab.daysInSlab}', Icons.calendar_today_rounded, const Color(0xFF6366F1), '${slab.logRatePct.toStringAsFixed(0)}% tracked')),
          const SizedBox(width: 10),
          Expanded(child: _metricCard('In Calorie Zone', '${slab.calAdherencePct.toStringAsFixed(0)}%', Icons.local_fire_department_rounded, const Color(0xFFF59E0B), '85–110% of target')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _metricCard('Protein Hit', '${slab.proteinHitRatePct.toStringAsFixed(0)}%', Icons.egg_alt_rounded, const Color(0xFFEC4899), '≥90% of ${plan.dailyProteinGoalG.toStringAsFixed(0)}g goal')),
          const SizedBox(width: 10),
          Expanded(child: _metricCard('Est. Fat Loss', '${slab.impliedWeightLossKg.toStringAsFixed(2)} kg', Icons.trending_down_rounded, const Color(0xFF10B981), 'from logged deficit')),
        ]),
        const SizedBox(height: 16),

        // Averages row
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.5),
            border: Border.all(color: AppTheme.borderLight.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Period Averages', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _avgRow('Avg Daily Calories', '${slab.avgCalories.toStringAsFixed(0)} kcal', '${plan.dailyCalorieTarget.toStringAsFixed(0)} kcal target', const Color(0xFFF59E0B)),
              const SizedBox(height: 8),
              _avgRow('Avg Daily Protein', '${slab.avgProtein.toStringAsFixed(0)} g', '${plan.dailyProteinGoalG.toStringAsFixed(0)} g target', const Color(0xFFEC4899)),
              const SizedBox(height: 8),
              _avgRow('Total Calorie Deficit', '${slab.totalDeficit.toStringAsFixed(0)} kcal', 'over ${slab.loggedDays} tracked days', const Color(0xFF10B981)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Verdict card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: slab.gradeColor.withOpacity(0.06),
            border: Border.all(color: slab.gradeColor.withOpacity(0.25)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.comment_rounded, color: slab.gradeColor, size: 16),
                const SizedBox(width: 8),
                Text('Our Assessment', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 10),
              Text(slab.verdict, style: GoogleFonts.inter(color: Colors.grey[200], fontSize: 13, height: 1.6)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Score breakdown bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.5),
            border: Border.all(color: AppTheme.borderLight.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Score Breakdown', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _scoreBar('Tracking Rate', slab.logRatePct / 100, const Color(0xFF6366F1), '30% weight'),
              const SizedBox(height: 10),
              _scoreBar('In Calorie Zone', slab.calAdherencePct / 100, const Color(0xFFF59E0B), '40% weight'),
              const SizedBox(height: 10),
              _scoreBar('Protein Goal Hit', slab.proteinHitRatePct / 100, const Color(0xFFEC4899), '30% weight'),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Overall Score', style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${slab.score.toStringAsFixed(1)} / 100', style: GoogleFonts.outfit(color: slab.gradeColor, fontSize: 16, fontWeight: FontWeight.w900)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Legend / explainer card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border.all(color: const Color(0xFF1E293B)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.help_outline_rounded, color: Color(0xFF64748B), size: 14),
                const SizedBox(width: 6),
                Text('How each metric works', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              _legendRow('📅 Days Logged', 'How many days in this period you logged your intake vs. total days in the period.'),
              _legendRow('🔥 In Calorie Zone', 'The % of logged days where your calories fell between 85% and 110% of your ${plan.dailyCalorieTarget.toStringAsFixed(0)} kcal target — not too low, not over.'),
              _legendRow('🥚 Protein Hit', 'The % of logged days where you reached at least 90% of your ${plan.dailyProteinGoalG.toStringAsFixed(0)}g protein goal. Protein protects muscle during a cut.'),
              _legendRow('📉 Est. Fat Loss', 'Calorie deficit summed across all logged days ÷ 7,700 (kcal per kg of fat). This is an estimate — actual loss depends on sleep, stress, and water retention.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(desc, style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11, height: 1.5)),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 1),
        Text(sub, style: GoogleFonts.inter(color: color.withOpacity(0.7), fontSize: 10)),
      ]),
    );
  }

  Widget _avgRow(String label, String value, String sub, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12)),
            Text(sub, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 10)),
          ]),
        ),
        Text(value, style: GoogleFonts.outfit(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _scoreBar(String label, double value, Color color, String weight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 12)),
          Row(children: [
            Text('${(value * 100).toStringAsFixed(0)}%', style: GoogleFonts.outfit(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            Text(weight, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 9)),
          ]),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
