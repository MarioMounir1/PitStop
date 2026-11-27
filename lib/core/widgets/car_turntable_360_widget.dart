import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:pitstop/core/services/car_view_generator_service.dart';
import 'package:pitstop/core/theme/app_colors.dart';

/// Converts a vehicle color name or hex string into linear PBR `[r, g, b, metallic, roughness]`
/// parameters for the Khronos `KHR_materials_clearcoat` car shader.
({double r, double g, double b, double metallic, double roughness})
    _resolveClearcoatPbr(String colorName, String? blueprintHex) {
  final c = colorName.trim().toLowerCase();
  if (c.contains('white') || c.contains('أبيض')) {
    return (r: 0.84, g: 0.86, b: 0.90, metallic: 0.32, roughness: 0.18);
  }
  if (c.contains('black') || c.contains('أسود')) {
    return (r: 0.020, g: 0.022, b: 0.028, metallic: 0.78, roughness: 0.17);
  }
  if (c.contains('silver') || c.contains('فضي')) {
    return (r: 0.50, g: 0.53, b: 0.58, metallic: 0.86, roughness: 0.19);
  }
  if (c.contains('gray') || c.contains('grey') || c.contains('رمادي')) {
    return (r: 0.13, g: 0.15, b: 0.18, metallic: 0.80, roughness: 0.21);
  }
  if (c.contains('red') || c.contains('أحمر')) {
    return (r: 0.58, g: 0.015, b: 0.020, metallic: 0.68, roughness: 0.19);
  }
  if (c.contains('blue') || c.contains('أزرق')) {
    return (r: 0.022, g: 0.12, b: 0.52, metallic: 0.74, roughness: 0.19);
  }
  if (c.contains('green') || c.contains('أخضر')) {
    return (r: 0.018, g: 0.24, b: 0.09, metallic: 0.74, roughness: 0.19);
  }
  if (c.contains('gold') || c.contains('champagne') || c.contains('ذهبي')) {
    return (r: 0.58, g: 0.40, b: 0.10, metallic: 0.82, roughness: 0.20);
  }

  final cleaned = (blueprintHex ?? '').trim().replaceAll('#', '');
  if (cleaned.length == 6) {
    final val = int.tryParse(cleaned, radix: 16);
    if (val != null) {
      final sr = ((val >> 16) & 0xFF) / 255.0;
      final sg = ((val >> 8) & 0xFF) / 255.0;
      final sb = (val & 0xFF) / 255.0;
      return (
        r: math.pow(sr, 2.2).toDouble(),
        g: math.pow(sg, 2.2).toDouble(),
        b: math.pow(sb, 2.2).toDouble(),
        metallic: 0.65,
        roughness: 0.20,
      );
    }
  }

  return (r: 0.84, g: 0.86, b: 0.90, metallic: 0.32, roughness: 0.18);
}

bool get _supportsNativeWebGlModelViewer {
  if (kIsWeb) return true;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

/// Renders a single car view tile inside the 8-view "Creating your car" grid:
/// - Displays the saved Gemini Nano Banana 2.1 studio PNG if present on disk
/// - Otherwise renders the clean amber showroom silhouette for that angle.
class CarAngleArtwork extends StatelessWidget {
  const CarAngleArtwork({
    required this.angle,
    this.imagePath,
    this.make = '',
    this.model = '',
    this.vehicleColor = 'White',
    this.blueprint,
    super.key,
  });

  final CarViewAngle angle;
  final String? imagePath;
  final String make;
  final String model;
  final String vehicleColor;
  final Car3dBlueprint? blueprint;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildTileGlyph(),
          ),
        );
      }
    }
    return _buildTileGlyph();
  }

  Widget _buildTileGlyph() {
    return CustomPaint(
      painter: _CarTileSilhouettePainter(angle: angle),
      child: const SizedBox.expand(),
    );
  }
}

/// Real WebGL PBR 360° interactive 3D Car Viewer (`assets/models/car_studio.glb`)
/// powered by Google `<model-viewer>` (`model_viewer_plus`), with dynamic
/// `KHR_materials_clearcoat` car paint matching the user's vehicle color,
/// or scrubbing across saved Gemini AI studio renders if present.
class CarTurntable360Viewer extends StatefulWidget {
  const CarTurntable360Viewer({
    required this.vehicleColor,
    this.make = '',
    this.model = '',
    this.year,
    this.carViewsJson,
    super.key,
  });

  final String make;
  final String model;
  final int? year;
  final String vehicleColor;
  final String? carViewsJson;

  @override
  State<CarTurntable360Viewer> createState() => _CarTurntable360ViewerState();
}

class _CarTurntable360ViewerState extends State<CarTurntable360Viewer> {
  int _aiAngleIndex = 1;
  double _dragAccum = 0;
  dynamic _webViewController;
  String? _precachedAssetDir;

  /// Resolves a bundled photorealistic 8-angle studio asset directory for
  /// supported vehicles (e.g., 2026 BMW 320i G20 LCI II).
  String? _resolveBundledStudioDir() {
    final mk = widget.make.trim().toLowerCase();
    final md = widget.model.trim().toLowerCase();
    final combined = '$mk $md';
    if (combined.contains('320i') ||
        combined.contains('320') ||
        (mk.contains('bmw') &&
            (md.contains('3 series') || md.startsWith('3')))) {
      return 'assets/images/cars/bmw_320i_2026';
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheBundledStudioIfNeeded();
  }

  void _precacheBundledStudioIfNeeded() {
    final dir = _resolveBundledStudioDir();
    if (dir == null || dir == _precachedAssetDir) return;
    _precachedAssetDir = dir;
    for (final angle in CarViewAngle.values) {
      precacheImage(AssetImage('$dir/${angle.key}.jpg'), context);
    }
  }

  String _buildPaintScript() {
    final bp = parseCar3dBlueprint(
      widget.carViewsJson,
      make: widget.make,
      model: widget.model,
      color: widget.vehicleColor,
    );
    final pbr = _resolveClearcoatPbr(widget.vehicleColor, bp.paintHex);
    final r = pbr.r.toStringAsFixed(4);
    final g = pbr.g.toStringAsFixed(4);
    final b = pbr.b.toStringAsFixed(4);
    final m = pbr.metallic.toStringAsFixed(2);
    final rough = pbr.roughness.toStringAsFixed(2);

    return '''
function applyPitStopCarPaint() {
  const mv = document.querySelector('model-viewer');
  if (!mv) return;
  mv.shadowIntensity = 1.0;
  mv.shadowSoftness = 0.85;
  if (!mv.model || !mv.model.materials) return;
  for (const mat of mv.model.materials) {
    const name = (mat.name || '').toLowerCase();
    if (name.startsWith('paint 1')) {
      mat.pbrMetallicRoughness.setBaseColorFactor([$r, $g, $b, 1.0]);
      mat.pbrMetallicRoughness.setMetallicFactor($m);
      mat.pbrMetallicRoughness.setRoughnessFactor($rough);
    }
  }
}
const pitStopMv = document.querySelector('model-viewer');
if (pitStopMv) {
  pitStopMv.addEventListener('load', applyPitStopCarPaint);
  if (pitStopMv.loaded) {
    applyPitStopCarPaint();
  }
}
''';
  }

  @override
  void didUpdateWidget(covariant CarTurntable360Viewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.make != widget.make ||
        oldWidget.model != widget.model ||
        oldWidget.year != widget.year ||
        oldWidget.vehicleColor != widget.vehicleColor) {
      _precacheBundledStudioIfNeeded();
    }
    if (oldWidget.vehicleColor != widget.vehicleColor ||
        oldWidget.carViewsJson != widget.carViewsJson) {
      final controller = _webViewController;
      if (controller != null) {
        try {
          controller.runJavaScript(_buildPaintScript());
        } catch (_) {}
      }
    }
  }

  Widget _build360ImageTurntable({
    required Widget imageWidget,
    required Color cardBg,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        _dragAccum += d.delta.dx;
        if (_dragAccum.abs() >= 24) {
          final steps = (_dragAccum / 24).truncate();
          _dragAccum -= steps * 24;
          setState(() {
            final len = CarViewAngle.values.length;
            _aiAngleIndex = ((_aiAngleIndex - steps) % len + len) % len;
          });
        }
      },
      child: SizedBox(
        height: 224,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              height: 28,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TurntableArcPainter(),
                ),
              ),
            ),
            Positioned.fill(
              bottom: 10,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const RadialGradient(
                        center: Alignment.center,
                        radius: 0.72,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.78, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: imageWidget,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;

    final paths = parseCarViewPaths(widget.carViewsJson);
    final existingAiFiles = CarViewAngle.values
        .map((a) => paths[a.key])
        .whereType<String>()
        .where((p) => p.isNotEmpty && File(p).existsSync())
        .toList();

    // 1. If Paid-tier Gemini AI photorealistic angle PNGs exist on disk, scrub them
    if (existingAiFiles.isNotEmpty) {
      final currentAngle =
          CarViewAngle.values[_aiAngleIndex % CarViewAngle.values.length];
      final imgPath = paths[currentAngle.key] ?? existingAiFiles.first;
      return _build360ImageTurntable(
        cardBg: cardBg,
        imageWidget: Image.file(
          File(imgPath),
          height: 192,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }

    // 2. Bundled photorealistic 8-angle studio turntable for exact vehicle match
    final bundledDir = _resolveBundledStudioDir();
    if (bundledDir != null) {
      final currentAngle =
          CarViewAngle.values[_aiAngleIndex % CarViewAngle.values.length];
      return _build360ImageTurntable(
        cardBg: cardBg,
        imageWidget: Image.asset(
          '$bundledDir/${currentAngle.key}.jpg',
          height: 210,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }

    // 3. Interactive WebGL PBR 3D Car (`assets/models/car_studio.glb`)
    if (_supportsNativeWebGlModelViewer) {

      return SizedBox(
        height: 198,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Subtle curved 360° turntable track at bottom of stage
            Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              height: 28,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TurntableArcPainter(),
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ModelViewer(
                  key: ValueKey('car_3d_v2_${isDark ? 'dark' : 'light'}'),
                  src: 'assets/models/car_studio.glb',
                  alt: '${widget.make} ${widget.model} 3D model',
                  backgroundColor: cardBg,
                  cameraControls: true,
                  disableZoom: true,
                  disablePan: true,
                  autoRotate: true,
                  autoRotateDelay: 1000,
                  rotationPerSecond: '18deg',
                  interactionPrompt: InteractionPrompt.none,
                  cameraOrbit: '35deg 77deg 95%',
                  minCameraOrbit: 'auto 62deg auto',
                  maxCameraOrbit: 'auto 86deg auto',
                  fieldOfView: '28deg',
                  exposure: 1.15,
                  relatedCss: '''
                    body, html { background: transparent !important; overflow: hidden; }
                    model-viewer {
                      --poster-color: transparent;
                      --progress-bar-color: #FFAE19;
                      --progress-bar-height: 2px;
                      outline: none;
                    }
                  ''',
                  relatedJs: _buildPaintScript(),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Fallback for headless tests / unsupported desktop targets
    return SizedBox(
      height: 170,
      child: CustomPaint(
        painter: _CarTileSilhouettePainter(angle: CarViewAngle.front34),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TurntableArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = const Color(0xFF6B7280).withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final startX = size.width * 0.08;
    final endX = size.width * 0.92;
    final baseY = size.height * 0.25;
    const sag = 13.0;
    const segments = 34;

    for (int i = 0; i < segments; i++) {
      if (i.isOdd) continue;
      final t0 = i / segments;
      final t1 = (i + 0.6) / segments;
      final x0 = startX + (endX - startX) * t0;
      final x1 = startX + (endX - startX) * t1;
      final y0 = baseY + math.sin(t0 * math.pi) * sag;
      final y1 = baseY + math.sin(t1 * math.pi) * sag;
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CarTileSilhouettePainter extends CustomPainter {
  const _CarTileSilhouettePainter({required this.angle});

  final CarViewAngle angle;

  @override
  void paint(Canvas canvas, Size size) {
    final isFrontOrRear =
        angle == CarViewAngle.front || angle == CarViewAngle.rear;
    final flip = angle == CarViewAngle.sideLeft ||
        angle == CarViewAngle.front34Left ||
        angle == CarViewAngle.rear34Left;

    final fillPaint = Paint()
      ..color = const Color(0xFF232936)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    if (isFrontOrRear) {
      final body = Path()
        ..moveTo(w * 0.20, h * 0.74)
        ..lineTo(w * 0.19, h * 0.52)
        ..quadraticBezierTo(w * 0.22, h * 0.42, w * 0.29, h * 0.40)
        ..lineTo(w * 0.36, h * 0.26)
        ..quadraticBezierTo(w * 0.50, h * 0.23, w * 0.64, h * 0.26)
        ..lineTo(w * 0.71, h * 0.40)
        ..quadraticBezierTo(w * 0.78, h * 0.42, w * 0.81, h * 0.52)
        ..lineTo(w * 0.80, h * 0.74)
        ..close();
      canvas.drawPath(body, fillPaint);
      canvas.drawPath(body, strokePaint);
      return;
    }

    canvas.save();
    if (flip) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    final body = Path()
      ..moveTo(w * 0.10, h * 0.70)
      ..lineTo(w * 0.10, h * 0.55)
      ..quadraticBezierTo(w * 0.13, h * 0.45, w * 0.25, h * 0.42)
      ..lineTo(w * 0.37, h * 0.27)
      ..quadraticBezierTo(w * 0.50, h * 0.23, w * 0.64, h * 0.27)
      ..lineTo(w * 0.77, h * 0.42)
      ..quadraticBezierTo(w * 0.89, h * 0.46, w * 0.90, h * 0.56)
      ..lineTo(w * 0.90, h * 0.70)
      ..close();
    canvas.drawPath(body, fillPaint);
    canvas.drawPath(body, strokePaint);

    final r = math.min(w * 0.075, h * 0.14);
    for (final cx in [w * 0.27, w * 0.73]) {
      canvas.drawCircle(
        Offset(cx, h * 0.70),
        r,
        Paint()..color = const Color(0xFF0B0D10),
      );
      canvas.drawCircle(Offset(cx, h * 0.70), r, strokePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarTileSilhouettePainter oldDelegate) =>
      oldDelegate.angle != angle;
}
