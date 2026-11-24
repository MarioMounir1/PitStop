import 'package:drift/drift.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/features/expenses/domain/repositories/expenses_repository.dart';

/// Drift-backed implementation of [ExpensesRepository].
class ExpensesRepositoryImpl implements ExpensesRepository {
  ExpensesRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Expense>> watchExpenses(String vehicleId) {
    return (_db.select(_db.expenses)
          ..where((e) => e.vehicleId.equals(vehicleId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch();
  }

  @override
  Stream<double> watchMonthlyTotal(String vehicleId, DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);

    return (_db.select(_db.expenses)
          ..where(
            (e) =>
                e.vehicleId.equals(vehicleId) &
                e.date.isBiggerOrEqualValue(start) &
                e.date.isSmallerThanValue(end),
          ))
        .watch()
        .map(
          (rows) => rows.fold<double>(0, (sum, row) => sum + row.amount),
        );
  }

  @override
  Future<void> addExpense(ExpensesCompanion expense) async {
    await _db.into(_db.expenses).insert(expense);
  }

  @override
  Future<void> updateExpense(ExpensesCompanion expense) async {
    if (!expense.id.present) {
      throw ArgumentError('Expense id is required for update.');
    }
    await (_db.update(_db.expenses)
          ..where((e) => e.id.equals(expense.id.value)))
        .write(expense);
  }

  @override
  Future<void> deleteExpense(String id) async {
    await (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();
  }
}
