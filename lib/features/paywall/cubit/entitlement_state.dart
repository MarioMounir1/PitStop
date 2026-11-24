import 'package:equatable/equatable.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class EntitlementState extends Equatable {
  const EntitlementState({
    this.isPro = false,
    this.offerings,
    this.isLoading = false,
    this.error,
  });

  final bool isPro;
  final Offerings? offerings;
  final bool isLoading;
  final String? error;

  EntitlementState copyWith({
    bool? isPro,
    Offerings? offerings,
    bool clearOfferings = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return EntitlementState(
      isPro: isPro ?? this.isPro,
      offerings: clearOfferings ? null : (offerings ?? this.offerings),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [isPro, offerings, isLoading, error];
}
