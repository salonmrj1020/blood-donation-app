import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:blood_donation_app/Screens/home_screen.dart';
import 'package:blood_donation_app/Screens/signup_screen.dart';
import 'package:blood_donation_app/Screens/email_verification_screen.dart';
import 'package:blood_donation_app/Screens/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await _authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      // Check if email is verified
      final isVerified = _authService.isEmailVerified;
      
      if (mounted) {
        if (isVerified) {
          // Email is verified - check if profile is completed
          final hasCompletedProfile = await _authService.hasCompletedProfile();
          
          if (hasCompletedProfile) {
            // Profile completed - go to home screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else {
            // Profile not completed - go directly to home 
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        } else {
          // Email not verified - navigate to verification screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
          );
        }
      }
    } else {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);

    final error = await _authService.googleSignIn();

    setState(() => _isLoading = false);

    if (error == null) {
      // Success - user is verified, check if profile is completed
      if (mounted) {
        final hasCompletedProfile = await _authService.hasCompletedProfile();
        
        if (hasCompletedProfile) {
          // Profile completed - go to home screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          // Profile not completed - go to profile setup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } else if (error == 'verification_required') {
      // New Google user needs email verification
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
        );
      }
    } else if (error == 'Google sign-in was cancelled') {
      // User cancelled - don't show error message
      return;
    } else {
      // Show error message with better styling and specific handling
      Color backgroundColor = Colors.red;
      IconData icon = Icons.error_outline;
      
      // Use different colors for different error types
      if (error.contains('Configuration Error') || error.contains('SHA-1')) {
        backgroundColor = Colors.orange;
        icon = Icons.settings;
      } else if (error.contains('Network error')) {
        backgroundColor = Colors.blue;
        icon = Icons.wifi_off;
      } else if (error.contains('not available')) {
        backgroundColor = Colors.grey;
        icon = Icons.info_outline;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: error.contains('Configuration Error') 
                ? SnackBarAction(
                    label: 'Help',
                    textColor: Colors.white,
                    onPressed: () {
                      // Show help dialog
                      _showGoogleSignInHelpDialog();
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom - 40,
            ),
            child: IntrinsicHeight(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bloodtype, size: 90, color: Colors.red),
                    const SizedBox(height: 20),

                    const Text(
                      "Welcome To Blood Donation App",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),

                    // Email field with validation
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Password field with validation
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),

                    // Login button with loading indicator
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: GestureDetector(
                        onLongPress: () {
                          // Hidden admin access - long press on login button
                          Navigator.pushNamed(context, '/admin');
                        },
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Login",
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Forgot password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),

                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text("OR"),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Google sign-in button
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        icon: Image.asset(
                          'assets/images/google.png',
                          width: 24,
                          height: 24,
                        ),
                        label: const Text(
                          "Continue with Google",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                        onPressed: _isLoading ? null : _googleSignIn,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    
                    // Helper text for Google Sign-In
                    Text(
                      "Google Sign-In requires configuration update",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    // Sign up link
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text("Create new account"),
                    ),
                    
                    const SizedBox(height: 20), // Extra padding at bottom
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showGoogleSignInHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Google Sign-In Help'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Google Sign-In Configuration Issue',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'The Google Sign-In feature requires a configuration update in Firebase Console. This is a technical issue that needs to be resolved by the developer.',
              ),
              SizedBox(height: 12),
              Text(
                'What you can do:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• Use email/password login instead'),
              Text('• Contact the developer to fix the configuration'),
              Text('• Try again later after the fix is applied'),
              SizedBox(height: 12),
              Text(
                'Technical Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'SHA-1 fingerprint mismatch between current keystore and Firebase Console configuration.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}