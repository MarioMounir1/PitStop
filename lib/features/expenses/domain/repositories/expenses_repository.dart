import 'package:torq/core/database/app_database.dart';

/// Domain contract for general vehicle expenses.
abstract class ExpensesRepository {
  Stream<List<Expense>> watchExpenses(String vehicleId);
  Stream<double> watchMonthlyTotal(String vehicleId, DateTime month);
  Future<void> addExpense(ExpensesCompanion expense);
  Future<void> updateExpense(ExpensesCompanion expense);
  Future<void> deleteExpense(String id);
}
