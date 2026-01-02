import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      final userCredential = await _auth.signInWithPopup(googleProvider);

      return userCredential.user;
    } catch (e) {
      SnackBar(content: Text('Failed to submit: ${e.toString()}'));
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}