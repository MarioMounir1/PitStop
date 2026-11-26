import 'package:flutter/material.dart';
import 'package:pitstop/core/theme/app_colors.dart';

/// Racing red accent used in the official `PIT STOP` wordmark.
const Color kPitStopRacingRed = Color(0xFFE53935);

/// Displays the PitStop app icon, automatically switching to:
/// - Simplified racing wheel mark at small sizes (`size <= 36`)
/// - Light version on light themes
/// - Main Pit Crew + Red Fender icon on dark themes.
class PitStopIconBadge extends StatelessWidget {
  const PitStopIconBadge({
    this.size = 72,
    this.forceWheelMark = false,
    super.key,
  });

  final double size;
  final bool forceWheelMark;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String assetPath;
    if (forceWheelMark || size <= 36) {
      assetPath = 'assets/images/pitstop_wheel_mark.png';
    } else if (!isDark) {
      assetPath = 'assets/images/pitstop_icon_light.png';
    } else {
      assetPath = 'assets/images/pitstop_icon.png';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Official `PIT STOP` italic wordmark with 2-row checkered racing stripe
/// and optional `Maintenance, fuel and costs` tagline.
class PitStopWordmark extends StatelessWidget {
  const PitStopWordmark({
    this.fontSize = 30,
    this.showCheckeredStripe = true,
    this.tagline,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    super.key,
  });

  final double fontSize;
  final bool showCheckeredStripe;
  final String? tagline;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final stripeWidth = fontSize * 6.4;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: Theme.of(context).textTheme.headlineLarge?.fontFamily,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 1.0,
                height: 1.05,
              ),
              children: [
                TextSpan(
                  text: 'PIT ',
                  style: TextStyle(color: colors.textPrimary),
                ),
                const TextSpan(
                  text: 'STOP',
                  style: TextStyle(color: kPitStopRacingRed),
                ),
              ],
            ),
          ),
          if (showCheckeredStripe) ...[
            SizedBox(height: fontSize * 0.22),
            SizedBox(
              width: stripeWidth,
              height: fontSize * 0.34,
              child: CustomPaint(
                painter: _CheckeredFlagStripePainter(
                  lightSquareColor: colors.textPrimary,
                ),
              ),
            ),
          ],
          if (tagline != null && tagline!.isNotEmpty) ...[
            SizedBox(height: fontSize * 0.26),
            Text(
              tagline!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckeredFlagStripePainter extends CustomPainter {
  const _CheckeredFlagStripePainter({required this.lightSquareColor});

  final Color lightSquareColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cellHeight = size.height / 2;
    final cols = (size.width / cellHeight).floor().clamp(8, 36);
    final cellWidth = size.width / cols;
    final paint = Paint()..color = lightSquareColor;

    for (int r = 0; r < 2; r++) {
      for (int c = 0; c < cols; c++) {
        if ((r + c).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellWidth, r * cellHeight, cellWidth, cellHeight),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckeredFlagStripePainter oldDelegate) =>
      oldDelegate.lightSquareColor != lightSquareColor;
}
