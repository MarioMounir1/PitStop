import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pitstop/core/database/app_database.dart';

/// Result summary returned after a successful JSON backup restore.
class BackupRestoreSummary {
  const BackupRestoreSummary({
    required this.vehiclesCount,
    required this.maintenanceCount,
    required this.fuelLogsCount,
    required this.expensesCount,
  });

  final int vehiclesCount;
  final int maintenanceCount;
  final int fuelLogsCount;
  final int expensesCount;
}

/// Exports and restores all PitStop Drift tables as a versioned JSON archive.
class BackupService {
  BackupService(this._db);

  static const int currentBackupFormatVersion = 1;

  final AppDatabase _db;

  /// Serializes all 4 Drift tables into a formatted JSON string.
  Future<String> exportToJsonString() async {
    final vehicles = await _db.select(_db.vehicles).get();
    final maintenance = await _db.select(_db.maintenanceRecords).get();
    final fuelLogs = await _db.select(_db.fuelLogs).get();
    final expenses = await _db.select(_db.expenses).get();

    final payload = <String, dynamic>{
      'app': 'pitstop',
      'formatVersion': currentBackupFormatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': <String, dynamic>{
        'vehicles': vehicles.map(_vehicleToMap).toList(),
        'maintenanceRecords': maintenance.map(_maintenanceToMap).toList(),
        'fuelLogs': fuelLogs.map(_fuelLogToMap).toList(),
        'expenses': expenses.map(_expenseToMap).toList(),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Writes all tables to a JSON file in temp storage and opens the share sheet.
  Future<File> exportAndShare() async {
    final jsonString = await exportToJsonString();
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}pitstop_backup_$timestamp.json',
    );
    await file.writeAsString(jsonString, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'PitStop Backup ($timestamp)',
      ),
    );

    return file;
  }

  /// Restores a backup from a JSON [File] inside a single Drift transaction.
  Future<BackupRestoreSummary> restoreFromFile(File file) async {
    final content = await file.readAsString();
    return restoreFromJsonString(content);
  }

  /// Parses [jsonContent] and replaces all table rows atomically inside a
  /// Drift transaction. Throws [FormatException] if the payload is invalid.
  Future<BackupRestoreSummary> restoreFromJsonString(String jsonContent) async {
    final dynamic decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid PitStop backup file format.');
    }

    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Backup file is missing "tables" section.');
    }

    final vehicleRows = _parseList(tables['vehicles'])
        .map(_vehicleFromMap)
        .toList();
    final maintenanceRows = _parseList(tables['maintenanceRecords'])
        .map(_maintenanceFromMap)
        .toList();
    final fuelLogRows = _parseList(tables['fuelLogs'])
        .map(_fuelLogFromMap)
        .toList();
    final expenseRows = _parseList(tables['expenses'])
        .map(_expenseFromMap)
        .toList();

    await _db.transaction(() async {
      // Clear child tables first to satisfy foreign key constraints.
      await _db.delete(_db.expenses).go();
      await _db.delete(_db.fuelLogs).go();
      await _db.delete(_db.maintenanceRecords).go();
      await _db.delete(_db.vehicles).go();

      await _db.batch((batch) {
        if (vehicleRows.isNotEmpty) {
          batch.insertAll(_db.vehicles, vehicleRows);
        }
        if (maintenanceRows.isNotEmpty) {
          batch.insertAll(_db.maintenanceRecords, maintenanceRows);
        }
        if (fuelLogRows.isNotEmpty) {
          batch.insertAll(_db.fuelLogs, fuelLogRows);
        }
        if (expenseRows.isNotEmpty) {
          batch.insertAll(_db.expenses, expenseRows);
        }
      });
    });

    return BackupRestoreSummary(
      vehiclesCount: vehicleRows.length,
      maintenanceCount: maintenanceRows.length,
      fuelLogsCount: fuelLogRows.length,
      expensesCount: expenseRows.length,
    );
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const FormatException('Expected a JSON array for table data.');
    }
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  DateTime _parseDate(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    throw FormatException('Invalid date value: $value');
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    return _parseDate(value);
  }

  Map<String, dynamic> _vehicleToMap(Vehicle v) => {
        'id': v.id,
        'make': v.make,
        'model': v.model,
        'year': v.year,
        'color': v.color,
        'plateNumber': v.plateNumber,
        'currentOdometer': v.currentOdometer,
        'distanceUnit': v.distanceUnit,
        'currencyCode': v.currencyCode,
        'fuelType': v.fuelType,
        'licenseExpiryDate': v.licenseExpiryDate?.toIso8601String(),
        'insuranceExpiryDate': v.insuranceExpiryDate?.toIso8601String(),
        'carViewsJson': v.carViewsJson,
        'isActive': v.isActive,
        'createdAt': v.createdAt.toIso8601String(),
      };

  VehiclesCompanion _vehicleFromMap(Map<String, dynamic> m) =>
      VehiclesCompanion.insert(
        id: m['id'] as String,
        make: m['make'] as String,
        model: m['model'] as String,
        year: (m['year'] as num).toInt(),
        color: Value((m['color'] as String?) ?? 'White'),
        plateNumber: Value(m['plateNumber'] as String?),
        currentOdometer: Value((m['currentOdometer'] as num?)?.toInt() ?? 0),
        distanceUnit: Value((m['distanceUnit'] as String?) ?? 'km'),
        currencyCode: Value((m['currencyCode'] as String?) ?? 'EGP'),
        fuelType: Value((m['fuelType'] as String?) ?? 'petrol_92'),
        licenseExpiryDate: Value(_parseNullableDate(m['licenseExpiryDate'])),
        insuranceExpiryDate: Value(
          _parseNullableDate(m['insuranceExpiryDate']),
        ),
        carViewsJson: Value(m['carViewsJson'] as String?),
        isActive: Value((m['isActive'] as bool?) ?? false),
        createdAt: Value(_parseNullableDate(m['createdAt']) ?? DateTime.now()),
      );

  Map<String, dynamic> _maintenanceToMap(MaintenanceRecord r) => {
        'id': r.id,
        'vehicleId': r.vehicleId,
        'category': r.category,
        'title': r.title,
        'serviceDate': r.serviceDate.toIso8601String(),
        'odometerAtService': r.odometerAtService,
        'cost': r.cost,
        'serviceCenter': r.serviceCenter,
        'notes': r.notes,
        'receiptImagePath': r.receiptImagePath,
        'nextDueOdometer': r.nextDueOdometer,
        'nextDueDate': r.nextDueDate?.toIso8601String(),
        'reminderEnabled': r.reminderEnabled,
        'isCompleted': r.isCompleted,
        'createdAt': r.createdAt.toIso8601String(),
      };

  MaintenanceRecordsCompanion _maintenanceFromMap(Map<String, dynamic> m) =>
      MaintenanceRecordsCompanion.insert(
        id: m['id'] as String,
        vehicleId: m['vehicleId'] as String,
        category: m['category'] as String,
        title: m['title'] as String,
        serviceDate: _parseDate(m['serviceDate']),
        odometerAtService: (m['odometerAtService'] as num).toInt(),
        cost: (m['cost'] as num).toDouble(),
        serviceCenter: Value(m['serviceCenter'] as String?),
        notes: Value(m['notes'] as String?),
        receiptImagePath: Value(m['receiptImagePath'] as String?),
        nextDueOdometer: Value((m['nextDueOdometer'] as num?)?.toInt()),
        nextDueDate: Value(_parseNullableDate(m['nextDueDate'])),
        reminderEnabled: Value((m['reminderEnabled'] as bool?) ?? true),
        isCompleted: Value((m['isCompleted'] as bool?) ?? true),
        createdAt: Value(_parseNullableDate(m['createdAt']) ?? DateTime.now()),
      );

  Map<String, dynamic> _fuelLogToMap(FuelLog f) => {
        'id': f.id,
        'vehicleId': f.vehicleId,
        'date': f.date.toIso8601String(),
        'odometer': f.odometer,
        'liters': f.liters,
        'pricePerLiter': f.pricePerLiter,
        'totalCost': f.totalCost,
        'isFullTank': f.isFullTank,
        'fuelGrade': f.fuelGrade,
        'stationName': f.stationName,
        'consumptionKmPerL': f.consumptionKmPerL,
        'createdAt': f.createdAt.toIso8601String(),
      };

  FuelLogsCompanion _fuelLogFromMap(Map<String, dynamic> m) =>
      FuelLogsCompanion.insert(
        id: m['id'] as String,
        vehicleId: m['vehicleId'] as String,
        date: _parseDate(m['date']),
        odometer: (m['odometer'] as num).toInt(),
        liters: (m['liters'] as num).toDouble(),
        pricePerLiter: (m['pricePerLiter'] as num).toDouble(),
        totalCost: (m['totalCost'] as num).toDouble(),
        isFullTank: Value((m['isFullTank'] as bool?) ?? true),
        fuelGrade: Value(m['fuelGrade'] as String?),
        stationName: Value(m['stationName'] as String?),
        consumptionKmPerL: Value((m['consumptionKmPerL'] as num?)?.toDouble()),
        createdAt: Value(_parseNullableDate(m['createdAt']) ?? DateTime.now()),
      );

  Map<String, dynamic> _expenseToMap(Expense e) => {
        'id': e.id,
        'vehicleId': e.vehicleId,
        'category': e.category,
        'title': e.title,
        'date': e.date.toIso8601String(),
        'amount': e.amount,
        'notes': e.notes,
        'receiptImagePath': e.receiptImagePath,
        'createdAt': e.createdAt.toIso8601String(),
      };

  ExpensesCompanion _expenseFromMap(Map<String, dynamic> m) =>
      ExpensesCompanion.insert(
        id: m['id'] as String,
        vehicleId: m['vehicleId'] as String,
        category: m['category'] as String,
        title: m['title'] as String,
        date: _parseDate(m['date']),
        amount: (m['amount'] as num).toDouble(),
        notes: Value(m['notes'] as String?),
        receiptImagePath: Value(m['receiptImagePath'] as String?),
        createdAt: Value(_parseNullableDate(m['createdAt']) ?? DateTime.now()),
      );
}
