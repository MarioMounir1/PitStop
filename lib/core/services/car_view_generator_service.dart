import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pitstop/core/services/auth_service.dart';
import 'package:pitstop/core/services/cloud_sync_service.dart';
import 'package:pitstop/features/settings/cubit/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical 8 angles around the vehicle in 360° clockwise turntable order.
enum CarViewAngle {
  front('front', 'Front', 'الأمام', 0),
  front34('front_3_4', 'Front 3/4', 'أمامي 3/4', 45),
  side('side', 'Side', 'الجانب', 90),
  rear34('rear_3_4', 'Rear 3/4', 'خلفي 3/4', 135),
  rear('rear', 'Rear', 'الخلف', 180),
  rear34Left('rear_3_4_l', 'Rear 3/4 L', 'خلفي 3/4 أيسر', 225),
  sideLeft('side_l', 'Side L', 'الجانب الأيسر', 270),
  front34Left('front_3_4_l', 'Front 3/4 L', 'أمامي 3/4 أيسر', 315);

  const CarViewAngle(this.key, this.labelEn, this.labelAr, this.yawDegrees);

  final String key;
  final String labelEn;
  final String labelAr;
  final double yawDegrees;

  String label({required bool isArabic}) => isArabic ? labelAr : labelEn;
}

/// Build state of a single angle during the "Creating your car" flow.
enum CarAngleBuildStatus {
  waiting,
  building,
  ready,
}

/// Brand-accurate 3D studio vehicle specification synthesized by Gemini AI
/// (`gemini-3.5-flash-lite`) or inferred from Make/Model/Year/Color.
class Car3dBlueprint {
  const Car3dBlueprint({
    this.bodyStyle = 'sport_sedan',
    this.grilleStyle = 'sport_mesh',
    this.headlightStyle = 'led_blade',
    this.rimStyle = 'multi_spoke',
    this.paintHex = '#F1F5F9',
    this.accentHex = '#FFAE19',
    this.caliperHex = '#E53935',
    this.lengthScale = 1.0,
    this.heightScale = 1.0,
    this.widthScale = 1.0,
    this.groundClearance = 0.14,
    this.hoodRatio = 0.30,
    this.trunkRatio = 0.17,
    this.roofSlopeRear = 0.18,
    this.wheelRadiusScale = 1.0,
    this.hasRearSpoiler = false,
    this.hasRoofRails = false,
  });

  factory Car3dBlueprint.fromJson(Map<String, dynamic> json) {
    double numVal(String k, double fallback, double min, double max) {
      final v = json[k];
      if (v is num) return v.toDouble().clamp(min, max);
      return fallback;
    }

    return Car3dBlueprint(
      bodyStyle: (json['bodyStyle'] as String?) ?? 'sport_sedan',
      grilleStyle: (json['grilleStyle'] as String?) ?? 'sport_mesh',
      headlightStyle: (json['headlightStyle'] as String?) ?? 'led_blade',
      rimStyle: (json['rimStyle'] as String?) ?? 'multi_spoke',
      paintHex: (json['paintHex'] as String?) ?? '#F1F5F9',
      accentHex: (json['accentHex'] as String?) ?? '#FFAE19',
      caliperHex: (json['caliperHex'] as String?) ?? '#E53935',
      lengthScale: numVal('lengthScale', 1.0, 0.85, 1.15),
      heightScale: numVal('heightScale', 1.0, 0.82, 1.28),
      widthScale: numVal('widthScale', 1.0, 0.88, 1.15),
      groundClearance: numVal('groundClearance', 0.14, 0.09, 0.25),
      hoodRatio: numVal('hoodRatio', 0.30, 0.20, 0.38),
      trunkRatio: numVal('trunkRatio', 0.17, 0.05, 0.26),
      roofSlopeRear: numVal('roofSlopeRear', 0.18, 0.06, 0.32),
      wheelRadiusScale: numVal('wheelRadiusScale', 1.0, 0.88, 1.18),
      hasRearSpoiler: (json['hasRearSpoiler'] as bool?) ?? false,
      hasRoofRails: (json['hasRoofRails'] as bool?) ?? false,
    );
  }

  /// Smart deterministic heuristic when offline without any API key.
  factory Car3dBlueprint.heuristic({
    required String make,
    required String model,
    required String color,
  }) {
    final mk = make.trim().toLowerCase();
    final md = model.trim().toLowerCase();
    final paintHex = _colorNameToHex(color);

    String grille = 'sport_mesh';
    String lights = 'led_blade';
    if (mk.contains('bmw')) {
      grille = 'bmw_kidney';
      lights = 'angel_eyes';
    } else if (mk.contains('mercedes') || mk.contains('benz')) {
      grille = 'mercedes_star';
    } else if (mk.contains('audi') || mk.contains('hyundai')) {
      grille = 'wide_hex';
    } else if (mk.contains('tesla') || mk.contains('byd')) {
      grille = 'ev_closed';
    } else if (mk.contains('jeep')) {
      grille = 'seven_slot';
      lights = 'round';
    }

    final isSuv = md.contains('x3') ||
        md.contains('x5') ||
        md.contains('rav4') ||
        md.contains('cr-v') ||
        md.contains('sportage') ||
        md.contains('tucson') ||
        md.contains('cayenne') ||
        md.contains('tahoe') ||
        md.contains('wrangler') ||
        md.contains('suv') ||
        md.contains('g63');

    final isCoupe = md.contains('911') ||
        md.contains('m4') ||
        md.contains('420') ||
        md.contains('mustang') ||
        md.contains('coupe') ||
        md.contains('supra');

    final isHatch = md.contains('golf') ||
        md.contains('yaris') ||
        md.contains('polo') ||
        md.contains('ibiza') ||
        md.contains('mini');

    if (isSuv) {
      return Car3dBlueprint(
        bodyStyle: 'suv',
        grilleStyle: grille,
        headlightStyle: lights,
        rimStyle: 'five_twin_spoke',
        paintHex: paintHex,
        heightScale: 1.20,
        groundClearance: 0.20,
        hoodRatio: 0.27,
        trunkRatio: 0.07,
        roofSlopeRear: 0.10,
        wheelRadiusScale: 1.10,
        hasRoofRails: true,
      );
    }
    if (isCoupe) {
      return Car3dBlueprint(
        bodyStyle: 'coupe',
        grilleStyle: grille,
        headlightStyle: lights,
        rimStyle: 'multi_spoke',
        paintHex: paintHex,
        heightScale: 0.88,
        widthScale: 1.06,
        groundClearance: 0.11,
        hoodRatio: 0.34,
        trunkRatio: 0.15,
        roofSlopeRear: 0.26,
        hasRearSpoiler: true,
      );
    }
    if (isHatch) {
      return Car3dBlueprint(
        bodyStyle: 'hatchback',
        grilleStyle: grille,
        headlightStyle: lights,
        paintHex: paintHex,
        lengthScale: 0.92,
        heightScale: 1.02,
        hoodRatio: 0.26,
        trunkRatio: 0.06,
        roofSlopeRear: 0.12,
      );
    }

    return Car3dBlueprint(
      bodyStyle: 'sport_sedan',
      grilleStyle: grille,
      headlightStyle: lights,
      rimStyle: mk.contains('bmw') ? 'multi_spoke' : 'five_twin_spoke',
      paintHex: paintHex,
      hasRearSpoiler: mk.contains('bmw') || md.contains('sport'),
    );
  }

  final String bodyStyle;
  final String grilleStyle;
  final String headlightStyle;
  final String rimStyle;
  final String paintHex;
  final String accentHex;
  final String caliperHex;
  final double lengthScale;
  final double heightScale;
  final double widthScale;
  final double groundClearance;
  final double hoodRatio;
  final double trunkRatio;
  final double roofSlopeRear;
  final double wheelRadiusScale;
  final bool hasRearSpoiler;
  final bool hasRoofRails;

  Map<String, dynamic> toJson() => {
        'bodyStyle': bodyStyle,
        'grilleStyle': grilleStyle,
        'headlightStyle': headlightStyle,
        'rimStyle': rimStyle,
        'paintHex': paintHex,
        'accentHex': accentHex,
        'caliperHex': caliperHex,
        'lengthScale': lengthScale,
        'heightScale': heightScale,
        'widthScale': widthScale,
        'groundClearance': groundClearance,
        'hoodRatio': hoodRatio,
        'trunkRatio': trunkRatio,
        'roofSlopeRear': roofSlopeRear,
        'wheelRadiusScale': wheelRadiusScale,
        'hasRearSpoiler': hasRearSpoiler,
        'hasRoofRails': hasRoofRails,
      };

  static String _colorNameToHex(String raw) {
    final c = raw.trim().toLowerCase();
    if (c.contains('black') || c.contains('أسود')) return '#1E232D';
    if (c.contains('silver') || c.contains('فضي')) return '#CBD5E1';
    if (c.contains('gray') || c.contains('grey') || c.contains('رمادي')) {
      return '#64748B';
    }
    if (c.contains('red') || c.contains('أحمر')) return '#DC2626';
    if (c.contains('blue') || c.contains('أزرق')) return '#2563EB';
    if (c.contains('green') || c.contains('أخضر')) return '#15803D';
    if (c.contains('gold') || c.contains('champagne') || c.contains('ذهبي')) {
      return '#D4AF37';
    }
    if (c.contains('yellow') || c.contains('أصفر')) return '#EAB308';
    return '#F1F5F9'; // Pearl White default
  }
}

/// Progress snapshot emitted as each of the 8 car views completes.
class CarViewsProgress {
  const CarViewsProgress({
    required this.statusByAngle,
    required this.localPathsByAngle,
    required this.usedAiImages,
    required this.blueprint,
    this.aiGeneratedBlueprint = false,
    this.statusNote,
  });

  final Map<CarViewAngle, CarAngleBuildStatus> statusByAngle;
  final Map<String, String> localPathsByAngle;
  final bool usedAiImages;
  final Car3dBlueprint blueprint;
  final bool aiGeneratedBlueprint;
  final String? statusNote;

  int get readyCount => statusByAngle.values
      .where((s) => s == CarAngleBuildStatus.ready)
      .length;

  bool get isComplete => readyCount == CarViewAngle.values.length;

  String toCarViewsJson() => jsonEncode({
        'mode': usedAiImages
            ? 'ai'
            : (aiGeneratedBlueprint ? 'gemini_3d' : 'studio_3d'),
        'views': localPathsByAngle,
        'blueprint': blueprint.toJson(),
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
  } catch (_) {}
  return const {};
}

/// Parses the saved `Car3dBlueprint` from `Vehicle.carViewsJson`, or computes
/// a brand-accurate fallback from Make/Model/Color.
Car3dBlueprint parseCar3dBlueprint(
  String? carViewsJson, {
  String make = '',
  String model = '',
  String color = 'White',
}) {
  if (carViewsJson != null && carViewsJson.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(carViewsJson);
      if (decoded is Map<String, dynamic>) {
        final bp = decoded['blueprint'];
        if (bp is Map<String, dynamic>) {
          return Car3dBlueprint.fromJson(bp);
        }
      }
    } catch (_) {}
  }
  return Car3dBlueprint.heuristic(make: make, model: model, color: color);
}

/// Generates 8-angle 360° vehicle views:
/// 1) Attempts `gemini-nano-banana-2.1` photorealistic studio PNG renders
///    (first angle guides the remaining 7).
/// 2) If on Gemini Free Tier (where image models have 0 daily quota) or if image
///    generation is unavailable, calls `gemini-3.5-flash-lite` to synthesize a
///    brand-accurate `Car3dBlueprint` (e.g. BMW twin-kidney grille, angel-eye
///    headlights, sport-sedan stance, exact metallic paint hex) for the real-time
///    3D perspective-projected studio renderer!
class CarViewGeneratorService {
  CarViewGeneratorService({
    required this.authService,
    required this.prefs,
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? CloudSyncService.resolveDefaultBaseUrl(),
        _client = client ?? http.Client();

  static const String geminiImageModel = 'gemini-nano-banana-2.1';
  static const String geminiBlueprintModel = 'gemini-3.5-flash-lite';

  final AuthService authService;
  final SharedPreferences prefs;
  final String baseUrl;
  final http.Client _client;

  String get _activeGeminiKey => SettingsCubit.resolveStoredOrEnvGeminiKey(prefs);

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
    Car3dBlueprint blueprint = Car3dBlueprint.heuristic(
      make: make,
      model: model,
      color: color,
    );
    bool aiBlueprintSynthesized = false;
    String? statusNote;

    String? anchorBase64;
    String anchorMimeType = 'image/png';
    bool tryImageApi = true;
    bool anyAiSaved = false;

    for (final angle in CarViewAngle.values) {
      statuses[angle] = CarAngleBuildStatus.building;
      yield CarViewsProgress(
        statusByAngle: Map.unmodifiable(statuses),
        localPathsByAngle: Map.unmodifiable(savedPaths),
        usedAiImages: anyAiSaved,
        blueprint: blueprint,
        aiGeneratedBlueprint: aiBlueprintSynthesized,
        statusNote: statusNote,
      );

      _RenderedAngleImage? rendered;
      if (tryImageApi) {
        final attempt = await _tryGenerateSingleAngle(
          make: make,
          model: model,
          year: year,
          color: color,
          angle: angle,
          referenceBase64: anchorBase64,
          referenceMimeType: anchorMimeType,
        );
        rendered = attempt.image;

        if (rendered == null) {
          tryImageApi = false;
          if (attempt.hitFreeTierQuota) {
            statusNote =
                'Gemini Free Tier active — synthesizing tailored 3D Studio Model via Gemini 3.5';
          }
          // Synthesize exact 3D car blueprint using Gemini 3.5 Flash-Lite!
          final aiBp = await _synthesizeGemini3dBlueprint(
            make: make,
            model: model,
            year: year,
            color: color,
          );
          if (aiBp != null) {
            blueprint = aiBp;
            aiBlueprintSynthesized = true;
          }
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
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }

      statuses[angle] = CarAngleBuildStatus.ready;
      yield CarViewsProgress(
        statusByAngle: Map.unmodifiable(statuses),
        localPathsByAngle: Map.unmodifiable(savedPaths),
        usedAiImages: anyAiSaved,
        blueprint: blueprint,
        aiGeneratedBlueprint: aiBlueprintSynthesized,
        statusNote: statusNote,
      );
    }
  }

  Future<Car3dBlueprint?> _synthesizeGemini3dBlueprint({
    required String make,
    required String model,
    required int year,
    required String color,
  }) async {
    final key = _activeGeminiKey;
    if (key.isEmpty) return null;

    try {
      final prompt = '''
Return ONLY a raw JSON object (no markdown fences) describing the 3D exterior studio proportions and styling cues of a $year $make $model in "$color" paint, with these exact fields:
{
  "bodyStyle": "sport_sedan" | "sedan" | "suv" | "coupe" | "hatchback" | "pickup",
  "grilleStyle": "bmw_kidney" | "mercedes_star" | "wide_hex" | "seven_slot" | "ev_closed" | "sport_mesh",
  "headlightStyle": "angel_eyes" | "led_blade" | "round",
  "rimStyle": "multi_spoke" | "five_twin_spoke" | "aero_ev",
  "paintHex": "#RRGGBB realistic automotive paint hex matching $color",
  "caliperHex": "#RRGGBB brake caliper accent hex",
  "lengthScale": 0.90 to 1.12,
  "heightScale": 0.85 to 1.25,
  "widthScale": 0.92 to 1.10,
  "groundClearance": 0.10 to 0.23,
  "hoodRatio": 0.22 to 0.36,
  "trunkRatio": 0.05 to 0.24,
  "roofSlopeRear": 0.08 to 0.28,
  "wheelRadiusScale": 0.92 to 1.15,
  "hasRearSpoiler": boolean,
  "hasRoofRails": boolean
}''';

      final response = await _client
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1/interactions',
            ),
            headers: {
              'x-goog-api-key': key,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': geminiBlueprintModel,
              'input': prompt,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      String? rawText;
      final steps = decoded['steps'];
      if (steps is List) {
        for (final step in steps) {
          if (step is Map && step['type'] == 'model_output') {
            final content = step['content'];
            if (content is List) {
              for (final item in content) {
                if (item is Map && item['type'] == 'text' && item['text'] is String) {
                  rawText = item['text'] as String;
                }
              }
            }
          }
        }
      }
      if (rawText == null || rawText.trim().isEmpty) return null;

      final start = rawText.indexOf('{');
      final end = rawText.lastIndexOf('}');
      if (start < 0 || end <= start) return null;

      final jsonMap =
          jsonDecode(rawText.substring(start, end + 1)) as Map<String, dynamic>;
      return Car3dBlueprint.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }

  Future<_AngleAttemptResult> _tryGenerateSingleAngle({
    required String make,
    required String model,
    required int year,
    required String color,
    required CarViewAngle angle,
    String? referenceBase64,
    String referenceMimeType = 'image/png',
  }) async {
    final key = _activeGeminiKey;
    if (key.isNotEmpty) {
      final direct = await _callGeminiInteractionsDirectly(
        apiKey: key,
        make: make,
        model: model,
        year: year,
        color: color,
        angle: angle,
        referenceBase64: referenceBase64,
        referenceMimeType: referenceMimeType,
      );
      if (direct.image != null || direct.hitFreeTierQuota) {
        return direct;
      }
    }

    final backendImg = await _callBackendRenderEndpoint(
      make: make,
      model: model,
      year: year,
      color: color,
      angle: angle,
      referenceBase64: referenceBase64,
      referenceMimeType: referenceMimeType,
    );
    return _AngleAttemptResult(image: backendImg);
  }

  Future<_AngleAttemptResult> _callGeminiInteractionsDirectly({
    required String apiKey,
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
              'https://generativelanguage.googleapis.com/v1/interactions',
            ),
            headers: {
              'x-goog-api-key': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': geminiImageModel,
              'input': inputPayload,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 429 &&
          response.body.toLowerCase().contains('free tier')) {
        return const _AngleAttemptResult(hitFreeTierQuota: true);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const _AngleAttemptResult();
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
                  return _AngleAttemptResult(
                    image: _RenderedAngleImage(
                      base64Data: item['data'] as String,
                      mimeType: (item['mime_type'] as String?) ?? 'image/png',
                    ),
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {
      return const _AngleAttemptResult();
    }
    return const _AngleAttemptResult();
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

class _AngleAttemptResult {
  const _AngleAttemptResult({
    this.image,
    this.hitFreeTierQuota = false,
  });

  final _RenderedAngleImage? image;
  final bool hitFreeTierQuota;
}

class _RenderedAngleImage {
  const _RenderedAngleImage({
    required this.base64Data,
    required this.mimeType,
  });

  final String base64Data;
  final String mimeType;
}
