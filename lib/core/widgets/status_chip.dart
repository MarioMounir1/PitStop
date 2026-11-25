import 'package:flutter/material.dart';
import 'package:pitstop/core/theme/app_colors.dart';

/// Semantic health status for maintenance items and vehicle documents.
enum StatusChipType {
  ok,
  dueSoon,
  overdue,
}

/// Clean semantic pill matching the Dark Amber Automotive design system.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.type,
    required this.label,
    this.icon,
    this.compact = false,
    super.key,
  });

  final StatusChipType type;
  final String label;
  final IconData? icon;
  final bool compact;

  Color _textColor(AppColorExtension colors) {
    return switch (type) {
      StatusChipType.ok => colors.ok,
      StatusChipType.dueSoon => colors.dueSoon,
      StatusChipType.overdue => colors.overdue,
    };
  }

  Color _backgroundColor(BuildContext context, Color foreground) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return foreground.withValues(alpha: 0.14);
    }
    return switch (type) {
      StatusChipType.ok => AppColors.okSurfaceDark,
      StatusChipType.dueSoon => AppColors.dueSoonSurfaceDark,
      StatusChipType.overdue => AppColors.overdueSurfaceDark,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fg = _textColor(context.appColors);
    final bg = _backgroundColor(context, fg);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 13,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: compact ? 13 : 15,
              color: fg,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12 : 13,
                ),
          ),
        ],
      ),
    );
  }
}
