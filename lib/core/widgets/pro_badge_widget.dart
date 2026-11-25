import 'package:flutter/material.dart';
import 'package:pitstop/core/theme/app_colors.dart';

/// Warm amber pill badge highlighting PitStop Pro or AI features.
class ProBadgeWidget extends StatelessWidget {
  const ProBadgeWidget({
    this.label = 'Pro',
    this.compact = false,
    this.onTap,
    super.key,
  });

  final String label;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.dueSoonSurfaceDark
        : AppColors.primary.withValues(alpha: 0.18);
    final fg = isDark ? AppColors.dueSoon : const Color(0xFF92400E);

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
      ),
    );

    if (onTap == null) return badge;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: badge,
    );
  }
}
