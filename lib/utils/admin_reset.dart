import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReset {
  static const String ADMIN_EMAIL = 'demo2026@gmail.com';
  static const String ADMIN_PASSWORD = 'demo123';
  
  static Future<void> resetAdminAccount() async {
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      
      // Try to delete existing admin user
      try {
        final userCredential = await auth.signInWithEmailAndPassword(
          email: ADMIN_EMAIL,
          password: ADMIN_PASSWORD,
        );
        
        if (userCredential.user != null) {
          // Delete admin record from Firestore
          await firestore.collection('admins').doc(userCredential.user!.uid).delete();
          
          // Delete user record from Firestore
          await firestore.collection('users').doc(userCredential.user!.uid).delete();
          
          // Delete the user account
          await userCredential.user!.delete();
          
          print('Admin account reset successfully');
        }
      } catch (e) {
        print('No existing admin account found or error deleting: $e');
      }
      
      // Sign out to clear any cached auth state
      await auth.signOut();
      
    } catch (e) {
      print('Error resetting admin account: $e');
    }
  }
}