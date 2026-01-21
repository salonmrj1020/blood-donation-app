import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../utils/admin_reset.dart';
import 'admin_dashboard_screen.dart';
import 'splash_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _adminService = AdminService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Admin credentials
  static const String ADMIN_EMAIL = 'demo2026@gmail.com';
  static const String ADMIN_PASSWORD = 'demo123';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _adminLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Check if credentials match admin credentials
    if (email != ADMIN_EMAIL || password != ADMIN_PASSWORD) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid admin credentials'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sign out any existing user first
      await FirebaseAuth.instance.signOut();
      
      UserCredential? credential;
      
      // Try to sign in first
      try {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('Admin signed in successfully');
      } on FirebaseAuthException catch (e) {
        print('Sign in failed: ${e.code} - ${e.message}');
        
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          // Try to create the account
          try {
            credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            print('Admin account created successfully');
            
            // Create user profile in Firestore
            await FirebaseFirestore.instance
                .collection('users')
                .doc(credential.user!.uid)
                .set({
              'firstName': 'Admin',
              'lastName': 'User',
              'email': email,
              'phone': '+1234567890',
              'createdAt': Timestamp.now(),
              'profileCompleted': true,
            });
            
          } catch (createError) {
            print('Account creation failed: $createError');
            throw Exception('Failed to create admin account: $createError');
          }
        } else if (e.code == 'wrong-password') {
          throw Exception('Invalid password for admin account');
        } else {
          throw Exception('Authentication error: ${e.message}');
        }
      }

      // Verify we have a user
      if (credential?.user == null) {
        throw Exception('Authentication failed - no user credential');
      }

      final user = credential!.user!;
      print('Admin authenticated: ${user.email}');

      // Create admin record in Firestore
      try {
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .set({
          'email': email,
          'name': 'Admin User',
          'createdAt': Timestamp.now(),
          'role': 'admin',
          'permissions': [
            'verify_donors',
            'reject_donors',
            'view_all_donors',
            'manage_blood_requests',
            'view_analytics'
          ],
        }, SetOptions(merge: true));
        
        print('Admin record created/updated in Firestore');
      } catch (firestoreError) {
        print('Firestore error (non-critical): $firestoreError');
        // Don't fail the login for Firestore errors
      }

      // Navigate to admin dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      }

    } catch (e) {
      print('Admin login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetAdminAccount() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Admin Account'),
        content: const Text('This will delete the existing admin account and allow you to create a fresh one. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Sign out first
        await FirebaseAuth.instance.signOut();
        
        // Try to delete the user if it exists
        try {
          final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: ADMIN_EMAIL,
            password: ADMIN_PASSWORD,
          );
          
          if (credential.user != null) {
            final uid = credential.user!.uid;
            
            // Delete Firestore records
            await FirebaseFirestore.instance.collection('admins').doc(uid).delete();
            await FirebaseFirestore.instance.collection('users').doc(uid).delete();
            
            // Delete the user account
            await credential.user!.delete();
            
            print('Admin account deleted successfully');
          }
        } catch (e) {
          print('No existing admin account found or error deleting: $e');
        }
        
        // Sign out again to clear any cached state
        await FirebaseAuth.instance.signOut();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin account reset successfully. You can now login with fresh credentials.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting admin account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                
                // Header
                const Center(
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 80,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 24),
                
                const Center(
                  child: Text(
                    'Admin Login',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                const Center(
                  child: Text(
                    'Blood Donation Management System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // Login Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Credentials',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Admin Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter admin email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter admin password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _adminLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Login as Admin',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Demo Credentials Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Demo Admin Credentials',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Email: demo2026@gmail.com\nPassword: demo123',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Back Button
                Center(
                  child: TextButton(
                    onPressed: () {
                      // Check if we can pop back
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        // If we can't pop, navigate to main app
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const SplashScreen()),
                          (route) => false,
                        );
                      }
                    },
                    child: const Text(
                      'Back to Main App',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}