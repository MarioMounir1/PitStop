import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pitstop/core/services/car_view_generator_service.dart';
import 'package:pitstop/core/theme/app_colors.dart';

/// Maps a vehicle color name (e.g., "White", "Black", "Silver", "Red")
/// to a subtle automotive body fill color for vector 3D fallback rendering.
Color resolveVehicleBodyTint(String colorName) {
  final normalized = colorName.trim().toLowerCase();
  if (normalized.contains('white') || normalized.contains('أبيض')) {
    return const Color(0xFF28303E);
  }
  if (normalized.contains('silver') ||
      normalized.contains('grey') ||
      normalized.contains('gray') ||
      normalized.contains('فضي') ||
      normalized.contains('رمادي')) {
    return const Color(0xFF232935);
  }
  if (normalized.contains('red') || normalized.contains('أحمر')) {
    return const Color(0xFF2E1A1E);
  }
  if (normalized.contains('blue') || normalized.contains('أزرق')) {
    return const Color(0xFF192538);
  }
  if (normalized.contains('green') || normalized.contains('أخضر')) {
    return const Color(0xFF182B24);
  }
  if (normalized.contains('gold') ||
      normalized.contains('champagne') ||
      normalized.contains('ذهبي')) {
    return const Color(0xFF2D2618);
  }
  return const Color(0xFF1C212C);
}

/// Renders a single car view angle (either from a saved Gemini PNG or a
/// sleek amber-wireframe automotive studio vector silhouette).
class CarAngleArtwork extends StatelessWidget {
  const CarAngleArtwork({
    required this.angle,
    this.imagePath,
    this.vehicleColor = 'White',
    this.showWireframeGrid = false,
    super.key,
  });

  final CarViewAngle angle;
  final String? imagePath;
  final String vehicleColor;
  final bool showWireframeGrid;

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
            errorBuilder: (_, _, _) => _buildVector(),
          ),
        );
      }
    }
    return _buildVector();
  }

  Widget _buildVector() {
    return CustomPaint(
      painter: _CarAngleVectorPainter(
        angle: angle,
        bodyFill: resolveVehicleBodyTint(vehicleColor),
        strokeColor: AppColors.primary,
        showWireframeGrid: showWireframeGrid,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Interactive 360° drag-to-rotate vehicle turntable widget for the Dashboard.
class CarTurntable360Viewer extends StatefulWidget {
  const CarTurntable360Viewer({
    required this.vehicleColor,
    this.carViewsJson,
    super.key,
  });

  final String vehicleColor;
  final String? carViewsJson;

  @override
  State<CarTurntable360Viewer> createState() => _CarTurntable360ViewerState();
}

class _CarTurntable360ViewerState extends State<CarTurntable360Viewer> {
  // Default to `side` (index 2) matching the Dashboard hero screenshot!
  int _angleIndex = 2;
  double _dragAccumulator = 0;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _dragAccumulator += details.delta.dx;
    const stepPixels = 28.0;
    if (_dragAccumulator.abs() >= stepPixels) {
      final steps = (_dragAccumulator / stepPixels).truncate();
      _dragAccumulator -= steps * stepPixels;
      final total = CarViewAngle.values.length;
      final nextIndex = (_angleIndex - steps) % total;
      final normalized = nextIndex < 0 ? nextIndex + total : nextIndex;
      if (normalized != _angleIndex) {
        HapticFeedback.selectionClick();
        setState(() => _angleIndex = normalized);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paths = parseCarViewPaths(widget.carViewsJson);
    final currentAngle = CarViewAngle.values[_angleIndex];
    final currentImagePath = paths[currentAngle.key];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      child: SizedBox(
        height: 158,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Turntable shadow + dashed 360° orbit arc
            Positioned.fill(
              child: CustomPaint(
                painter: _TurntableOrbitPainter(
                  activeIndex: _angleIndex,
                  totalAngles: CarViewAngle.values.length,
                ),
              ),
            ),
            // Car render (AI image or 3D-styled amber contour model)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: SizedBox(
                  key: ValueKey('${currentAngle.key}_${currentImagePath ?? 'vec'}'),
                  width: double.infinity,
                  height: 124,
                  child: CarAngleArtwork(
                    angle: currentAngle,
                    imagePath: currentImagePath,
                    vehicleColor: widget.vehicleColor,
                    showWireframeGrid: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurntableOrbitPainter extends CustomPainter {
  const _TurntableOrbitPainter({
    required this.activeIndex,
    required this.totalAngles,
  });

  final int activeIndex;
  final int totalAngles;

  @override
  void paint(Canvas canvas, Size size) {
    final shadowRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.78),
      width: size.width * 0.78,
      height: 22,
    );
    canvas.drawOval(
      shadowRect,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Dashed curved 360° track underneath the car
    final dashPaint = Paint()
      ..color = const Color(0xFF6B7280).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final startX = size.width * 0.07;
    final endX = size.width * 0.93;
    final baseY = size.height * 0.80;
    final sag = 16.0;
    const segments = 34;

    for (int i = 0; i < segments; i++) {
      if (i.isOdd) continue;
      final t0 = i / segments;
      final t1 = (i + 0.65) / segments;
      final x0 = startX + (endX - startX) * t0;
      final x1 = startX + (endX - startX) * t1;
      final y0 = baseY + math.sin(t0 * math.pi) * sag;
      final y1 = baseY + math.sin(t1 * math.pi) * sag;
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TurntableOrbitPainter oldDelegate) =>
      oldDelegate.activeIndex != activeIndex;
}

class _CarAngleVectorPainter extends CustomPainter {
  const _CarAngleVectorPainter({
    required this.angle,
    required this.bodyFill,
    required this.strokeColor,
    required this.showWireframeGrid,
  });

  final CarViewAngle angle;
  final Color bodyFill;
  final Color strokeColor;
  final bool showWireframeGrid;

  @override
  void paint(Canvas canvas, Size size) {
    switch (angle) {
      case CarViewAngle.front:
        _paintFrontOrRear(canvas, size, isRear: false);
      case CarViewAngle.rear:
        _paintFrontOrRear(canvas, size, isRear: true);
      case CarViewAngle.side:
        _paintSideProfile(canvas, size, flipHorizontal: false, skew34: 0);
      case CarViewAngle.sideLeft:
        _paintSideProfile(canvas, size, flipHorizontal: true, skew34: 0);
      case CarViewAngle.front34:
        _paintSideProfile(canvas, size, flipHorizontal: false, skew34: 0.14);
      case CarViewAngle.front34Left:
        _paintSideProfile(canvas, size, flipHorizontal: true, skew34: 0.14);
      case CarViewAngle.rear34:
        _paintSideProfile(canvas, size, flipHorizontal: false, skew34: -0.14);
      case CarViewAngle.rear34Left:
        _paintSideProfile(canvas, size, flipHorizontal: true, skew34: -0.14);
    }
  }

  void _paintSideProfile(
    Canvas canvas,
    Size size, {
    required bool flipHorizontal,
    required double skew34,
  }) {
    canvas.save();
    if (flipHorizontal) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (skew34 != 0) {
      // Compress slightly horizontally to convey 3/4 perspective
      canvas.translate(size.width * 0.06, 0);
      canvas.scale(0.88, 1.0);
    }

    final w = size.width;
    final h = size.height;
    final strokeWidth = showWireframeGrid ? 2.1 : 1.6;

    final fillPaint = Paint()
      ..color = bodyFill
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final gridPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final body = Path()
      ..moveTo(w * 0.10, h * 0.72)
      ..lineTo(w * 0.10, h * 0.54)
      ..quadraticBezierTo(w * 0.12, h * 0.45, w * 0.24, h * 0.42)
      ..lineTo(w * 0.36, h * 0.25)
      ..quadraticBezierTo(w * 0.50, h * 0.21, w * 0.65, h * 0.25)
      ..lineTo(w * 0.78, h * 0.41)
      ..quadraticBezierTo(w * 0.90, h * 0.45, w * 0.91, h * 0.56)
      ..lineTo(w * 0.91, h * 0.72)
      ..close();

    canvas.drawPath(body, fillPaint);

    // Greenhouse window polygon
    final windowPath = Path()
      ..moveTo(w * 0.29, h * 0.41)
      ..lineTo(w * 0.38, h * 0.29)
      ..quadraticBezierTo(w * 0.51, h * 0.26, w * 0.63, h * 0.29)
      ..lineTo(w * 0.74, h * 0.41)
      ..close();

    canvas.drawPath(
      windowPath,
      Paint()..color = const Color(0xFF0E1219),
    );

    if (showWireframeGrid) {
      // Subtle 3D CAD mesh lines matching the Dashboard hero mockup
      canvas.drawLine(
        Offset(w * 0.11, h * 0.55),
        Offset(w * 0.90, h * 0.55),
        gridPaint,
      );
      canvas.drawLine(
        Offset(w * 0.31, h * 0.41),
        Offset(w * 0.31, h * 0.72),
        gridPaint,
      );
      canvas.drawLine(
        Offset(w * 0.51, h * 0.27),
        Offset(w * 0.51, h * 0.72),
        gridPaint,
      );
      canvas.drawLine(
        Offset(w * 0.70, h * 0.41),
        Offset(w * 0.70, h * 0.72),
        gridPaint,
      );
    }

    canvas.drawPath(body, strokePaint);
    canvas.drawPath(windowPath, strokePaint..strokeWidth = strokeWidth * 0.85);

    // Front & rear wheels
    final wheelRadius = math.min(w * 0.068, h * 0.145);
    final wheelY = h * 0.72;
    final rearWheelCenter = Offset(w * 0.27, wheelY);
    final frontWheelCenter = Offset(w * 0.74, wheelY);

    final tireFill = Paint()..color = const Color(0xFF0B0D10);
    final wheelStroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final c in [rearWheelCenter, frontWheelCenter]) {
      canvas.drawCircle(c, wheelRadius, tireFill);
      canvas.drawCircle(c, wheelRadius, wheelStroke);
    }

    canvas.restore();
  }

  void _paintFrontOrRear(Canvas canvas, Size size, {required bool isRear}) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = showWireframeGrid ? 2.1 : 1.6;

    final fillPaint = Paint()
      ..color = bodyFill
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;

    final body = Path()
      ..moveTo(w * 0.20, h * 0.74)
      ..lineTo(w * 0.19, h * 0.50)
      ..quadraticBezierTo(w * 0.21, h * 0.42, w * 0.28, h * 0.40)
      ..lineTo(w * 0.35, h * 0.25)
      ..quadraticBezierTo(w * 0.50, h * 0.22, w * 0.65, h * 0.25)
      ..lineTo(w * 0.72, h * 0.40)
      ..quadraticBezierTo(w * 0.79, h * 0.42, w * 0.81, h * 0.50)
      ..lineTo(w * 0.80, h * 0.74)
      ..close();

    // Tires underneath
    final tirePaint = Paint()..color = const Color(0xFF0B0D10);
    for (final x in [w * 0.24, w * 0.76]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, h * 0.74),
          width: w * 0.09,
          height: h * 0.18,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(r, tirePaint);
      canvas.drawRRect(r, strokePaint);
    }

    canvas.drawPath(body, fillPaint);
    canvas.drawPath(body, strokePaint);

    // Windshield / Rear glass
    final glass = Path()
      ..moveTo(w * 0.31, h * 0.40)
      ..lineTo(w * 0.37, h * 0.28)
      ..lineTo(w * 0.63, h * 0.28)
      ..lineTo(w * 0.69, h * 0.40)
      ..close();
    canvas.drawPath(glass, Paint()..color = const Color(0xFF0E1219));
    canvas.drawPath(glass, strokePaint);

    // Headlights or Taillights
    final lampColor = isRear ? AppColors.overdue : strokeColor;
    final lampPaint = Paint()
      ..color = lampColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.23, h * 0.49, w * 0.12, h * 0.07),
        const Radius.circular(4),
      ),
      lampPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.65, h * 0.49, w * 0.12, h * 0.07),
        const Radius.circular(4),
      ),
      lampPaint,
    );

    // Grille / trunk bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.39, h * 0.52, w * 0.22, h * 0.08),
        const Radius.circular(4),
      ),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CarAngleVectorPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.bodyFill != bodyFill ||
      oldDelegate.showWireframeGrid != showWireframeGrid;
}
