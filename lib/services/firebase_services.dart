import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';


class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Robust internet connection check using connectivity_plus + HTTP HEAD request
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        debugPrint("Internet lookup success: ${result[0]}");
        return true;
      }
      debugPrint("Internet lookup failed");
      return false;
    } on SocketException catch (e) {
      debugPrint("SocketException during internet lookup: $e");
      return false;
    } catch (e) {
      debugPrint("Exception during internet lookup: $e");
      return false;
    }
  }

  // Private helper to get any user field with error and connectivity handling
  Future<dynamic> _getUserField(String email, String fieldName) async {
    if (!await _hasInternetConnection()) {
      debugPrint("No internet connection. Cannot fetch user field: $fieldName");
      return null;
    }
    try {
      final doc = await _firestore.collection('users').doc(email).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()![fieldName];
      }
      return null;
    } on FirebaseException catch (e) {
      debugPrint("Firebase error fetching $fieldName: $e");
      return null;
    } catch (e) {
      debugPrint("Error fetching $fieldName: $e");
      return null;
    }
  }

  // Sign in with email and password
  Future<String?> signIn(String email, String password) async {
    if (!await _hasInternetConnection()) {
      return "No internet connection";
    }
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Successful login
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign up with email, password, firstName, lastName, and isAdmin status
  Future<String?> signUp(String email, String password, String firstName, String lastName, bool isAdmin) async {
    if (!await _hasInternetConnection()) {
      return "No internet connection";
    }
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);

      // Save user info to Firestore after successful sign-up
      await saveUserInfo(
        email: email,
        firstName: firstName,
        lastName: lastName,
        isAdmin: isAdmin,
      );

      return null; // Successful sign-up
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Save user information to Firestore
  Future<void> saveUserInfo({
    required String email,
    required String firstName,
    required String lastName,
    required bool isAdmin,
  }) async {
    if (!await _hasInternetConnection()) {
      debugPrint("No internet connection. Cannot save user info");
      return;
    }
    try {
      await _firestore.collection('users').doc(email).set({
        'firstName': firstName,
        'lastName': lastName,
        'isAdmin': isAdmin,
      });
    } catch (e) {
      debugPrint("Error saving user info: $e");
    }
  }

  // Get user's first name
  Future<String?> getUserFirstName(String email) async {
    final value = await _getUserField(email, 'firstName');
    return value?.toString();
  }

  // Get user's last name
  Future<String?> getUserLastName(String email) async {
    final value = await _getUserField(email, 'lastName');
    return value?.toString();
  }

  // Get user's isAdmin role
  Future<bool> getUserRole(String email) async {
    final value = await _getUserField(email, 'isAdmin');
    if (value is bool) return value;
    return false;
  }

  // Get full user info map (firstName, lastName, isAdmin)
  Future<Map<String, dynamic>?> getUserInfo(String email) async {
    if (!await _hasInternetConnection()) {
      debugPrint("No internet connection. Cannot fetch user info");
      return null;
    }
    try {
      final userDoc = await _firestore.collection('users').doc(email).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user info: $e");
      return null;
    }
  }

  // Get the current user's UID
  String? getCurrentUserUID() {
    User? user = _auth.currentUser;
    return user?.uid;
  }

  // Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password for user
  Future<String?> resetPassword(String email) async {
    if (!await _hasInternetConnection()) {
      return "No internet connection";
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Change the user's password
  Future<String?> changePassword(String newPassword) async {
    if (!await _hasInternetConnection()) {
      return "No internet connection";
    }
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Get current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Check if user is authenticated
  bool isUserAuthenticated() {
    return _auth.currentUser != null;
  }

  // Check if email is already in use for sign-up
  Future<bool> isEmailInUse(String email) async {
    if (!await _hasInternetConnection()) {
      debugPrint("No internet connection. Cannot check email in use");
      return false;
    }
    try {
      final result = await _auth.fetchSignInMethodsForEmail(email);
      return result.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking email in use: $e");
      return false;
    }
  }

  // Update user profile (first and last name)
  Future<String?> updateUserProfile({
    required String firstName,
    required String lastName,
  }) async {
    if (!await _hasInternetConnection()) {
      return "No internet connection";
    }
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.email).update({
          'firstName': firstName,
          'lastName': lastName,
        });
        return null; // Success
      }
      return "User not authenticated";
    } catch (e) {
      return e.toString();
    }
  }
}
