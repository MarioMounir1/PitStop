import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/utils/fuel_calculator.dart';
import 'package:pitstop/features/analytics/domain/models/analytics_models.dart';
import 'package:pitstop/features/analytics/presentation/bloc/analytics_event.dart';
import 'package:pitstop/features/analytics/presentation/bloc/analytics_state.dart';

/// Aggregates Maintenance, Fuel, and General Expenses over time for charts & KPIs.
class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  AnalyticsBloc(this._db) : super(const AnalyticsState()) {
    on<AnalyticsVehicleSubscribed>(_onVehicleSubscribed);
    on<AnalyticsRecomputeRequested>(_onRecomputeRequested);
  }

  final AppDatabase _db;

  int _currentOdometer = 0;
  List<MaintenanceRecord> _maintenance = const [];
  List<FuelLog> _fuelLogs = const [];
  List<Expense> _expenses = const [];

  StreamSubscription<List<MaintenanceRecord>>? _maintenanceSub;
  StreamSubscription<List<FuelLog>>? _fuelSub;
  StreamSubscription<List<Expense>>? _expensesSub;

  Future<void> _onVehicleSubscribed(
    AnalyticsVehicleSubscribed event,
    Emitter<AnalyticsState> emit,
  ) async {
    _currentOdometer = event.currentOdometer;

    final vehicleChanged = state.vehicleId != event.vehicleId;
    if (!vehicleChanged) {
      add(const AnalyticsRecomputeRequested());
      return;
    }

    emit(
      state.copyWith(
        status: AnalyticsLoadStatus.loading,
        vehicleId: event.vehicleId,
        clearError: true,
      ),
    );

    await _maintenanceSub?.cancel();
    await _fuelSub?.cancel();
    await _expensesSub?.cancel();

    _maintenance = const [];
    _fuelLogs = const [];
    _expenses = const [];

    _maintenanceSub = (_db.select(_db.maintenanceRecords)
          ..where((r) => r.vehicleId.equals(event.vehicleId)))
        .watch()
        .listen((rows) {
      _maintenance = rows;
      add(const AnalyticsRecomputeRequested());
    });

    _fuelSub = (_db.select(_db.fuelLogs)
          ..where((f) => f.vehicleId.equals(event.vehicleId))
          ..orderBy([(f) => OrderingTerm.asc(f.date)]))
        .watch()
        .listen((rows) {
      _fuelLogs = rows;
      add(const AnalyticsRecomputeRequested());
    });

    _expensesSub = (_db.select(_db.expenses)
          ..where((e) => e.vehicleId.equals(event.vehicleId)))
        .watch()
        .listen((rows) {
      _expenses = rows;
      add(const AnalyticsRecomputeRequested());
    });
  }

  void _onRecomputeRequested(
    AnalyticsRecomputeRequested event,
    Emitter<AnalyticsState> emit,
  ) {
    final now = DateTime.now();

    final maintenanceTotal =
        _maintenance.fold<double>(0, (sum, r) => sum + r.cost);
    final fuelTotal = _fuelLogs.fold<double>(0, (sum, f) => sum + f.totalCost);
    final expensesTotal =
        _expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final allTimeSpend = maintenanceTotal + fuelTotal + expensesTotal;

    final thisMonthMaintenance = _maintenance
        .where(
          (r) =>
              r.serviceDate.year == now.year &&
              r.serviceDate.month == now.month,
        )
        .fold<double>(0, (sum, r) => sum + r.cost);
    final thisMonthFuel = _fuelLogs
        .where((f) => f.date.year == now.year && f.date.month == now.month)
        .fold<double>(0, (sum, f) => sum + f.totalCost);
    final thisMonthExpenses = _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final thisMonthSpend =
        thisMonthMaintenance + thisMonthFuel + thisMonthExpenses;

    // Last 6 months breakdown (oldest -> newest).
    final monthlyPoints = <MonthlySpendPoint>[];
    for (int offset = 5; offset >= 0; offset--) {
      final monthDate = DateTime(now.year, now.month - offset);
      final mCost = _maintenance
          .where(
            (r) =>
                r.serviceDate.year == monthDate.year &&
                r.serviceDate.month == monthDate.month,
          )
          .fold<double>(0, (sum, r) => sum + r.cost);
      final fCost = _fuelLogs
          .where(
            (f) =>
                f.date.year == monthDate.year &&
                f.date.month == monthDate.month,
          )
          .fold<double>(0, (sum, f) => sum + f.totalCost);
      final eCost = _expenses
          .where(
            (e) =>
                e.date.year == monthDate.year &&
                e.date.month == monthDate.month,
          )
          .fold<double>(0, (sum, e) => sum + e.amount);

      monthlyPoints.add(
        MonthlySpendPoint(
          month: monthDate,
          maintenance: mCost,
          fuel: fCost,
          expenses: eCost,
        ),
      );
    }

    // Fuel efficiency trend (ascending chronological order).
    final fuelTrend = _fuelLogs
        .where((f) => f.consumptionKmPerL != null && f.consumptionKmPerL! > 0)
        .map(
          (f) => FuelTrendPoint(
            date: f.date,
            kmPerL: f.consumptionKmPerL!,
          ),
        )
        .toList();

    final avgKmPerL = FuelCalculator.averageKmPerL(_fuelLogs);

    // Distance span for cost/km: prefer tracked odometer span; fall back to
    // currentOdometer if only one reading exists.
    final odometers = <int>[
      ..._maintenance.map((r) => r.odometerAtService),
      ..._fuelLogs.map((f) => f.odometer),
      if (_currentOdometer > 0) _currentOdometer,
    ];
    int distance = 0;
    if (odometers.length >= 2) {
      odometers.sort();
      distance = odometers.last - odometers.first;
    }
    if (distance <= 0 && _currentOdometer > 0) {
      distance = _currentOdometer;
    }
    final costPerKm = FuelCalculator.averageCostPerKm(allTimeSpend, distance);

    emit(
      state.copyWith(
        status: AnalyticsLoadStatus.loaded,
        thisMonthSpend: thisMonthSpend,
        allTimeSpend: allTimeSpend,
        avgKmPerL: avgKmPerL,
        clearAvgKmPerL: avgKmPerL == null,
        costPerKm: costPerKm,
        clearCostPerKm: costPerKm == null,
        monthlySpend: monthlyPoints,
        fuelTrend: fuelTrend,
        categoryBreakdown: {
          'maintenance': maintenanceTotal,
          'fuel': fuelTotal,
          'expenses': expensesTotal,
        },
        clearError: true,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _maintenanceSub?.cancel();
    await _fuelSub?.cancel();
    await _expensesSub?.cancel();
    return super.close();
  }
}
