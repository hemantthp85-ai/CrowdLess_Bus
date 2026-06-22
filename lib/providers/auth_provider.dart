import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

// Provide the AuthService instance
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Provide the Auth State stream (listens to auth state changes from Firebase)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Provide the current user's profile details from Firestore
final userProfileProvider = FutureProvider.family<UserModel?, String>((ref, uid) async {
  return ref.read(authServiceProvider).getUserProfile(uid);
});

// Auth State class for managing Login/Signup loading & error states in the UI
class AuthUIState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  AuthUIState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  AuthUIState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return AuthUIState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Reset if null
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// StateNotifier for UI forms to watch and update loading/errors
class AuthNotifier extends StateNotifier<AuthUIState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthUIState());

  Future<void> login(String email, String password) async {
    state = AuthUIState(isLoading: true);
    try {
      await _authService.signInWithEmailAndPassword(email: email, password: password);
      state = AuthUIState(isSuccess: true);
    } catch (e) {
      state = AuthUIState(errorMessage: e.toString());
    }
  }

  Future<void> signup({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    state = AuthUIState(isLoading: true);
    try {
      await _authService.registerWithEmailAndPassword(
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );
      state = AuthUIState(isSuccess: true);
    } catch (e) {
      state = AuthUIState(errorMessage: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

// Provide the StateNotifier to screens
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthUIState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
