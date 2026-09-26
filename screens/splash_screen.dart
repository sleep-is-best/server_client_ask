import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../main.dart'; // To access initializeService and dbService if they are there, but I should probably move them to a better place or just import.
import '../config.dart';
import 'login_screen.dart';
import 'desktop_main_layout.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      debugPrint("🚀 Starting App Initialization...");
      
      // 1. Core Services
      await NotificationService.init().timeout(const Duration(seconds: 5));
      debugPrint("🔔 Notifications initialized");
      
      await dbService.database.timeout(const Duration(seconds: 8));
      debugPrint("📦 Database initialized");
      
      try {
        await initializeService().timeout(const Duration(seconds: 5));
        debugPrint("⚙️ Background Service initialized");
      } catch (e) {
        debugPrint("⚠️ Background Service warning: $e");
      }

      // 2. Auto Login Check
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('student_id')) {
        final studentId = prefs.getString('student_id')!;
        AppConfig.currentStudentId = studentId;
        debugPrint("👤 Found saved user: $studentId");
        
        // Fast path: if we have local data, consider going to main screen immediately
        // and updating in background, or just do a quick check.
        try {
          final student = await ApiService.login(studentId: studentId)
              .timeout(const Duration(seconds: 3));
              
          if (student != null) {
            debugPrint("✅ Auto-login successful");
            AppConfig.currentStudentId = student['studentId']?.toString() ?? studentId;
            if (mounted) {
              if (MediaQuery.of(context).size.width > 900) {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => DesktopMainLayout(myUserId: student['studentId']))
                );
              } else {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => MainNavigationScreen(myUserId: student['studentId']))
                );
              }
              return;
            }
          }
        } catch (e) {
          debugPrint("🌐 Login check failed (probably offline): $e");
          // If offline but we have a studentId, we might still want to enter the app
          if (mounted) {
            if (MediaQuery.of(context).size.width > 900) {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => DesktopMainLayout(myUserId: studentId))
              );
            } else {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => MainNavigationScreen(myUserId: studentId))
              );
            }
            return;
          }
        }
      }

      // 3. Fallback to Login
      debugPrint("👋 Navigating to Login Screen");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen())
        );
      }
    } catch (e, stack) {
      debugPrint("❌ Critical Initialization Error: $e");
      debugPrint(stack.toString());
      if (mounted) {
        // Even on error, try to go to login instead of staying on black screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen())
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_rounded, size: 100, color: Color(0xFF4A6572)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'PLATFORM EDU',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A6572),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
