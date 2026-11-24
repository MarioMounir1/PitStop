import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:torq/core/services/monetization_service.dart';
import 'package:torq/features/paywall/cubit/entitlement_state.dart';

/// Manages Torq Pro entitlement status, RevenueCat offerings, and purchases.
class EntitlementCubit extends Cubit<EntitlementState> {
  EntitlementCubit(this._monetizationService)
      : super(const EntitlementState());

  final MonetizationService _monetizationService;

  bool get isDebugFallback => _monetizationService.isDebugFallback;

  /// Loads current Pro entitlement status and available store offerings.
  Future<void> loadEntitlements() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _monetizationService.initialize();
      final isPro = await _monetizationService.checkProStatus();
      final offerings = await _monetizationService.getOfferings();
      emit(
        state.copyWith(
          isPro: isPro,
          offerings: offerings,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }

  /// Purchases a RevenueCat [package] and updates [EntitlementState.isPro].
  Future<bool> purchasePackage(Package package) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final isPro = await _monetizationService.purchasePackage(package);
      emit(state.copyWith(isPro: isPro, isLoading: false, clearError: true));
      return isPro;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        emit(state.copyWith(isLoading: false, clearError: true));
        return false;
      }
      emit(
        state.copyWith(
          isLoading: false,
          error: e.message ?? 'Purchase failed. Please try again.',
        ),
      );
      return false;
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
      return false;
    }
  }

  /// Completes a simulated Pro purchase when RevenueCat runs in debug fallback mode.
  Future<bool> purchaseDebugFallback() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final isPro = await _monetizationService.purchaseDebugFallback();
    emit(state.copyWith(isPro: isPro, isLoading: false, clearError: true));
    return isPro;
  }

  /// Restores store purchases and refreshes entitlement state.
  Future<bool> restorePurchases() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final isPro = await _monetizationService.restorePurchases();
      emit(state.copyWith(isPro: isPro, isLoading: false, clearError: true));
      return isPro;
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Could not restore purchases: $e',
        ),
      );
      return false;
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}
