import 'dart:math' as math;
import '../theme/app_theme.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/nutrition.dart';
import '../services/firebase_service.dart';
import 'report_card_screen.dart';
import 'nutrition_log_screens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NutritionTab — root widget
// ─────────────────────────────────────────────────────────────────────────────
class NutritionTab extends StatefulWidget {
  final String userId;

  const NutritionTab({super.key, required this.userId});

  @override
  State<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<NutritionTab> {
  final FirebaseService _service = FirebaseService();

  bool _isLoading = true;
  NutritionProfile? _profile;
  NutritionPlan? _plan;
  List<NutritionPlan> _allPlans = [];
  List<DailyNutritionLog> _nutritionLogs = [];
  List<WeightLog> _weightLogs = [];

  // View control: 'setup' | 'dashboard'
  String _view = 'setup';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.loadNutritionProfile(),
      _service.loadAllNutritionPlans(),
      _service.loadNutritionLogs(),
      _service.loadWeightLogs(),
    ]);
    _profile = results[0] as NutritionProfile?;
    _allPlans = results[1] as List<NutritionPlan>;
    
    try {
      _plan = _allPlans.firstWhere((p) => p.status == 'active');
    } catch (_) {
      _plan = null;
    }
    
    _nutritionLogs = results[2] as List<DailyNutritionLog>;
    _weightLogs = results[3] as List<WeightLog>;
    setState(() {
      _isLoading = false;
      _view = (_plan != null) ? 'dashboard' : 'setup';
    });
  }

  Future<void> _onPlanCreated(NutritionProfile profile, NutritionPlan plan) async {
    try {
      await _service.saveNutritionProfile(profile);
      await _service.saveNutritionPlan(plan);
      await _loadData();
    } catch (e) {
      print("=== SYSTEM ERROR: _onPlanCreated failed: $e ===");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save plan: $e'), backgroundColor: Colors.redAccent),
        );
      }
      rethrow;
    }
  }

  void _onCompletePlan(double endWeight, String grade, double score, int loggedDays, double totalDeficit) async {
    if (_plan == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final completedPlan = NutritionPlan(
      id: _plan!.id,
      status: 'completed',
      deficitPercent: _plan!.deficitPercent,
      maintenanceCalories: _plan!.maintenanceCalories,
      dailyCalorieTarget: _plan!.dailyCalorieTarget,
      dailyProteinGoalG: _plan!.dailyProteinGoalG,
      startDate: _plan!.startDate,
      startWeightKg: _plan!.startWeightKg,
      goalWeightKg: _plan!.goalWeightKg,
      estimatedWeeks: _plan!.estimatedWeeks,
      completionDate: today,
      actualEndWeightKg: endWeight,
      overallGrade: grade,
      overallAdherenceScore: score,
      loggedDaysCount: loggedDays,
      totalDeficitKcal: totalDeficit,
    );
    await _service.saveNutritionPlan(completedPlan);
    await _logWeight(endWeight);
    await _loadData();
  }



  Future<void> _logNutrition(double cal, double protein) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log = DailyNutritionLog(
      date: today,
      caloriesConsumed: cal,
      proteinConsumed: protein,
    );
    await _service.saveDailyNutritionLog(log);

    // Refresh logs list locally
    final idx = _nutritionLogs.indexWhere((l) => l.date == today);
    setState(() {
      if (idx >= 0) {
        _nutritionLogs[idx] = log;
      } else {
        _nutritionLogs.add(log);
        _nutritionLogs.sort((a, b) => a.date.compareTo(b.date));
      }
    });
  }

  Future<void> _logWeight(double weightKg) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log = WeightLog(date: today, weightKg: weightKg);
    await _service.saveWeightLog(log);

    final idx = _weightLogs.indexWhere((l) => l.date == today);
    setState(() {
      if (idx >= 0) {
        _weightLogs[idx] = log;
      } else {
        _weightLogs.add(log);
        _weightLogs.sort((a, b) => a.date.compareTo(b.date));
      }
    });
  }

  void _showCompletedPlanDetailsDialog(BuildContext context, NutritionPlan plan) {
    final weightLost = plan.startWeightKg - (plan.actualEndWeightKg ?? plan.startWeightKg);
    final daysInPlan = plan.completionDate != null
        ? DateTime.parse(plan.completionDate!).difference(DateTime.parse(plan.startDate)).inDays + 1
        : plan.estimatedWeeks * 7;
        
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Text(
                "Plan Results Summary",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.08),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.background,
                          border: Border.all(color: const Color(0xFF10B981), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            plan.overallGrade ?? 'N/A',
                            style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Overall Adherence Grade",
                              style: GoogleFonts.inter(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              weightLost > 0 
                                  ? "Lost ${weightLost.toStringAsFixed(1)} kg" 
                                  : "Weight maintained",
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "PLAN DETAILS",
                  style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                _summaryStatRow("Timeline", "${plan.startDate} to ${plan.completionDate ?? 'N/A'}"),
                _summaryStatRow("Actual Duration", "$daysInPlan days"),
                _summaryStatRow("Start Weight", "${plan.startWeightKg.toStringAsFixed(1)} kg"),
                _summaryStatRow("Goal Weight", "${plan.goalWeightKg.toStringAsFixed(1)} kg"),
                _summaryStatRow("Final Weight", "${(plan.actualEndWeightKg ?? 0).toStringAsFixed(1)} kg"),
                _summaryStatRow("Deficit", "${plan.deficitPercent}% (${(plan.maintenanceCalories - plan.dailyCalorieTarget).toStringAsFixed(0)} kcal)"),
                _summaryStatRow("Daily Calorie Target", "${plan.dailyCalorieTarget.toStringAsFixed(0)} kcal"),
                _summaryStatRow("Daily Protein Target", "${plan.dailyProteinGoalG.toStringAsFixed(0)} g"),
                _summaryStatRow("Logged Days", "${plan.loggedDaysCount ?? 0} days"),
                _summaryStatRow("Total Deficit Achieved", "${(plan.totalDeficitKcal ?? 0).toStringAsFixed(0)} kcal"),
                _summaryStatRow("Overall Score", "${(plan.overallAdherenceScore ?? 0).toStringAsFixed(1)}%"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close", style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryStatRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
        ),
      );
    }

    final completedPlans = _allPlans.where((p) => p.status == 'completed').toList();

    if (_view == 'setup') {
      return SetupView(
        existingProfile: _profile,
        existingPlan: _plan,
        onPlanCreated: _onPlanCreated,
        completedPlans: completedPlans,
        onViewCompletedPlan: (plan) => _showCompletedPlanDetailsDialog(context, plan),
      );
    }

    return DashboardView(
      userId: widget.userId,
      plan: _plan!,
      profile: _profile!,
      nutritionLogs: _nutritionLogs,
      weightLogs: _weightLogs,
      completedPlans: completedPlans,
      onLogNutrition: _logNutrition,
      onLogWeight: _logWeight,
      onCompletePlan: _onCompletePlan,
      onViewCompletedPlan: (plan) => _showCompletedPlanDetailsDialog(context, plan),
      onEditPlan: () => setState(() => _view = 'setup'),
      onRefreshLogs: _loadData,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SetupView — Profile + Plan creation form
// ─────────────────────────────────────────────────────────────────────────────
class SetupView extends StatefulWidget {
  final NutritionProfile? existingProfile;
  final NutritionPlan? existingPlan;
  final Future<void> Function(NutritionProfile, NutritionPlan) onPlanCreated;
  final List<NutritionPlan> completedPlans;
  final void Function(NutritionPlan) onViewCompletedPlan;

  const SetupView({
    super.key,
    this.existingProfile,
    this.existingPlan,
    required this.onPlanCreated,
    required this.completedPlans,
    required this.onViewCompletedPlan,
  });

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final _formKey = GlobalKey<FormState>();

  String _gender = 'male';
  int _age = 25;
  double _heightCm = 175;
  double _currentWeightKg = 80;
  double _goalWeightKg = 70;
  String _activityLevel = 'moderate';
  String _unit = 'kg';
  int _deficitPercent = 20;
  double? _userAdjustedProteinGoal;
  bool _isSaving = false;

  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _currentWeightCtrl = TextEditingController();
  final _goalWeightCtrl = TextEditingController();

  static const _activityLabels = {
    'sedentary': 'Sedentary (desk job, no exercise)',
    'light': 'Lightly Active (1–2x/week)',
    'moderate': 'Moderately Active (3–5x/week)',
    'active': 'Very Active (6–7x/week)',
    'extra': 'Extra Active (twice/day training)',
  };

  static const _activityMultipliers = {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'extra': 1.9,
  };

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    if (p != null) {
      _gender = p.gender;
      _age = p.age;
      _heightCm = p.heightCm;
      _currentWeightKg = p.currentWeightKg;
      _goalWeightKg = p.goalWeightKg;
      _activityLevel = p.activityLevel;
      _unit = p.unit;
    }
    final plan = widget.existingPlan;
    if (plan != null) {
      _deficitPercent = plan.deficitPercent;
      _userAdjustedProteinGoal = plan.dailyProteinGoalG;
    }
    _ageCtrl.text = _age.toString();
    _heightCtrl.text = _heightCm.toStringAsFixed(0);
    _currentWeightCtrl.text = _currentWeightKg.toStringAsFixed(1);
    _goalWeightCtrl.text = _goalWeightKg.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _currentWeightCtrl.dispose();
    _goalWeightCtrl.dispose();
    super.dispose();
  }

  double get _tdee {
    final w = _currentWeightKg;
    final h = _heightCm;
    final a = _age.toDouble();
    final base = 10 * w + 6.25 * h - 5 * a;
    final bmr = _gender == 'male' ? base + 5 : base - 161;
    return bmr * (_activityMultipliers[_activityLevel] ?? 1.55);
  }

  double get _dailyTarget => _tdee * (1 - _deficitPercent / 100);

  double get _proteinGoal {
    return _userAdjustedProteinGoal ?? (_goalWeightKg * 2.0);
  }

  int get _estimatedWeeks {
    final dailyDeficit = _tdee - _dailyTarget;
    if (dailyDeficit <= 0) return 9999;
    final weeklyLoss = dailyDeficit * 7 / 7700;
    if (weeklyLoss <= 0) return 9999;
    final weeks = (_currentWeightKg - _goalWeightKg) / weeklyLoss;
    return weeks.ceil();
  }

  void _parseInputs() {
    _age = int.tryParse(_ageCtrl.text) ?? _age;
    _heightCm = double.tryParse(_heightCtrl.text) ?? _heightCm;
    _currentWeightKg = double.tryParse(_currentWeightCtrl.text) ?? _currentWeightKg;
    _goalWeightKg = double.tryParse(_goalWeightCtrl.text) ?? _goalWeightKg;
  }

  Future<void> _startPlan() async {
    _parseInputs();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final profile = NutritionProfile(
        gender: _gender,
        age: _age,
        heightCm: _heightCm,
        currentWeightKg: _currentWeightKg,
        goalWeightKg: _goalWeightKg,
        activityLevel: _activityLevel,
        unit: _unit,
      );
      final plan = NutritionPlan(
        deficitPercent: _deficitPercent,
        maintenanceCalories: _tdee,
        dailyCalorieTarget: _dailyTarget,
        dailyProteinGoalG: _proteinGoal,
        startDate: today,
        startWeightKg: _currentWeightKg,
        goalWeightKg: _goalWeightKg,
        estimatedWeeks: _estimatedWeeks,
      );

      await widget.onPlanCreated(profile, plan);
    } catch (e) {
      print("=== SYSTEM ERROR: SetupView _startPlan failed: $e ===");
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _sectionCard({required String title, required IconData icon, required Color accent, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        border: Border.all(color: AppTheme.borderLight.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _labeledField({required String label, required TextEditingController ctrl, required String hint, String? unit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          onChanged: (_) => setState(() => _parseInputs()),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (double.tryParse(v) == null) return 'Invalid number';
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            suffixText: unit,
            suffixStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
            hintStyle: GoogleFonts.inter(color: const Color(0xFF4B5563), fontSize: 13),
            filled: true,
            fillColor: AppTheme.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF10B981))),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.redAccent)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
        children: [
          const SizedBox(height: 16),

          // Header
          Text('CUT', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10B981), fontWeight: FontWeight.w900)),
          Text('Build Your Plan', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Fill in your stats. We\'ll calculate your optimal cut plan.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // 1. Personal Stats
          _sectionCard(
            title: 'Personal Stats',
            icon: Icons.person_outline_rounded,
            accent: const Color(0xFF10B981),
            children: [
              // Gender
              Text('GENDER', style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Row(children: [
                _genderChip('Male', 'male'),
                const SizedBox(width: 8),
                _genderChip('Female', 'female'),
              ]),
              const SizedBox(height: 16),

              // Unit
              Text('UNIT', style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Row(children: [
                _unitChip('kg'),
                const SizedBox(width: 8),
                _unitChip('lbs'),
              ]),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: _labeledField(label: 'AGE', ctrl: _ageCtrl, hint: '25', unit: 'yrs')),
                const SizedBox(width: 12),
                Expanded(child: _labeledField(label: 'HEIGHT', ctrl: _heightCtrl, hint: '175', unit: 'cm')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _labeledField(label: 'CURRENT WEIGHT', ctrl: _currentWeightCtrl, hint: '80.0', unit: 'kg')),
                const SizedBox(width: 12),
                Expanded(child: _labeledField(label: 'GOAL WEIGHT', ctrl: _goalWeightCtrl, hint: '70.0', unit: 'kg')),
              ]),
              const SizedBox(height: 16),

              // Activity Level
              Text('ACTIVITY LEVEL', style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              ..._activityLabels.entries.map((entry) => _activityRow(entry.key, entry.value)).toList(),
            ],
          ),

          // 2. Your TDEE (computed)
          _sectionCard(
            title: 'Maintenance Calories (TDEE)',
            icon: Icons.local_fire_department_rounded,
            accent: const Color(0xFFF59E0B),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your daily maintenance', style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '${_tdee.toStringAsFixed(0)} kcal / day',
                      style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ]),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 24),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Based on Mifflin-St Jeor formula with your selected activity multiplier.',
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 10),
              ),
            ],
          ),

          // 3. Cut Settings
          _sectionCard(
            title: 'Cut Settings',
            icon: Icons.trending_down_rounded,
            accent: const Color(0xFF6366F1),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Deficit', style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$_deficitPercent%', style: GoogleFonts.outfit(color: const Color(0xFF818CF8), fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF6366F1),
                  inactiveTrackColor: AppTheme.border,
                  thumbColor: const Color(0xFF818CF8),
                  overlayColor: const Color(0xFF6366F1).withOpacity(0.1),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _deficitPercent.toDouble(),
                  min: 10,
                  max: 50,
                  divisions: 8,
                  onChanged: (v) => setState(() => _deficitPercent = v.round()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('10%', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 10)),
                  Text('Recommended: 15–25%', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 10)),
                  Text('50%', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 10)),
                ],
              ),
              const SizedBox(height: 20),
              _resultRow(
                label: 'Daily Calorie Target',
                value: '${_dailyTarget.toStringAsFixed(0)} kcal',
                accent: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 10),
              _resultRow(
                label: 'Daily Deficit',
                value: '${(_tdee - _dailyTarget).toStringAsFixed(0)} kcal',
                accent: const Color(0xFF10B981),
              ),
              const SizedBox(height: 10),
              _resultRow(
                label: 'Estimated Time to Goal',
                value: '${_estimatedWeeks > 500 ? '∞' : _estimatedWeeks} weeks',
                accent: const Color(0xFFF59E0B),
              ),
            ],
          ),

          // 4. Protein
          _sectionCard(
            title: 'Daily Protein Goal',
            icon: Icons.egg_alt_rounded,
            accent: const Color(0xFFEC4899),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Target: ${_proteinGoal.toStringAsFixed(0)} g / day',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            if (_userAdjustedProteinGoal != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _userAdjustedProteinGoal = null),
                                child: Text(
                                  'Reset',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFEC4899),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userAdjustedProteinGoal == null
                              ? 'Suggested: 2 g per kg of goal body weight'
                              : 'Custom Target (Suggested: ${(_goalWeightKg * 2.0).toStringAsFixed(0)} g)',
                          style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.egg_alt_rounded, color: Color(0xFFEC4899), size: 36),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFEC4899),
                  inactiveTrackColor: AppTheme.border,
                  thumbColor: const Color(0xFFF472B6),
                  overlayColor: const Color(0xFFEC4899).withOpacity(0.1),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _proteinGoal.clamp(50.0, 300.0),
                  min: 50,
                  max: 300,
                  divisions: 250, // 1g increments
                  onChanged: (v) {
                    setState(() {
                      _userAdjustedProteinGoal = v.roundToDouble();
                    });
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('50 g', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 9)),
                  Text('Adjustable per gram', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 9)),
                  Text('300 g', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 9)),
                ],
              ),
            ],
          ),

          // CTA Button
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _startPlan,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Icon(Icons.rocket_launch_rounded, color: Colors.white),
            label: Text(
              _isSaving ? 'Starting Plan...' : 'Start My Cut Plan',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '⚠ This is for guidance only, not medical advice.',
              style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 10),
            ),
          ),
          _buildPlanHistoryList(widget.completedPlans, widget.onViewCompletedPlan),
        ],
      ),
    );
  }

  Widget _genderChip(String label, String value) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981).withOpacity(0.15) : AppTheme.background,
          border: Border.all(color: selected ? const Color(0xFF10B981) : AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: GoogleFonts.inter(color: selected ? const Color(0xFF10B981) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _unitChip(String value) {
    final selected = _unit == value;
    return GestureDetector(
      onTap: () => setState(() => _unit = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1).withOpacity(0.15) : AppTheme.background,
          border: Border.all(color: selected ? const Color(0xFF6366F1) : AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(value, style: GoogleFonts.inter(color: selected ? const Color(0xFF818CF8) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _activityRow(String key, String label) {
    final selected = _activityLevel == key;
    return GestureDetector(
      onTap: () => setState(() => _activityLevel = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981).withOpacity(0.08) : Colors.transparent,
          border: Border.all(color: selected ? const Color(0xFF10B981).withOpacity(0.4) : AppTheme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF10B981) : Colors.transparent,
                border: Border.all(color: selected ? const Color(0xFF10B981) : Colors.grey),
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.inter(color: selected ? Colors.white : Colors.grey, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _resultRow({required String label, required String value, required Color accent}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12)),
        Text(value, style: GoogleFonts.outfit(color: accent, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DashboardView — Daily log + progress tracking
// ─────────────────────────────────────────────────────────────────────────────
class DashboardView extends StatefulWidget {
  final String userId;
  final NutritionPlan plan;
  final NutritionProfile profile;
  final List<DailyNutritionLog> nutritionLogs;
  final List<WeightLog> weightLogs;
  final List<NutritionPlan> completedPlans;
  final Future<void> Function(double cal, double protein) onLogNutrition;
  final Future<void> Function(double weightKg) onLogWeight;
  final void Function(double endWeight, String grade, double score, int loggedDays, double totalDeficit) onCompletePlan;
  final void Function(NutritionPlan) onViewCompletedPlan;
  final VoidCallback onEditPlan;
  final VoidCallback? onRefreshLogs;

  const DashboardView({
    super.key,
    required this.userId,
    required this.plan,
    required this.profile,
    required this.nutritionLogs,
    required this.weightLogs,
    required this.completedPlans,
    required this.onLogNutrition,
    required this.onLogWeight,
    required this.onCompletePlan,
    required this.onViewCompletedPlan,
    required this.onEditPlan,
    this.onRefreshLogs,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _calCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _isLoggingNutrition = false;
  bool _isLoggingWeight = false;
  bool _isEditingNutrition = false;

  @override
  void dispose() {
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  DateTime get _startDate => DateTime.parse(widget.plan.startDate);
  int get _dayIndex => DateTime.now().difference(_startDate).inDays;

  DailyNutritionLog? get _todayLog {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      return widget.nutritionLogs.firstWhere((l) => l.date == today);
    } catch (_) {
      return null;
    }
  }

  WeightLog? get _lastWeightLog => widget.weightLogs.isNotEmpty ? widget.weightLogs.last : null;

  bool get _shouldPromptWeightLog {
    if (_lastWeightLog == null) return _dayIndex >= 30;
    final lastDate = DateTime.parse(_lastWeightLog!.date);
    return DateTime.now().difference(lastDate).inDays >= 30;
  }

  double get _cumulativeDeficitKcal {
    double total = 0;
    for (final log in widget.nutritionLogs) {
      final dayDeficit = widget.plan.dailyCalorieTarget - log.caloriesConsumed;
      total += dayDeficit;
    }
    return total;
  }

  double get _impliedCurrentWeight {
    final lossKg = _cumulativeDeficitKcal / 7700;
    return widget.plan.startWeightKg - lossKg;
  }

  Future<void> _logNutrition() async {
    final cal = double.tryParse(_calCtrl.text);
    final protein = double.tryParse(_proteinCtrl.text);
    if (cal == null || protein == null) return;
    setState(() => _isLoggingNutrition = true);
    await widget.onLogNutrition(cal, protein);
    _calCtrl.clear();
    _proteinCtrl.clear();
    setState(() {
      _isLoggingNutrition = false;
      _isEditingNutrition = false;
    });
  }

  Future<void> _logWeight() async {
    final w = double.tryParse(_weightCtrl.text);
    if (w == null) return;
    setState(() => _isLoggingWeight = true);
    await widget.onLogWeight(w);
    _weightCtrl.clear();
    setState(() => _isLoggingWeight = false);
  }

  void _showCompletePlanDialog(BuildContext context) {
    final lastW = _lastWeightLog?.weightKg ?? widget.plan.startWeightKg;
    final endWeightCtrl = TextEditingController(text: lastW.toStringAsFixed(1));
    
    final start = DateTime.parse(widget.plan.startDate);
    final today = DateTime.now();
    final daysInPlan = today.difference(start).inDays + 1;
    
    final planLogs = widget.nutritionLogs.where((l) {
      final d = DateTime.parse(l.date);
      return !d.isBefore(start) && !d.isAfter(today);
    }).toList();
    
    final loggedDays = planLogs.length;
    final logRatePct = daysInPlan > 0 ? (loggedDays / daysInPlan) * 100 : 0.0;
    
    final avgCalories = planLogs.isEmpty 
        ? 0.0 
        : planLogs.map((l) => l.caloriesConsumed).reduce((a, b) => a + b) / planLogs.length;
        
    final avgProtein = planLogs.isEmpty 
        ? 0.0 
        : planLogs.map((l) => l.proteinConsumed).reduce((a, b) => a + b) / planLogs.length;
        
    final targetCal = widget.plan.dailyCalorieTarget;
    final targetProt = widget.plan.dailyProteinGoalG;
    
    final calOnTarget = planLogs.where((l) {
      final r = l.caloriesConsumed / targetCal;
      return r >= 0.85 && r <= 1.1;
    }).length;
    final calAdherencePct = planLogs.isEmpty ? 0.0 : (calOnTarget / planLogs.length) * 100;
    
    final protHit = planLogs.where((l) => l.proteinConsumed >= targetProt * 0.9).length;
    final proteinHitRatePct = planLogs.isEmpty ? 0.0 : (protHit / planLogs.length) * 100;
    
    final totalDeficit = planLogs.fold(0.0, (sum, l) => sum + (targetCal - l.caloriesConsumed));
    
    final score = (logRatePct * 0.3) + (calAdherencePct * 0.4) + (proteinHitRatePct * 0.3);
    
    String getGrade(double s) {
      if (s >= 90) return 'A+';
      if (s >= 80) return 'A';
      if (s >= 70) return 'B+';
      if (s >= 60) return 'B';
      if (s >= 50) return 'C';
      if (s >= 35) return 'D';
      return 'F';
    }
    
    final finalGrade = getGrade(score);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double currentInputWeight = double.tryParse(endWeightCtrl.text) ?? lastW;
            final double weightLost = widget.plan.startWeightKg - currentInputWeight;
            
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                "Finish & Archive Plan",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Enter your final scale weight to complete this cut plan:",
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: endWeightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "Final weight (kg)",
                        suffixText: "kg",
                        suffixStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF10B981)),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "PLAN SUMMARY STATS",
                      style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    _summaryStatRow("Start Weight", "${widget.plan.startWeightKg.toStringAsFixed(1)} kg"),
                    _summaryStatRow("End Weight", "${currentInputWeight.toStringAsFixed(1)} kg"),
                    _summaryStatRow(
                      "Total Weight Lost", 
                      "${weightLost.toStringAsFixed(1)} kg", 
                      valueColor: weightLost > 0 ? const Color(0xFF10B981) : Colors.redAccent,
                    ),
                    _summaryStatRow("Logged Days", "$loggedDays / $daysInPlan days"),
                    _summaryStatRow("Calorie Adherence", "${calAdherencePct.toStringAsFixed(0)}%"),
                    _summaryStatRow("Protein Hit Rate", "${proteinHitRatePct.toStringAsFixed(0)}%"),
                    _summaryStatRow("Final Grade", finalGrade, valueColor: const Color(0xFF10B981)),
                    const SizedBox(height: 12),
                    Text(
                      "This plan will be completed, archived into your Plan History, and you will be returned to the Setup view to create your next plan.",
                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 10, height: 1.4),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCompletePlan(
                      currentInputWeight,
                      finalGrade,
                      score,
                      loggedDays,
                      totalDeficit,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Finish & Archive",
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _summaryStatRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final today = _todayLog;
    final todayCal = today?.caloriesConsumed ?? 0;
    final todayProtein = today?.proteinConsumed ?? 0;
    final todayDeficit = plan.dailyCalorieTarget - todayCal;

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
      children: [
        const SizedBox(height: 16),

        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'CUT PLAN ACTIVE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Progress',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showPlanActionsBottomSheet(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.border.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderLight.withOpacity(0.4)),
                ),
                child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Premium horizontal action pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _actionChip(
                onTap: () => _showCompletePlanDialog(context),
                icon: Icons.check_circle_outline_rounded,
                label: 'Finish Plan',
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              _actionChip(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportCardScreen(userId: widget.userId),
                    ),
                  );
                },
                icon: Icons.stars_rounded,
                label: 'Report Card',
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              _actionChip(
                onTap: widget.onEditPlan,
                icon: Icons.edit_outlined,
                label: 'Edit Plan',
                color: const Color(0xFF818CF8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_dayIndex >= widget.plan.estimatedWeeks * 7) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Text('Plan Timeline Reached!', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Congratulations! You have completed the scheduled weeks for this plan. Tap "Finish Plan" to log your final weight and archive your results.',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _showCompletePlanDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Finish & Archive Results', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Quick-access navigation row
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NutritionDiaryScreen(
                      userId: widget.userId,
                      plan: widget.plan,
                      nutritionLogs: widget.nutritionLogs,
                    ),
                  ),
                ).then((_) => widget.onRefreshLogs?.call());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.borderLight.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xFF60A5FA), size: 15),
                  const SizedBox(width: 6),
                  Text('Calorie Diary', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280), size: 16),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Nutrition30DayReportScreen(
                      userId: widget.userId,
                      plan: widget.plan,
                      nutritionLogs: widget.nutritionLogs,
                      weightLogs: widget.weightLogs,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.borderLight.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.analytics_rounded, color: Color(0xFF818CF8), size: 15),
                  const SizedBox(width: 6),
                  Text('30-Day Slabs', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280), size: 16),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // ── Plan header card ──────────────────────────────────────────────────

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), AppTheme.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              // Progress ring
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: (_dayIndex / (plan.estimatedWeeks * 7.0)).clamp(0.0, 1.0),
                    color: const Color(0xFF10B981),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_dayIndex + 1}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        Text('of\n${plan.estimatedWeeks * 7}d', style: GoogleFonts.inter(color: Colors.grey, fontSize: 8), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _miniWeightCard('Start', '${plan.startWeightKg.toStringAsFixed(1)} kg', Colors.grey),
                    const SizedBox(height: 6),
                    _miniWeightCard('Projected Today', '${_impliedCurrentWeight.toStringAsFixed(1)} kg', const Color(0xFF60A5FA)),
                    const SizedBox(height: 6),
                    _miniWeightCard('Goal', '${plan.goalWeightKg.toStringAsFixed(1)} kg', const Color(0xFF10B981)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Weight log banner ─────────────────────────────────────────────────
        if (_shouldPromptWeightLog)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.monitor_weight_outlined, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Text('Time to weigh yourself!', style: GoogleFonts.outfit(color: const Color(0xFFFBBF24), fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Enter scale weight (kg)',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF4B5563), fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFF59E0B))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoggingWeight ? null : _logWeight,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_isLoggingWeight ? '...' : 'Log', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ]),
              ],
            ),
          ),

        // ── Today's Log ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.5),
            border: Border.all(color: AppTheme.borderLight.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.restaurant_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Text("Today's Intake", style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(DateFormat('EEE, MMM d').format(DateTime.now()), style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
              ]),
              const SizedBox(height: 16),

              // Summary chips
              Row(children: [
                _todayChip(
                  label: 'Calories',
                  value: '${todayCal.toStringAsFixed(0)} / ${plan.dailyCalorieTarget.toStringAsFixed(0)}',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF59E0B),
                  percent: (todayCal / plan.dailyCalorieTarget).clamp(0.0, 1.0),
                ),
                const SizedBox(width: 10),
                _todayChip(
                  label: 'Protein',
                  value: '${todayProtein.toStringAsFixed(0)} / ${plan.dailyProteinGoalG.toStringAsFixed(0)}g',
                  icon: Icons.egg_alt_rounded,
                  color: const Color(0xFFEC4899),
                  percent: (todayProtein / plan.dailyProteinGoalG).clamp(0.0, 1.0),
                ),
              ]),
              const SizedBox(height: 12),

              // Deficit indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: todayDeficit > 0
                      ? const Color(0xFF10B981).withOpacity(0.08)
                      : const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: todayDeficit > 0
                        ? const Color(0xFF10B981).withOpacity(0.2)
                        : const Color(0xFFEF4444).withOpacity(0.2),
                  ),
                ),
                child: Row(children: [
                  Icon(
                    todayDeficit > 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                    color: todayDeficit > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    todayDeficit > 0
                        ? 'In deficit by ${todayDeficit.toStringAsFixed(0)} kcal today'
                        : 'Over by ${(-todayDeficit).toStringAsFixed(0)} kcal today',
                    style: GoogleFonts.inter(
                      color: todayDeficit > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Input fields & buttons
              if (today == null || _isEditingNutrition) ...[
                Row(children: [
                  Expanded(child: _logField(ctrl: _calCtrl, hint: 'Calories eaten', unit: 'kcal')),
                  const SizedBox(width: 10),
                  Expanded(child: _logField(ctrl: _proteinCtrl, hint: 'Protein eaten', unit: 'g')),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoggingNutrition ? null : _logNutrition,
                        icon: _isLoggingNutrition
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _isLoggingNutrition ? 'Saving...' : (today != null ? 'Save Changes' : 'Log Today\'s Intake'),
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    if (today != null) ...[
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditingNutrition = false;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditingNutrition = true;
                        _calCtrl.text = today.caloriesConsumed.toStringAsFixed(0);
                        _proteinCtrl.text = today.proteinConsumed.toStringAsFixed(0);
                      });
                    },
                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                    label: Text(
                      'Edit Today\'s Intake',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.border.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppTheme.borderLight.withOpacity(0.5)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 3-Line Weight Progress Chart ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.5),
            border: Border.all(color: AppTheme.borderLight.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.show_chart_rounded, color: Color(0xFF6366F1), size: 18),
                const SizedBox(width: 8),
                Text('Weight Progress', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 6),
              // Legend
              Row(children: [
                _legendDot(const Color(0xFF60A5FA), 'Projected', dashed: true),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFF10B981), 'Calorie-implied'),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFFF59E0B), 'Actual weight', dotted: true),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: CustomPaint(
                  painter: _WeightChartPainter(
                    plan: widget.plan,
                    nutritionLogs: widget.nutritionLogs,
                    weightLogs: widget.weightLogs,
                    totalDays: widget.plan.estimatedWeeks * 7,
                  ),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 7-Day Calorie & Protein trend ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.5),
            border: Border.all(color: AppTheme.borderLight.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.bar_chart_rounded, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 8),
                Text('Last 7 Days', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: _Last7DaysChart(
                  nutritionLogs: widget.nutritionLogs,
                  calTarget: widget.plan.dailyCalorieTarget,
                  proteinTarget: widget.plan.dailyProteinGoalG,
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _legendDot(const Color(0xFFF59E0B), 'Calories'),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFFEC4899), 'Protein'),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 30-Day Plan Revision Card ─────────────────────────────────────────
        if (_shouldPromptWeightLog && _lastWeightLog != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.06),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 18),
                  const SizedBox(width: 8),
                  Text('30-Day Plan Revision', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 12),
                Text(
                  'Based on your logged weight of ${_lastWeightLog!.weightKg.toStringAsFixed(1)} kg, here is your updated TDEE:',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _revisedTDEERow(),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: widget.onEditPlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Center(
                    child: Text('Revise My Plan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        _buildPlanHistoryList(widget.completedPlans, widget.onViewCompletedPlan),
      ],
    );
  }

  Widget _miniWeightCard(String label, String value, Color color) {
    return Row(children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
      const SizedBox(width: 8),
      Text(value, style: GoogleFonts.outfit(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _todayChip({required String label, required String value, required IconData icon, required Color color, required double percent}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: percent, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 4),
          ),
        ]),
      ),
    );
  }

  Widget _logField({required TextEditingController ctrl, required String hint, required String unit}) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        suffixText: unit,
        suffixStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF4B5563), fontSize: 12),
        filled: true,
        fillColor: AppTheme.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF10B981))),
      ),
    );
  }

  Widget _legendDot(Color color, String label, {bool dashed = false, bool dotted = false}) {
    return Row(children: [
      Container(
        width: 20,
        height: 2,
        decoration: BoxDecoration(
          color: dotted ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(1),
        ),
        child: dotted
            ? Row(children: [
                Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                const SizedBox(width: 3),
                Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              ])
            : null,
      ),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 9)),
    ]);
  }

  Widget _revisedTDEERow() {
    final lastW = _lastWeightLog!.weightKg;
    final profile = widget.profile;
    final base = 10 * lastW + 6.25 * profile.heightCm - 5 * profile.age;
    final bmr = profile.gender == 'male' ? base + 5 : base - 161;
    final newTdee = bmr * profile.activityMultiplier;
    final newTarget = newTdee * (1 - widget.plan.deficitPercent / 100);

    return Column(children: [
      _resultRowD(label: 'Updated TDEE', value: '${newTdee.toStringAsFixed(0)} kcal', accent: const Color(0xFFF59E0B)),
      const SizedBox(height: 6),
      _resultRowD(label: 'Updated Daily Target', value: '${newTarget.toStringAsFixed(0)} kcal', accent: const Color(0xFF818CF8)),
    ]);
  }

  Widget _actionChip({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.25), width: 1.2),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.95),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlanActionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A), // Slate-900
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Plan Management',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Manage your active CUT plan settings and records',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 24),
                _bottomSheetActionTile(
                  onTap: () {
                    Navigator.pop(context);
                    _showCompletePlanDialog(context);
                  },
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Finish & Archive Plan',
                  subtitle: 'Complete this plan and record your final weight',
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                _bottomSheetActionTile(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportCardScreen(userId: widget.userId),
                      ),
                    );
                  },
                  icon: Icons.stars_rounded,
                  title: 'View Report Card',
                  subtitle: 'Generate and review your progress summary',
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 12),
                _bottomSheetActionTile(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onEditPlan();
                  },
                  icon: Icons.edit_outlined,
                  title: 'Edit Current Plan',
                  subtitle: 'Adjust target weights, calories or duration',
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomSheetActionTile({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B), // Slate-800
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _resultRowD({required String label, required String value, required Color accent}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12)),
        Text(value, style: GoogleFonts.outfit(color: accent, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final paintBg = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final paintFg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paintBg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paintFg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// 3-line weight chart
class _WeightChartPainter extends CustomPainter {
  final NutritionPlan plan;
  final List<DailyNutritionLog> nutritionLogs;
  final List<WeightLog> weightLogs;
  final int totalDays;

  const _WeightChartPainter({
    required this.plan,
    required this.nutritionLogs,
    required this.weightLogs,
    required this.totalDays,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDays <= 0) return;

    final startDate = DateTime.parse(plan.startDate);
    final startW = plan.startWeightKg;
    final goalW = plan.goalWeightKg;
    final days = math.max(totalDays, 7);

    // Weight bounds with padding
    final allWeights = [startW, goalW, ...weightLogs.map((l) => l.weightKg)];
    double minW = allWeights.reduce(math.min) - 1.5;
    double maxW = allWeights.reduce(math.max) + 1.5;
    if (maxW - minW < 3) {
      minW -= 1.5;
      maxW += 1.5;
    }

    double toX(int day) => size.width * day / days;
    double toY(double w) => size.height - size.height * (w - minW) / (maxW - minW);

    // Draw grid lines
    final gridPaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      // Y labels
      final w = maxW - (maxW - minW) * i / 4;
      final tp = _buildTextPainter('${w.toStringAsFixed(1)}', 8, Colors.grey);
      tp.layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // ── Line 1: Projected (blue, dashed) ─────────────────────────────────────
    final projPath = Path();
    projPath.moveTo(toX(0), toY(startW));
    projPath.lineTo(toX(days), toY(goalW));

    final projPaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    _drawDashedPath(canvas, projPath, projPaint, dashLen: 8, gapLen: 5);

    // ── Line 2: Calorie-implied weight (green, solid) ─────────────────────────
    if (nutritionLogs.isNotEmpty) {
      final implPath = Path();
      double cumDeficit = 0;
      bool started = false;

      for (final log in nutritionLogs) {
        final logDate = DateTime.parse(log.date);
        final dayIdx = logDate.difference(startDate).inDays;
        if (dayIdx < 0) continue;
        final def = plan.dailyCalorieTarget - log.caloriesConsumed;
        cumDeficit += def;
        final implW = startW - cumDeficit / 7700;
        if (!started) {
          implPath.moveTo(toX(dayIdx), toY(implW));
          started = true;
        } else {
          implPath.lineTo(toX(dayIdx), toY(implW));
        }
      }

      if (started) {
        canvas.drawPath(
          implPath,
          Paint()
            ..color = const Color(0xFF10B981)
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    // ── Line 3: Actual weight logs (orange dots + connecting line) ────────────
    if (weightLogs.isNotEmpty) {
      final actualPath = Path();
      bool started = false;

      for (final log in weightLogs) {
        final logDate = DateTime.parse(log.date);
        final dayIdx = logDate.difference(startDate).inDays;
        if (dayIdx < 0) continue;
        final x = toX(dayIdx);
        final y = toY(log.weightKg);

        if (!started) {
          actualPath.moveTo(x, y);
          started = true;
        } else {
          actualPath.lineTo(x, y);
        }

        canvas.drawCircle(
          Offset(x, y),
          5,
          Paint()..color = const Color(0xFFF59E0B),
        );
        canvas.drawCircle(
          Offset(x, y),
          3,
          Paint()..color = AppTheme.background,
        );
      }

      if (started) {
        canvas.drawPath(
          actualPath,
          Paint()
            ..color = const Color(0xFFF59E0B).withOpacity(0.5)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {double dashLen = 8, double gapLen = 5}) {
    for (final pm in path.computeMetrics()) {
      double dist = 0;
      bool draw = true;
      while (dist < pm.length) {
        final next = math.min(dist + (draw ? dashLen : gapLen), pm.length);
        if (draw) {
          canvas.drawPath(pm.extractPath(dist, next), paint);
        }
        dist = next;
        draw = !draw;
      }
    }
  }

  TextPainter _buildTextPainter(String text, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: ui.TextDirection.ltr,
    );
    return tp;
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) => true;
}

// Last 7 days bar chart widget
class _Last7DaysChart extends StatelessWidget {
  final List<DailyNutritionLog> nutritionLogs;
  final double calTarget;
  final double proteinTarget;

  const _Last7DaysChart({
    required this.nutritionLogs,
    required this.calTarget,
    required this.proteinTarget,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateFormat('yyyy-MM-dd').format(d);
    });

    final dayLogs = {for (final log in nutritionLogs) log.date: log};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((date) {
        final log = dayLogs[date];
        final calRatio = log != null ? (log.caloriesConsumed / calTarget).clamp(0.0, 1.2) : 0.0;
        final proteinRatio = log != null ? (log.proteinConsumed / proteinTarget).clamp(0.0, 1.2) : 0.0;
        final label = DateFormat('E').format(DateTime.parse(date));

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _bar(calRatio, const Color(0xFFF59E0B), 8),
                    const SizedBox(width: 2),
                    _bar(proteinRatio, const Color(0xFFEC4899), 8),
                  ],
                ),
                const SizedBox(height: 4),
                Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 9)),
                if (log != null)
                  Text(
                    '${log.caloriesConsumed.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 7),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _bar(double ratio, Color color, double width) {
    final maxH = 120.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: width,
      height: math.max(4.0, maxH * ratio),
      decoration: BoxDecoration(
        color: ratio > 1.0 ? const Color(0xFFEF4444) : color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

Widget _buildPlanHistoryList(List<NutritionPlan> completedPlans, void Function(NutritionPlan) onViewDetails) {
  if (completedPlans.isEmpty) return const SizedBox.shrink();
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Text(
        "PLAN HISTORY",
        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
      const SizedBox(height: 10),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: completedPlans.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final plan = completedPlans[index];
          final weightLost = plan.startWeightKg - (plan.actualEndWeightKg ?? plan.startWeightKg);
          
          return GestureDetector(
            onTap: () => onViewDetails(plan),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.5),
                border: Border.all(color: AppTheme.borderLight.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Text(
                      plan.overallGrade ?? 'N/A',
                      style: GoogleFonts.shareTechMono(color: const Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weightLost > 0 
                              ? "Lost ${weightLost.toStringAsFixed(1)} kg" 
                              : "Weight Maintained",
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${plan.startDate} to ${plan.completionDate ?? 'N/A'}",
                          style: GoogleFonts.inter(color: Colors.grey, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}
