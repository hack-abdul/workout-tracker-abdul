import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import 'workout_tab.dart';
import 'history_tab.dart';
import 'analytics_tab.dart';
import 'settings_tab.dart';
import 'nutrition_tab.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _preferences = {'defaultRestDuration': 60, 'weightUnit': 'kg'};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() => _isLoading = true);
    final prefs = await _firebaseService.loadPreferences();
    setState(() {
      _preferences = prefs;
      _isLoading = false;
    });
  }

  void _onPreferencesChange(Map<String, dynamic> newPrefs) {
    setState(() {
      _preferences = newPrefs;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF030712),
        body: Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB))),
        ),
      );
    }

    final List<Widget> tabs = [
      WorkoutTab(userId: widget.userId, preferences: _preferences),
      HistoryTab(userId: widget.userId),
      AnalyticsTab(userId: widget.userId),
      NutritionTab(userId: widget.userId),
      SettingsTab(
        userId: widget.userId,
        preferences: _preferences,
        onPreferencesChange: _onPreferencesChange,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF030712), // Zinc-950
      body: Stack(
        children: [
          // Active Tab content
          SafeArea(
            child: tabs[_currentIndex],
          ),
          
          // Bottom Navigation Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withOpacity(0.85), // Gray-900 with opacity
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF374151).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.fitness_center_rounded, "Workout"),
                  _buildNavItem(1, Icons.calendar_today_rounded, "History"),
                  _buildNavItem(2, Icons.trending_up_rounded, "Analytics"),
                  _buildNavItem(3, Icons.monitor_weight_rounded, "Cut"),
                  _buildNavItem(4, Icons.settings_rounded, "Settings"),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF9CA3AF),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
