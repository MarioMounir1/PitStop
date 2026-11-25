import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pitstop/core/services/auth_service.dart';
import 'package:pitstop/core/services/cloud_sync_service.dart';

/// Canonical 8 angles around the vehicle in 360° clockwise turntable order.
enum CarViewAngle {
  front('front', 'Front', 'الأمام'),
  front34('front_3_4', 'Front 3/4', 'أمامي 3/4'),
  side('side', 'Side', 'الجانب'),
  rear34('rear_3_4', 'Rear 3/4', 'خلفي 3/4'),
  rear('rear', 'Rear', 'الخلف'),
  rear34Left('rear_3_4_l', 'Rear 3/4 L', 'خلفي 3/4 أيسر'),
  sideLeft('side_l', 'Side L', 'الجانب الأيسر'),
  front34Left('front_3_4_l', 'Front 3/4 L', 'أمامي 3/4 أيسر');

  const CarViewAngle(this.key, this.labelEn, this.labelAr);

  final String key;
  final String labelEn;
  final String labelAr;

  String label({required bool isArabic}) => isArabic ? labelAr : labelEn;
}

/// Build state of a single angle during the "Creating your car" flow.
enum CarAngleBuildStatus {
  waiting,
  building,
  ready,
}

/// Progress snapshot emitted as each of the 8 car views completes.
class CarViewsProgress {
  const CarViewsProgress({
    required this.statusByAngle,
    required this.localPathsByAngle,
    required this.usedAiImages,
  });

  final Map<CarViewAngle, CarAngleBuildStatus> statusByAngle;
  final Map<String, String> localPathsByAngle;
  final bool usedAiImages;

  int get readyCount => statusByAngle.values
      .where((s) => s == CarAngleBuildStatus.ready)
      .length;

  bool get isComplete => readyCount == CarViewAngle.values.length;

  String toCarViewsJson() => jsonEncode({
        'mode': usedAiImages ? 'ai' : 'vector3d',
        'views': localPathsByAngle,
      });
}

/// Parses `Vehicle.carViewsJson` into local image file paths keyed by angle.
Map<String, String> parseCarViewPaths(String? carViewsJson) {
  if (carViewsJson == null || carViewsJson.trim().isEmpty) {
    return const {};
  }
  try {
    final decoded = jsonDecode(carViewsJson);
    if (decoded is Map<String, dynamic>) {
      final rawViews = decoded['views'];
      if (rawViews is Map) {
        return rawViews.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        )..removeWhere((_, v) => v.isEmpty);
      }
    }
  } catch (_) {
    // Ignore malformed JSON and fall back to interactive 360 vector render.
  }
  return const {};
}

/// Generates the 8-angle 360° vehicle views using Gemini Nano Banana 2.1
/// (`gemini-nano-banana-2.1`), where the first (`front`) view guides the
/// remaining 7 angles for visual consistency, with automatic offline fallback.
class CarViewGeneratorService {
  CarViewGeneratorService({
    required this.authService,
    this.baseUrl = CloudSyncService.defaultBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String directGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );
  static const String geminiImageModel = 'gemini-nano-banana-2.1';

  final AuthService authService;
  final String baseUrl;
  final http.Client _client;

  static const Map<CarViewAngle, String> _anglePrompts = {
    CarViewAngle.front:
        'direct eye-level front view, centered symmetrical headlights and grille',
    CarViewAngle.front34:
        'front right 3/4 studio angle (45 degrees), showing front fascia and right profile',
    CarViewAngle.side:
        'pure right-side profile studio view (90 degrees), full wheelbase centered horizontally',
    CarViewAngle.rear34:
        'rear right 3/4 studio angle (135 degrees), showing taillights and right quarter panel',
    CarViewAngle.rear:
        'direct eye-level rear view (180 degrees), centered taillights and rear bumper',
    CarViewAngle.rear34Left:
        'rear left 3/4 studio angle (225 degrees), showing taillights and left quarter panel',
    CarViewAngle.sideLeft:
        'pure left-side profile studio view (270 degrees), full wheelbase facing left',
    CarViewAngle.front34Left:
        'front left 3/4 studio angle (315 degrees), showing front fascia and left profile',
  };

  /// Streams progressive status updates (`waiting` -> `building` -> `ready`)
  /// across all 8 angles.
  Stream<CarViewsProgress> generateAllViews({
    required String vehicleId,
    required String make,
    required String model,
    required int year,
    required String color,
  }) async* {
    final statuses = <CarViewAngle, CarAngleBuildStatus>{
      for (final angle in CarViewAngle.values)
        angle: CarAngleBuildStatus.waiting,
    };
    final savedPaths = <String, String>{};
    String? anchorBase64;
    String anchorMimeType = 'image/png';
    bool aiAvailable = true;
    bool anyAiSaved = false;

    for (final angle in CarViewAngle.values) {
      statuses[angle] = CarAngleBuildStatus.building;
      yield CarViewsProgress(
        statusByAngle: Map.unmodifiable(statuses),
        localPathsByAngle: Map.unmodifiable(savedPaths),
        usedAiImages: anyAiSaved,
      );

      _RenderedAngleImage? rendered;
      if (aiAvailable) {
        rendered = await _tryGenerateSingleAngle(
          make: make,
          model: model,
          year: year,
          color: color,
          angle: angle,
          referenceBase64: anchorBase64,
          referenceMimeType: anchorMimeType,
        );

        if (rendered == null) {
          // Avoid timing out 7 more times when offline or unconfigured.
          aiAvailable = false;
        }
      }

      if (rendered != null) {
        if (angle == CarViewAngle.front) {
          anchorBase64 = rendered.base64Data;
          anchorMimeType = rendered.mimeType;
        }
        final savedPath = await _persistAngleImage(
          vehicleId: vehicleId,
          angle: angle,
          base64Data: rendered.base64Data,
        );
        if (savedPath != null) {
          savedPaths[angle.key] = savedPath;
          anyAiSaved = true;
        }
      } else {
        // Smooth studio cadence for offline 360° vector synthesis.
        await Future<void>.delayed(const Duration(milliseconds: 280));
      }

      statuses[angle] = CarAngleBuildStatus.ready;
      yield CarViewsProgress(
        statusByAngle: Map.unmodifiable(statuses),
        localPathsByAngle: Map.unmodifiable(savedPaths),
        usedAiImages: anyAiSaved,
      );
    }
  }

  Future<_RenderedAngleImage?> _tryGenerateSingleAngle({
    required String make,
    required String model,
    required int year,
    required String color,
    required CarViewAngle angle,
    String? referenceBase64,
    String referenceMimeType = 'image/png',
  }) async {
    if (directGeminiApiKey.isNotEmpty) {
      final direct = await _callGeminiInteractionsDirectly(
        make: make,
        model: model,
        year: year,
        color: color,
        angle: angle,
        referenceBase64: referenceBase64,
        referenceMimeType: referenceMimeType,
      );
      if (direct != null) return direct;
    }

    return _callBackendRenderEndpoint(
      make: make,
      model: model,
      year: year,
      color: color,
      angle: angle,
      referenceBase64: referenceBase64,
      referenceMimeType: referenceMimeType,
    );
  }

  Future<_RenderedAngleImage?> _callGeminiInteractionsDirectly({
    required String make,
    required String model,
    required int year,
    required String color,
    required CarViewAngle angle,
    String? referenceBase64,
    required String referenceMimeType,
  }) async {
    try {
      final angleDesc = _anglePrompts[angle]!;
      const studioStyle =
          'Clean dark obsidian automotive studio background (#0E1117), subtle soft floor shadow, sleek studio rim lighting, photorealistic showroom turntable render, no text, no watermarks, entire car centered in frame.';
      final carDesc = '$year $make $model in $color paint';

      final Object inputPayload = referenceBase64 != null
          ? [
              {
                'type': 'text',
                'text':
                    'Using the attached reference car image so the exact body trim, wheels, paint finish, and proportions stay identical, render the $angleDesc of this $carDesc. $studioStyle',
              },
              {
                'type': 'image',
                'mime_type': referenceMimeType,
                'data': referenceBase64,
              },
            ]
          : 'Render the $angleDesc of a $carDesc. $studioStyle';

      final response = await _client
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/interactions',
            ),
            headers: {
              'x-goog-api-key': directGeminiApiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': geminiImageModel,
              'input': inputPayload,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final steps = decoded['steps'];
      if (steps is List) {
        for (final step in steps) {
          if (step is Map && step['type'] == 'model_output') {
            final content = step['content'];
            if (content is List) {
              for (final item in content) {
                if (item is Map &&
                    item['type'] == 'image' &&
                    item['data'] is String) {
                  return _RenderedAngleImage(
                    base64Data: item['data'] as String,
                    mimeType: (item['mime_type'] as String?) ?? 'image/png',
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<_RenderedAngleImage?> _callBackendRenderEndpoint({
    required String make,
    required String model,
    required int year,
    required String color,
    required CarViewAngle angle,
    String? referenceBase64,
    required String referenceMimeType,
  }) async {
    try {
      final token = await authService.getIdToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token'
        else
          'x-dev-uid': 'local-device',
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/car-views/generate'),
            headers: headers,
            body: jsonEncode({
              'make': make,
              'model': model,
              'year': year,
              'color': color,
              'angle': angle.key,
              if (referenceBase64 != null) ...{
                'referenceImageBase64': referenceBase64,
                'referenceMimeType': referenceMimeType,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final imageBase64 = decoded['imageBase64'] as String?;
      if (imageBase64 == null || imageBase64.isEmpty) return null;

      return _RenderedAngleImage(
        base64Data: imageBase64,
        mimeType: (decoded['mimeType'] as String?) ?? 'image/png',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _persistAngleImage({
    required String vehicleId,
    required CarViewAngle angle,
    required String base64Data,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory(
        '${docsDir.path}${Platform.pathSeparator}car_views${Platform.pathSeparator}$vehicleId',
      );
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}${Platform.pathSeparator}${angle.key}.png');
      await file.writeAsBytes(base64Decode(base64Data), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

class _RenderedAngleImage {
  const _RenderedAngleImage({
    required this.base64Data,
    required this.mimeType,
  });

  final String base64Data;
  final String mimeType;
}
