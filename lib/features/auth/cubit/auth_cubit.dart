import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:torq/core/services/auth_service.dart';
import 'package:torq/core/services/cloud_sync_service.dart';
import 'package:torq/features/auth/cubit/auth_state.dart';

/// Manages Firebase Auth sign-in/sign-up/guest sessions and cloud sync actions.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.authService,
    required this.cloudSyncService,
  }) : super(AuthState(user: authService.currentUser)) {
    _authSub = authService.authStateChanges.listen((user) {
      emit(state.copyWith(user: user, clearUser: user == null));
    });
  }

  final AuthService authService;
  final CloudSyncService cloudSyncService;
  StreamSubscription<AuthUser?>? _authSub;

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        clearStatusMessage: true,
      ),
    );
    try {
      final user = await authService.signInWithEmail(
        email: email,
        password: password,
      );
      emit(state.copyWith(user: user, isLoading: false));
      return true;
    } on FirebaseAuthException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _friendlyAuthError(e),
        ),
      );
      return false;
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        clearStatusMessage: true,
      ),
    );
    try {
      final user = await authService.signUpWithEmail(
        displayName: displayName,
        email: email,
        password: password,
      );
      emit(state.copyWith(user: user, isLoading: false));
      return true;
    } on FirebaseAuthException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _friendlyAuthError(e),
        ),
      );
      return false;
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        clearStatusMessage: true,
      ),
    );
    try {
      final user = await authService.signInWithGoogle();
      emit(state.copyWith(user: user, isLoading: false));
      return true;
    } on FirebaseAuthException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: _friendlyAuthError(e),
        ),
      );
      return false;
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> continueAsGuest() async {
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        clearStatusMessage: true,
      ),
    );
    try {
      if (authService.isFirebaseReady) {
        final user = await authService.signInAnonymously();
        emit(state.copyWith(user: user, isLoading: false));
      } else {
        emit(state.copyWith(isLoading: false));
      }
      return true;
    } catch (e) {
      // Allow offline usage even if anonymous sign-in fails without network.
      emit(state.copyWith(isLoading: false));
      return true;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        clearStatusMessage: true,
      ),
    );
    try {
      await authService.sendPasswordResetEmail(email);
      emit(
        state.copyWith(
          isLoading: false,
          statusMessage: 'Password reset link sent to $email.',
        ),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(isLoading: false, error: _friendlyAuthError(e)));
      return false;
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
      return false;
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    await authService.signOut();
    emit(state.copyWith(clearUser: true, isLoading: false));
  }

  /// Pushes local Drift data to Firestore via the Node.js backend.
  Future<bool> syncPushToCloud() async {
    emit(
      state.copyWith(
        isSyncing: true,
        clearError: true,
        clearStatusMessage: true,
      ),
    );
    try {
      final token = await authService.getIdToken();
      if (token == null) {
        emit(
          state.copyWith(
            isSyncing: false,
            error: 'Please sign in first to sync with the cloud.',
          ),
        );
        return false;
      }
      final result = await cloudSyncService.pushToCloud(
        firebaseIdToken: token,
      );
      emit(
        state.copyWith(
          isSyncing: false,
          statusMessage:
              'Synced ${result.vehiclesCount} vehicles and ${result.maintenanceCount} records to cloud.',
        ),
      );
      return true;
    } catch (e) {
      emit(state.copyWith(isSyncing: false, error: e.toString()));
      return false;
    }
  }

  /// Pulls Firestore data from the Node.js backend and restores it into Drift.
  Future<bool> syncPullFromCloud() async {
    emit(
      state.copyWith(
        isSyncing: true,
        clearError: true,
        clearStatusMessage: true,
      ),
    );
    try {
      final token = await authService.getIdToken();
      if (token == null) {
        emit(
          state.copyWith(
            isSyncing: false,
            error: 'Please sign in first to restore from the cloud.',
          ),
        );
        return false;
      }
      final summary = await cloudSyncService.pullFromCloud(
        firebaseIdToken: token,
      );
      emit(
        state.copyWith(
          isSyncing: false,
          statusMessage:
              'Restored ${summary.vehiclesCount} vehicles and ${summary.maintenanceCount} records from cloud.',
        ),
      );
      return true;
    } catch (e) {
      emit(state.copyWith(isSyncing: false, error: e.toString()));
      return false;
    }
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearStatusMessage: true));
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' => 'No account found with that email.',
      'wrong-password' || 'invalid-credential' => 'Invalid email or password.',
      'email-already-in-use' => 'An account already exists for that email.',
      'weak-password' => 'Password must be at least 6 characters.',
      'invalid-email' => 'Please enter a valid email address.',
      'network-request-failed' => 'Network error. Check your internet connection.',
      _ => e.message ?? 'Authentication failed (${e.code}).',
    };
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
