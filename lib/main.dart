import 'package:flutter/material.dart';
import 'package:blood_donation_app/Screens/splash_screen.dart';
import 'package:blood_donation_app/Screens/admin_login_screen.dart';
import 'package:blood_donation_app/Screens/verification_application_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:blood_donation_app/services/notification_service.dart';
import 'package:blood_donation_app/services/blood_request_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service for popup notifications
  try {
    await NotificationService().initialize();
    print('Notification service initialized successfully');
  } catch (e) {
    print(' Error initializing notification service: $e');
  }

  // Start auto-expire check for blood requests
  try {
    // deleteExpired: true means expired requests will be completely deleted
    // Set to false if you want to keep them as "expired" status for records
    await BloodRequestService().startAutoExpireCheck(deleteExpired: true);
    print('Blood request auto-expire check started (delete mode: ON)');
  } catch (e) {
    print(' Error starting auto-expire check: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blood Donation App',
      theme: ThemeData(
        // Professional color scheme
        primarySwatch: Colors.red,
        primaryColor: const Color(0xFFD32F2F), // Professional red
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD32F2F),
          primary: const Color(0xFFD32F2F), // Professional red
          secondary: const Color(0xFF1976D2), // Professional blue
          surface: const Color(0xFFFAFAFA), // Light gray background
          background: const Color(0xFFF5F5F5), // Slightly darker gray
          error: const Color(0xFFF44336), // Professional red for errors
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD32F2F)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/admin': (context) => const AdminLoginScreen(),
        '/verification-application': (context) => const VerificationApplicationScreen(),
      },
    );
  }
}
