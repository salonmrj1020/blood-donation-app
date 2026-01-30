import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if current user's email is verified
  bool get isEmailVerified {
    final user = currentUser;
    return user?.emailVerified ?? false;
  }

  // Login with email and password
  Future<String?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user != null) {
        // Check if email is verified
        if (!user.emailVerified) {
          // Sign out the user since email is not verified
          await _auth.signOut();
          return 'Please verify your email before signing in. Check your inbox for verification link.';
        }
        
        return null; // Success
      } else {
        return 'Login failed';
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email format';
      } else if (e.code == 'user-disabled') {
        return 'This account has been disabled';
      } else if (e.code == 'too-many-requests') {
        return 'Too many failed attempts. Please try again later';
      }
      return e.message ?? 'Login failed';
    } catch (e) {
      return 'An error occurred';
    }
  }

  // Sign up with email and password
  Future<String?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      print('Starting signup for: $email');
      
      // Create user with timeout
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Registration timeout'),
      );

      final user = result.user;
      if (user != null) {
        // Send email verification
        await user.sendEmailVerification();
        print('Email verification sent to: $email');

        // Store user data in Firestore
        await _storeUserData(
          user.uid,
          email,
          firstName,
          lastName,
          phone,
        );

        return null; // Success
      } else {
        return 'Failed to create user account';
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      
      if (e.code == 'weak-password') {
        return 'The password provided is too weak';
      } else if (e.code == 'email-already-in-use') {
        return 'An account already exists for this email';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email format';
      }
      return e.message ?? 'Registration failed';
    } catch (e) {
      print('General Error: $e');
      return 'Registration failed: ${e.toString()}';
    }
  }

  // Store user data in Firestore
  Future<void> _storeUserData(
    String uid,
    String email,
    String firstName,
    String lastName,
    String phone,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'createdAt': Timestamp.now(),
        'phoneVerified': false,
        'addressCompleted': false,
      });
      print('User data stored successfully');
    } catch (e) {
      print('Error storing user data: $e');
      rethrow;
    }
  }

  // Google Sign In
  Future<String?> googleSignIn() async {
    try {
      print('Starting Google Sign-In...');
      print('🔍 DEBUG: Current SHA-1 should be: 48:AD:4A:0B:16:3B:05:F1:E4:37:9A:E6:DD:C1:C0:FA:0C:B3:89:65');
      
      // Sign out first to ensure clean state
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google sign-in cancelled by user');
        return 'Google sign-in cancelled';
      }

      print('Google user signed in: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Failed to get Google authentication tokens');
        return 'Failed to get authentication tokens';
      }

      print('Got Google authentication tokens');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Created Firebase credential');

      UserCredential result = await _auth.signInWithCredential(credential);
      final user = result.user;
      
      if (user != null) {
        print('Firebase authentication successful for: ${user.email}');
        
        // Check if this is a new user
        if (result.additionalUserInfo?.isNewUser == true) {
          print('New Google user detected');
          // New Google user - send email verification
          await user.sendEmailVerification();
          print('Email verification sent to Google user: ${user.email}');
          
          // Store user data
          await _storeGoogleUserData(user);
          
          // Sign out the user so they must verify email first
          await _auth.signOut();
          return 'verification_required'; // Special return code for new Google users
        } else {
          print('Existing Google user');
          // Existing user - check if email is verified
          if (!user.emailVerified) {
            print('Email not verified for existing user');
            await _auth.signOut();
            return 'Please verify your email before signing in. Check your inbox for verification link.';
          }
          
          print('Email verified - login successful');
          // Email is verified - allow login
          return null; // Success
        }
      }
      
      print('Firebase user is null');
      return 'Google sign-in failed';
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      return e.message ?? 'Google sign-in failed';
    } catch (e) {
      print('General Google Sign-In Error: $e');
      
      // Handle specific Google Sign-In errors more gracefully
      final errorString = e.toString();
      if (errorString.contains('ApiException: 10') || 
          errorString.contains('sign_in_failed') ||
          errorString.contains('DEVELOPER_ERROR')) {
        print('🚨 SHA-1 FINGERPRINT MISMATCH DETECTED!');
        print('📋 Current SHA-1: 48:AD:4A:0B:16:3B:05:F1:E4:37:9A:E6:DD:C1:C0:FA:0C:B3:89:65');
        print('📋 Expected in Firebase: f40e1efa9bd67f32213713fde83a15c772689afc');
        print('🔧 Please update Firebase Console with the correct SHA-1 fingerprint');
        return 'Configuration Error: Google Sign-In requires SHA-1 fingerprint update in Firebase Console. Please contact developer to fix this issue.';
      } else if (errorString.contains('network_error') || 
                 errorString.contains('NETWORK_ERROR')) {
        return 'Network error. Please check your internet connection and try again.';
      } else if (errorString.contains('sign_in_cancelled')) {
        return 'Google sign-in was cancelled';
      }
      
      return 'Google Sign-In is currently unavailable. Please use email/password login.';
    }
  }

  // Store Google user data
  Future<void> _storeGoogleUserData(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        final nameParts = user.displayName?.split(' ') ?? ['', ''];
        await _firestore.collection('users').doc(user.uid).set({
          'firstName': nameParts.isNotEmpty ? nameParts[0] : '',
          'lastName': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'createdAt': Timestamp.now(),
          'phoneVerified': user.phoneNumber != null,
          'addressCompleted': false,
        });
      }
    } catch (e) {
      print('Error storing Google user data: $e');
    }
  }

  // Send email verification
  Future<String?> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return null; // Success
      } else if (user?.emailVerified == true) {
        return 'Email is already verified';
      } else {
        return 'No user logged in';
      }
    } catch (e) {
      return 'Failed to send verification email: ${e.toString()}';
    }
  }

  // Reload user to check verification status
  Future<void> reloadUser() async {
    final user = currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  // Check verification status
  Future<bool> checkEmailVerification() async {
    final user = currentUser;
    if (user != null) {
      await user.reload();
      return user.emailVerified;
    }
    return false;
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }

  // Get current user data as stream for real-time updates
  Stream<Map<String, dynamic>?> getCurrentUserDataStream() {
    final user = currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  // Update user profile
  Future<String?> updateUserProfile({
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
    String? country,
    String? city,
    String? bloodType,
    double? weight,
    String? occupation,
  }) async {
    try {
      final user = currentUser;
      if (user == null) return 'User not authenticated';

      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      // Only update fields that are provided
      if (firstName != null) updateData['firstName'] = firstName;
      if (lastName != null) updateData['lastName'] = lastName;
      if (phone != null) updateData['phone'] = phone;
      if (dateOfBirth != null) updateData['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
      if (gender != null) updateData['gender'] = gender;
      if (country != null) updateData['country'] = country;
      if (city != null) updateData['city'] = city;
      if (bloodType != null) updateData['bloodType'] = bloodType;
      if (weight != null) updateData['weight'] = weight;
      if (occupation != null) updateData['occupation'] = occupation;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      return null; // Success
    } catch (e) {
      print('Error updating user profile: $e');
      return 'Failed to update profile';
    }
  }

  // Check if user has completed profile setup
  Future<bool> hasCompletedProfile() async {
    try {
      final userData = await getCurrentUserData();
      if (userData == null) return false;

      // Check if essential profile fields are filled
      return userData['firstName'] != null &&
             userData['firstName'].toString().isNotEmpty &&
             userData['phone'] != null &&
             userData['phone'].toString().isNotEmpty;
    } catch (e) {
      print('Error checking profile completion: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Delete current user account (for testing purposes)
  Future<String?> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) return 'No user logged in';

      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Try to delete donor profile if exists
      try {
        await _firestore.collection('donors').doc(user.uid).delete();
      } catch (e) {
        // Donor profile might not exist, ignore error
      }

      // Delete the user account
      await user.delete();
      
      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Please log in again before deleting your account';
      }
      return e.message ?? 'Failed to delete account';
    } catch (e) {
      return 'Failed to delete account: ${e.toString()}';
    }
  }

  // Update profile image URL
  Future<String?> updateProfileImage(String imageUrl) async {
    try {
      final user = currentUser;
      if (user == null) return 'User not authenticated';

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'profileImage': imageUrl,
        'updatedAt': Timestamp.now(),
      });

      return null; // Success
    } catch (e) {
      print('Error updating profile image: $e');
      return 'Failed to update profile image';
    }
  }
}