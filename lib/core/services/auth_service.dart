import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Lightweight authenticated user model decoupled from platform SDK types.
class AuthUser extends Equatable {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });

  factory AuthUser.fromFirebaseUser(User user) {
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      isAnonymous: user.isAnonymous,
    );
  }

  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  @override
  List<Object?> get props => [uid, email, displayName, isAnonymous];
}

/// Wraps [FirebaseAuth] and [GoogleSignIn] with graceful fallback when
/// Firebase is not initialized (e.g. desktop or widget tests).
class AuthService {
  bool _googleInitialized = false;

  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  AuthUser? get currentUser {
    if (!isFirebaseReady) return null;
    final user = _auth.currentUser;
    return user != null ? AuthUser.fromFirebaseUser(user) : null;
  }

  Stream<AuthUser?> get authStateChanges {
    if (!isFirebaseReady) return Stream<AuthUser?>.value(null);
    return _auth.authStateChanges().map(
          (user) => user != null ? AuthUser.fromFirebaseUser(user) : null,
        );
  }

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureReady();
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return AuthUser.fromFirebaseUser(cred.user!);
  }

  Future<AuthUser> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    _ensureReady();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final trimmedName = displayName.trim();
    if (trimmedName.isNotEmpty) {
      await cred.user?.updateDisplayName(trimmedName);
      await cred.user?.reload();
    }
    final refreshed = _auth.currentUser ?? cred.user!;
    return AuthUser.fromFirebaseUser(refreshed);
  }

  Future<AuthUser> signInWithGoogle() async {
    _ensureReady();
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google Sign-In did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCred = await _auth.signInWithCredential(credential);
    return AuthUser.fromFirebaseUser(userCred.user!);
  }

  Future<AuthUser> signInAnonymously() async {
    _ensureReady();
    final cred = await _auth.signInAnonymously();
    return AuthUser.fromFirebaseUser(cred.user!);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _ensureReady();
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (!isFirebaseReady) return null;
    return _auth.currentUser?.getIdToken(forceRefresh);
  }

  Future<void> signOut() async {
    if (!isFirebaseReady) return;
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      debugPrint('GoogleSignIn.signOut skipped: $e');
    }
    await _auth.signOut();
  }

  void _ensureReady() {
    if (!isFirebaseReady) {
      throw StateError(
        'Firebase is not initialized on this platform. Run on Android/iOS to use Firebase Auth.',
      );
    }
  }
}
