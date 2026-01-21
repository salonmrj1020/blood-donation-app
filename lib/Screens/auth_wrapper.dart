import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:blood_donation_app/Screens/splash_screen.dart';
import 'package:blood_donation_app/Screens/home_screen.dart';
import 'package:blood_donation_app/Screens/email_verification_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is signed in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          
          // Check if email is verified
          if (user.emailVerified) {
            // Email verified - go directly to home screen (no profile setup required)
            return const HomeScreen();
          } else {
            // Email not verified - go to verification screen
            return const EmailVerificationScreen();
          }
        }

        // User is not signed in - show splash/onboarding
        return const SplashScreen();
      },
    );
  }
}