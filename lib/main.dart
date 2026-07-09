import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/firebase_service.dart';
import 'firebase_options.dart';

Object? startupError;
StackTrace? startupStackTrace;

void main() async {
  print("=== SYSTEM: main() started ===");
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print("=== SYSTEM: WidgetsFlutterBinding initialized ===");
    
    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    print("=== SYSTEM: Orientations configured ===");
    
    // Initialize Firebase
    print("=== SYSTEM: Firebase initialization starting ===");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("=== SYSTEM: Firebase initialization successful ===");
  } catch (e, stack) {
    startupError = e;
    startupStackTrace = stack;
    print("=== SYSTEM: ERROR DURING STARTUP: $e ===");
    print(stack);
  }
  
  runApp(const AestheticsApp());
}

class AestheticsApp extends StatelessWidget {
  const AestheticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        title: 'Aesthetics Startup Error',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppTheme.background,
        ),
        home: Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        "Startup Error",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "An error occurred while initializing the application. Please review the details below:",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: SelectableText(
                          "$startupError\n\n$startupStackTrace",
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Asthetics',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 64),
                const SizedBox(height: 16),
                const Text(
                  "Firebase Not Initialized",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Firebase apps collection is empty. Ensure Firebase is configured correctly in main.dart.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final firebaseService = FirebaseService();
    
    return StreamBuilder<User?>(
      stream: firebaseService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return HomeScreen(userId: snapshot.data!.uid);
        }
        
        return const LoginScreen();
      },
    );
  }
}
