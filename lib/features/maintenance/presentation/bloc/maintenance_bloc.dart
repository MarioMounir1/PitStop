import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/utils/reminder_calculator.dart';
import 'package:pitstop/features/maintenance/domain/repositories/maintenance_repository.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_event.dart';
import 'package:pitstop/features/maintenance/presentation/bloc/maintenance_state.dart';

/// BLoC managing maintenance history, per-category reminder statuses,
/// and overdue / due-soon counts for the active vehicle.
class MaintenanceBloc extends Bloc<MaintenanceEvent, MaintenanceState> {
  MaintenanceBloc(this._repository) : super(const MaintenanceState()) {
    on<MaintenanceVehicleSubscribed>(_onVehicleSubscribed);
    on<MaintenanceRecordsUpdated>(_onRecordsUpdated);
    on<MaintenanceFilterChanged>(_onFilterChanged);
    on<MaintenanceRecordAdded>(_onRecordAdded);
    on<MaintenanceRecordUpdated>(_onRecordUpdated);
    on<MaintenanceRecordDeleted>(_onRecordDeleted);
  }

  final MaintenanceRepository _repository;
  StreamSubscription<List<MaintenanceRecord>>? _recordsSubscription;

  Future<void> _onVehicleSubscribed(
    MaintenanceVehicleSubscribed event,
    Emitter<MaintenanceState> emit,
  ) async {
    final vehicleChanged = state.vehicleId != event.vehicleId;
    emit(
      state.copyWith(
        status: vehicleChanged ? MaintenanceLoadStatus.loading : state.status,
        vehicleId: event.vehicleId,
        currentOdometer: event.currentOdometer,
        clearError: true,
      ),
    );

    if (!vehicleChanged && state.records.isNotEmpty) {
      // Recompute statuses immediately when odometer changes.
      _emitComputedRecords(state.records, event.currentOdometer, emit);
      return;
    }

    await _recordsSubscription?.cancel();
    _recordsSubscription = _repository.watchRecords(event.vehicleId).listen(
      (records) => add(MaintenanceRecordsUpdated(records)),
      onError: (Object err) {
        emit(
          state.copyWith(
            status: MaintenanceLoadStatus.failure,
            error: err.toString(),
          ),
        );
      },
    );
  }

  void _onRecordsUpdated(
    MaintenanceRecordsUpdated event,
    Emitter<MaintenanceState> emit,
  ) {
    _emitComputedRecords(event.records, state.currentOdometer, emit);
  }

  void _emitComputedRecords(
    List<MaintenanceRecord> records,
    int currentOdometer,
    Emitter<MaintenanceState> emit,
  ) {
    final now = DateTime.now();
    final statusByRecordId = <String, MaintenanceStatus>{};
    final statusByCategory = <String, MaintenanceStatus>{};

    // Records are ordered newest-first from the repository, so the first
    // occurrence of each category is the latest service for that category.
    for (final record in records) {
      final status = ReminderCalculator.calculateStatus(
        currentOdometer: currentOdometer,
        nextDueOdometer: record.nextDueOdometer,
        nextDueDate: record.nextDueDate,
        now: now,
      );
      statusByRecordId[record.id] = status;
      statusByCategory.putIfAbsent(record.category, () => status);
    }

    int overdueCount = 0;
    int dueSoonCount = 0;
    for (final st in statusByCategory.values) {
      if (st == MaintenanceStatus.overdue) overdueCount++;
      if (st == MaintenanceStatus.dueSoon) dueSoonCount++;
    }

    emit(
      state.copyWith(
        status: MaintenanceLoadStatus.loaded,
        records: records,
        statusByRecordId: statusByRecordId,
        statusByCategory: statusByCategory,
        overdueCount: overdueCount,
        dueSoonCount: dueSoonCount,
        clearError: true,
      ),
    );
  }

  void _onFilterChanged(
    MaintenanceFilterChanged event,
    Emitter<MaintenanceState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  Future<void> _onRecordAdded(
    MaintenanceRecordAdded event,
    Emitter<MaintenanceState> emit,
  ) async {
    try {
      await _repository.addRecord(event.record);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRecordUpdated(
    MaintenanceRecordUpdated event,
    Emitter<MaintenanceState> emit,
  ) async {
    try {
      await _repository.updateRecord(event.record);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRecordDeleted(
    MaintenanceRecordDeleted event,
    Emitter<MaintenanceState> emit,
  ) async {
    try {
      await _repository.deleteRecord(event.recordId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _recordsSubscription?.cancel();
    return super.close();
  }
}
