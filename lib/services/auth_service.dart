import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of User Auth State
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get Current Firebase User
  User? get currentUser => _auth.currentUser;

  // Register user
  Future<UserModel> registerWithEmailAndPassword({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;
      if (user == null) {
        throw Exception('User creation failed');
      }

      // 2. Create user document in Firestore
      final userModel = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        phoneNumber: phoneNumber.trim(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during registration');
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  // Login user
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during login');
    } catch (e) {
      throw Exception('Failed to log in: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get User Profile from Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
