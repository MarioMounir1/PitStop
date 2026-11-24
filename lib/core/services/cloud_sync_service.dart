import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:torq/core/services/backup_service.dart';

/// Result returned after pushing local Drift data to the Torq Node.js + Firebase backend.
class CloudSyncResult {
  const CloudSyncResult({
    required this.syncedAt,
    required this.vehiclesCount,
    required this.maintenanceCount,
    required this.fuelLogsCount,
    required this.expensesCount,
  });

  final DateTime syncedAt;
  final int vehiclesCount;
  final int maintenanceCount;
  final int fuelLogsCount;
  final int expensesCount;
}

/// Connects Torq's offline-first Drift database to the Node.js + Firebase backend
/// (`POST /api/sync/push` and `GET /api/sync/pull`).
class CloudSyncService {
  CloudSyncService({
    required this.backupService,
    this.baseUrl = defaultBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Android emulator localhost alias (`10.0.2.2` maps to host `localhost:8080`).
  static const String defaultBaseUrl = String.fromEnvironment(
    'TORQ_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  final BackupService backupService;
  final String baseUrl;
  final http.Client _client;

  /// Verifies that the Node.js + Firebase backend is reachable.
  Future<bool> checkHealth() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/api/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Pushes all local Drift tables to Firestore via `POST /api/sync/push`.
  Future<CloudSyncResult> pushToCloud({
    required String firebaseIdToken,
  }) async {
    final jsonPayload = await backupService.exportToJsonString();
    final response = await _client.post(
      Uri.parse('$baseUrl/api/sync/push'),
      headers: {
        'Authorization': 'Bearer $firebaseIdToken',
        'Content-Type': 'application/json',
      },
      body: jsonPayload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Cloud sync push failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final summary = decoded['summary'] as Map<String, dynamic>? ?? const {};

    return CloudSyncResult(
      syncedAt: DateTime.tryParse(decoded['syncedAt'] as String? ?? '') ??
          DateTime.now(),
      vehiclesCount: (summary['vehiclesCount'] as num?)?.toInt() ?? 0,
      maintenanceCount: (summary['maintenanceCount'] as num?)?.toInt() ?? 0,
      fuelLogsCount: (summary['fuelLogsCount'] as num?)?.toInt() ?? 0,
      expensesCount: (summary['expensesCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Pulls the user's cloud snapshot from Firestore via `GET /api/sync/pull`
  /// and restores it atomically into local Drift storage.
  Future<BackupRestoreSummary> pullFromCloud({
    required String firebaseIdToken,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/sync/pull'),
      headers: {
        'Authorization': 'Bearer $firebaseIdToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Cloud sync pull failed (${response.statusCode}): ${response.body}',
      );
    }

    return backupService.restoreFromJsonString(response.body);
  }
}
