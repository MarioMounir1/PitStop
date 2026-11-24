import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/features/garage/domain/repositories/garage_repository.dart';
import 'package:torq/features/garage/presentation/bloc/garage_event.dart';
import 'package:torq/features/garage/presentation/bloc/garage_state.dart';

/// BLoC managing the user's vehicle garage, active vehicle, odometer updates,
/// and the Free-tier 1-vehicle freemium gate.
class GarageBloc extends Bloc<GarageEvent, GarageState> {
  GarageBloc(this._repository) : super(const GarageState()) {
    on<GarageStarted>(_onStarted);
    on<GarageVehiclesUpdated>(_onVehiclesUpdated);
    on<GarageVehicleAdded>(_onVehicleAdded);
    on<GarageVehicleUpdated>(_onVehicleUpdated);
    on<GarageVehicleDeleted>(_onVehicleDeleted);
    on<GarageActiveVehicleSelected>(_onActiveVehicleSelected);
    on<GarageOdometerUpdated>(_onOdometerUpdated);
    on<GaragePaywallAcknowledged>(_onPaywallAcknowledged);
  }

  static const int freeVehicleLimit = 1;

  final GarageRepository _repository;
  StreamSubscription<List<Vehicle>>? _vehiclesSubscription;

  Future<void> _onStarted(
    GarageStarted event,
    Emitter<GarageState> emit,
  ) async {
    emit(state.copyWith(status: GarageStatus.loading, clearError: true));
    await _vehiclesSubscription?.cancel();
    _vehiclesSubscription = _repository.watchVehicles().listen(
      (vehicles) => add(GarageVehiclesUpdated(vehicles)),
      onError: (Object err) {
        emit(
          state.copyWith(
            status: GarageStatus.failure,
            error: err.toString(),
          ),
        );
      },
    );
  }

  void _onVehiclesUpdated(
    GarageVehiclesUpdated event,
    Emitter<GarageState> emit,
  ) {
    Vehicle? active;
    for (final v in event.vehicles) {
      if (v.isActive) {
        active = v;
        break;
      }
    }
    active ??= event.vehicles.isNotEmpty ? event.vehicles.first : null;

    emit(
      state.copyWith(
        status: GarageStatus.loaded,
        vehicles: event.vehicles,
        activeVehicle: active,
        clearActiveVehicle: active == null,
        clearError: true,
      ),
    );
  }

  Future<void> _onVehicleAdded(
    GarageVehicleAdded event,
    Emitter<GarageState> emit,
  ) async {
    if (!event.isPro && state.vehicles.length >= freeVehicleLimit) {
      emit(state.copyWith(paywallRequired: true));
      return;
    }

    try {
      await _repository.addVehicle(event.vehicle);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onVehicleUpdated(
    GarageVehicleUpdated event,
    Emitter<GarageState> emit,
  ) async {
    try {
      await _repository.updateVehicle(event.vehicle);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onVehicleDeleted(
    GarageVehicleDeleted event,
    Emitter<GarageState> emit,
  ) async {
    try {
      await _repository.deleteVehicle(event.vehicleId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onActiveVehicleSelected(
    GarageActiveVehicleSelected event,
    Emitter<GarageState> emit,
  ) async {
    try {
      await _repository.setActiveVehicle(event.vehicleId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onOdometerUpdated(
    GarageOdometerUpdated event,
    Emitter<GarageState> emit,
  ) async {
    try {
      await _repository.updateOdometerIfHigher(
        event.vehicleId,
        event.newOdometer,
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onPaywallAcknowledged(
    GaragePaywallAcknowledged event,
    Emitter<GarageState> emit,
  ) {
    emit(state.copyWith(paywallRequired: false));
  }

  @override
  Future<void> close() async {
    await _vehiclesSubscription?.cancel();
    return super.close();
  }
}
