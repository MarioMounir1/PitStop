import 'package:flutter/material.dart';
import 'package:torq/core/theme/app_colors.dart';

/// Semantic health status for maintenance items and vehicle documents.
enum StatusChipType {
  ok,
  dueSoon,
  overdue,
}

/// Compact semantic pill used across maintenance cards, alerts, and dashboards.
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

  Color _colorForType(AppColorExtension colors) {
    return switch (type) {
      StatusChipType.ok => colors.ok,
      StatusChipType.dueSoon => colors.dueSoon,
      StatusChipType.overdue => colors.overdue,
    };
  }

  IconData _defaultIconForType() {
    return switch (type) {
      StatusChipType.ok => Icons.check_circle_rounded,
      StatusChipType.dueSoon => Icons.schedule_rounded,
      StatusChipType.overdue => Icons.warning_amber_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(context.appColors);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? _defaultIconForType(),
            size: compact ? 13 : 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 11 : 12,
                ),
          ),
        ],
      ),
    );
  }
}
