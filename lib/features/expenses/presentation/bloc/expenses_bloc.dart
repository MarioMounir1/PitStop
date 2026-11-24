import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/features/expenses/domain/repositories/expenses_repository.dart';
import 'package:pitstop/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:pitstop/features/expenses/presentation/bloc/expenses_state.dart';

/// BLoC managing general vehicle expenses and monthly totals.
class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  ExpensesBloc(this._repository) : super(const ExpensesState()) {
    on<ExpensesVehicleSubscribed>(_onVehicleSubscribed);
    on<ExpensesListUpdated>(_onListUpdated);
    on<ExpensesMonthlyTotalUpdated>(_onMonthlyTotalUpdated);
    on<ExpenseAdded>(_onAdded);
    on<ExpenseUpdated>(_onUpdated);
    on<ExpenseDeleted>(_onDeleted);
  }

  final ExpensesRepository _repository;
  StreamSubscription<List<Expense>>? _expensesSub;
  StreamSubscription<double>? _monthlyTotalSub;

  Future<void> _onVehicleSubscribed(
    ExpensesVehicleSubscribed event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ExpensesLoadStatus.loading,
        vehicleId: event.vehicleId,
        clearError: true,
      ),
    );

    await _expensesSub?.cancel();
    await _monthlyTotalSub?.cancel();

    _expensesSub = _repository.watchExpenses(event.vehicleId).listen(
      (items) => add(ExpensesListUpdated(items)),
      onError: (Object err) {
        emit(
          state.copyWith(
            status: ExpensesLoadStatus.failure,
            error: err.toString(),
          ),
        );
      },
    );

    _monthlyTotalSub = _repository
        .watchMonthlyTotal(event.vehicleId, DateTime.now())
        .listen((total) => add(ExpensesMonthlyTotalUpdated(total)));
  }

  void _onListUpdated(
    ExpensesListUpdated event,
    Emitter<ExpensesState> emit,
  ) {
    final allTime =
        event.expenses.fold<double>(0, (sum, e) => sum + e.amount);
    emit(
      state.copyWith(
        status: ExpensesLoadStatus.loaded,
        expenses: event.expenses,
        allTimeTotal: allTime,
        clearError: true,
      ),
    );
  }

  void _onMonthlyTotalUpdated(
    ExpensesMonthlyTotalUpdated event,
    Emitter<ExpensesState> emit,
  ) {
    emit(state.copyWith(monthlyTotal: event.monthlyTotal));
  }

  Future<void> _onAdded(
    ExpenseAdded event,
    Emitter<ExpensesState> emit,
  ) async {
    try {
      await _repository.addExpense(event.expense);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdated(
    ExpenseUpdated event,
    Emitter<ExpensesState> emit,
  ) async {
    try {
      await _repository.updateExpense(event.expense);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleted(
    ExpenseDeleted event,
    Emitter<ExpensesState> emit,
  ) async {
    try {
      await _repository.deleteExpense(event.expenseId);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _expensesSub?.cancel();
    await _monthlyTotalSub?.cancel();
    return super.close();
  }
}
