import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/utils/fuel_calculator.dart';
import 'package:pitstop/features/fuel/domain/repositories/fuel_repository.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_event.dart';
import 'package:pitstop/features/fuel/presentation/bloc/fuel_state.dart';

/// BLoC managing fuel fill-up history, average `km/L`, monthly fuel spend,
/// and total liters for the active vehicle.
class FuelBloc extends Bloc<FuelEvent, FuelState> {
  FuelBloc(this._repository) : super(const FuelState()) {
    on<FuelVehicleSubscribed>(_onVehicleSubscribed);
    on<FuelLogsUpdated>(_onLogsUpdated);
    on<FuelLogAdded>(_onLogAdded);
    on<FuelLogUpdated>(_onLogUpdated);
    on<FuelLogDeleted>(_onLogDeleted);
  }

  final FuelRepository _repository;
  StreamSubscription<List<FuelLog>>? _logsSubscription;

  Future<void> _onVehicleSubscribed(
    FuelVehicleSubscribed event,
    Emitter<FuelState> emit,
  ) async {
    emit(
      state.copyWith(
        status: FuelLoadStatus.loading,
        vehicleId: event.vehicleId,
        clearError: true,
      ),
    );
    await _logsSubscription?.cancel();
    _logsSubscription = _repository.watchFuelLogs(event.vehicleId).listen(
      (logs) => add(FuelLogsUpdated(logs)),
      onError: (Object err) {
        emit(
          state.copyWith(
            status: FuelLoadStatus.failure,
            error: err.toString(),
          ),
        );
      },
    );
  }

  void _onLogsUpdated(
    FuelLogsUpdated event,
    Emitter<FuelState> emit,
  ) {
    final now = DateTime.now();
    final avg = FuelCalculator.averageKmPerL(event.logs);
    final monthlySpend = event.logs
        .where((l) => l.date.year == now.year && l.date.month == now.month)
        .fold<double>(0, (sum, l) => sum + l.totalCost);
    final totalLiters =
        event.logs.fold<double>(0, (sum, l) => sum + l.liters);

    emit(
      state.copyWith(
        status: FuelLoadStatus.loaded,
        logs: event.logs,
        averageKmPerL: avg,
        clearAverageKmPerL: avg == null,
        monthlyFuelSpend: monthlySpend,
        totalLiters: totalLiters,
        clearError: true,
      ),
    );
  }

  Future<void> _onLogAdded(
    FuelLogAdded event,
    Emitter<FuelState> emit,
  ) async {
    try {
      await _repository.addFuelLog(event.log);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLogUpdated(
    FuelLogUpdated event,
    Emitter<FuelState> emit,
  ) async {
    try {
      await _repository.updateFuelLog(event.log);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLogDeleted(
    FuelLogDeleted event,
    Emitter<FuelState> emit,
  ) async {
    try {
      await _repository.deleteFuelLog(event.logId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _logsSubscription?.cancel();
    return super.close();
  }
}
