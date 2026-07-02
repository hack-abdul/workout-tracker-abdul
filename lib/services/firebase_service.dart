import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout.dart';
import '../models/nutrition.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get userId => _auth.currentUser?.uid;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email/Password sign in
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Email/Password sign up
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Load user preferences
  Future<Map<String, dynamic>> loadPreferences() async {
    if (userId == null) return {'defaultRestDuration': 60, 'weightUnit': 'kg'};
    try {
      final snap = await _db
          .doc('users/$userId/settings/preferences')
          .get()
          .timeout(const Duration(seconds: 3));
      if (snap.exists) {
        return snap.data() ?? {'defaultRestDuration': 60, 'weightUnit': 'kg'};
      }
    } catch (e) {
      print("=== SYSTEM ERROR: loadPreferences failed or timed out: $e ===");
    }
    return {'defaultRestDuration': 60, 'weightUnit': 'kg'};
  }

  // Save user preferences
  Future<void> savePreferences(int restDuration, String unit) async {
    if (userId == null) return;
    await _db.doc('users/$userId/settings/preferences').set({
      'defaultRestDuration': restDuration,
      'weightUnit': unit,
    }, SetOptions(merge: true));
  }

  // Load custom weekly plan
  Future<Map<String, WorkoutPlan>?> loadCustomPlan() async {
    if (userId == null) return null;
    try {
      final snap = await _db
          .doc('users/$userId/plan/routine')
          .get()
          .timeout(const Duration(seconds: 3));
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final plan = <String, WorkoutPlan>{};
        data.forEach((key, value) {
          plan[key] = WorkoutPlan.fromJson(Map<String, dynamic>.from(value as Map));
        });
        return plan;
      }
    } catch (e) {
      print("=== SYSTEM ERROR: loadCustomPlan failed or timed out: $e ===");
      // Fallback to cache
      try {
        final snap = await _db
            .doc('users/$userId/plan/routine')
            .get(const GetOptions(source: Source.cache));
        if (snap.exists && snap.data() != null) {
          print("=== SYSTEM: Loaded custom plan from CACHE after timeout ===");
          final data = snap.data()!;
          final plan = <String, WorkoutPlan>{};
          data.forEach((key, value) {
            plan[key] = WorkoutPlan.fromJson(Map<String, dynamic>.from(value as Map));
          });
          return plan;
        }
      } catch (cacheError) {
        print("=== SYSTEM ERROR: loadCustomPlan cache read failed: $cacheError ===");
      }
    }
    return null;
  }

  // Save custom weekly plan
  Future<void> saveCustomPlan(Map<String, WorkoutPlan> plan) async {
    if (userId == null) return;
    final data = plan.map((key, value) => MapEntry(key, value.toJson()));
    await _db.doc('users/$userId/plan/routine').set(data);
  }

  // Load daily log
  Future<WorkoutLog?> loadDailyLog(String date) async {
    if (userId == null) return null;
    try {
      final snap = await _db
          .doc('users/$userId/logs/$date')
          .get()
          .timeout(const Duration(seconds: 3));
      if (snap.exists && snap.data() != null) {
        return WorkoutLog.fromJson(snap.data()!, date);
      }
    } catch (e) {
      print("=== SYSTEM ERROR: loadDailyLog failed or timed out: $e ===");
      // Fallback to cache
      try {
        final snap = await _db
            .doc('users/$userId/logs/$date')
            .get(const GetOptions(source: Source.cache));
        if (snap.exists && snap.data() != null) {
          print("=== SYSTEM: Loaded daily log from CACHE after timeout ===");
          return WorkoutLog.fromJson(snap.data()!, date);
        }
      } catch (cacheError) {
        print("=== SYSTEM ERROR: loadDailyLog cache read failed: $cacheError ===");
      }
    }
    return null;
  }

  // Save daily log
  Future<void> saveDailyLog(WorkoutLog log) async {
    if (userId == null) return;
    await _db.doc('users/$userId/logs/${log.date}').set(log.toJson());
  }

  // Delete daily log
  Future<void> deleteDailyLog(String date) async {
    if (userId == null) return;
    await _db.doc('users/$userId/logs/$date').delete();
  }

  // Load history logs
  Future<List<WorkoutLog>> loadHistoryLogs({int? limit}) async {
    if (userId == null) {
      print("=== SYSTEM WARNING: loadHistoryLogs called but userId is NULL ===");
      return [];
    }
    try {
      var query = _db
          .collection('users/$userId/logs')
          .orderBy('date', descending: true);
          
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final snap = await query
          .get()
          .timeout(const Duration(seconds: 3));
      
      return _parseHistorySnap(snap);
    } catch (e) {
      print("=== SYSTEM ERROR: loadHistoryLogs failed or timed out: $e ===");
      // Fallback to cache
      try {
        var query = _db
            .collection('users/$userId/logs')
            .orderBy('date', descending: true);
            
        if (limit != null) {
          query = query.limit(limit);
        }
        final snap = await query.get(const GetOptions(source: Source.cache));
        print("=== SYSTEM: Loaded history logs from CACHE after timeout ===");
        return _parseHistorySnap(snap);
      } catch (cacheError) {
        print("=== SYSTEM ERROR: loadHistoryLogs cache read failed: $cacheError ===");
        return [];
      }
    }
  }

  List<WorkoutLog> _parseHistorySnap(QuerySnapshot<Map<String, dynamic>> snap) {
    final logs = <WorkoutLog>[];
    for (var doc in snap.docs) {
      try {
        final data = doc.data();
        final log = WorkoutLog.fromJson(data, doc.id);
        logs.add(log);
      } catch (parseError) {
        print("=== SYSTEM ERROR parsing doc ${doc.id}: $parseError ===");
      }
    }
    
    final filteredLogs = logs
        .where((log) => log.exercises.values.any((sets) => sets.any((s) => s.completed)))
        .toList();
        
    return filteredLogs;
  }

  // ─── Nutrition: Profile ───────────────────────────────────────────────────

  Future<void> saveNutritionProfile(NutritionProfile profile) async {
    if (userId == null) return;
    await _db.doc('users/$userId/nutrition/profile').set(profile.toJson());
  }

  Future<NutritionProfile?> loadNutritionProfile() async {
    if (userId == null) return null;
    try {
      final snap = await _db
          .doc('users/$userId/nutrition/profile')
          .get()
          .timeout(const Duration(seconds: 3));
      if (snap.exists && snap.data() != null) {
        return NutritionProfile.fromJson(snap.data()!);
      }
    } catch (e) {
      print('=== SYSTEM ERROR: loadNutritionProfile: $e ===');
    }
    return null;
  }

  // ─── Nutrition: Plan ──────────────────────────────────────────────────────

  Future<void> saveNutritionPlan(NutritionPlan plan) async {
    if (userId == null) return;
    await _db.doc('users/$userId/nutrition/plan').set(plan.toJson());
  }

  Future<NutritionPlan?> loadNutritionPlan() async {
    if (userId == null) return null;
    try {
      final snap = await _db
          .doc('users/$userId/nutrition/plan')
          .get()
          .timeout(const Duration(seconds: 3));
      if (snap.exists && snap.data() != null) {
        return NutritionPlan.fromJson(snap.data()!);
      }
    } catch (e) {
      print('=== SYSTEM ERROR: loadNutritionPlan: $e ===');
    }
    return null;
  }

  // ─── Nutrition: Daily logs ────────────────────────────────────────────────

  Future<void> saveDailyNutritionLog(DailyNutritionLog log) async {
    if (userId == null) return;
    await _db
        .doc('users/$userId/nutrition/daily_logs/entries/${log.date}')
        .set(log.toJson());
  }

  Future<List<DailyNutritionLog>> loadNutritionLogs() async {
    if (userId == null) return [];
    try {
      final snap = await _db
          .collection('users/$userId/nutrition/daily_logs/entries')
          .orderBy('date', descending: false)
          .get()
          .timeout(const Duration(seconds: 5));
      return snap.docs
          .map((d) => DailyNutritionLog.fromJson(d.data(), d.id))
          .toList();
    } catch (e) {
      print('=== SYSTEM ERROR: loadNutritionLogs: $e ===');
      return [];
    }
  }

  // ─── Nutrition: Weight logs ───────────────────────────────────────────────

  Future<void> saveWeightLog(WeightLog log) async {
    if (userId == null) return;
    await _db
        .doc('users/$userId/nutrition/weight_logs/entries/${log.date}')
        .set(log.toJson());
  }

  Future<List<WeightLog>> loadWeightLogs() async {
    if (userId == null) return [];
    try {
      final snap = await _db
          .collection('users/$userId/nutrition/weight_logs/entries')
          .orderBy('date', descending: false)
          .get()
          .timeout(const Duration(seconds: 5));
      return snap.docs
          .map((d) => WeightLog.fromJson(d.data(), d.id))
          .toList();
    } catch (e) {
      print('=== SYSTEM ERROR: loadWeightLogs: $e ===');
      return [];
    }
  }
}
