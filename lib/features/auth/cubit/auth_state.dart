import 'package:equatable/equatable.dart';
import 'package:torq/core/services/auth_service.dart';

class AuthState extends Equatable {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.statusMessage,
  });

  final AuthUser? user;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final String? statusMessage;

  bool get isSignedIn => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    bool clearError = false,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
      statusMessage:
          clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }

  @override
  List<Object?> get props => [
        user,
        isLoading,
        isSyncing,
        error,
        statusMessage,
      ];
}
