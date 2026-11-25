import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/theme/app_colors.dart';
import 'package:pitstop/core/widgets/empty_state_widget.dart';
import 'package:pitstop/core/widgets/pro_badge_widget.dart';
import 'package:pitstop/features/analytics/domain/models/analytics_models.dart';
import 'package:pitstop/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:pitstop/features/analytics/presentation/bloc/analytics_state.dart';
import 'package:pitstop/features/paywall/cubit/entitlement_cubit.dart';
import 'package:pitstop/features/paywall/presentation/paywall_sheet.dart';

/// Analytics screen featuring:
/// - 2x2 KPI grid (`Monthly spend`, `All-time`, `Avg km/L`, `Cost per km`)
/// - `Spend, last 6 months` stacked bar chart (`Fuel · Maintenance · Other`)
/// - `Resale report` card with `Pro` badge and `Export PDF` button.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({
    required this.vehicle,
    this.onExportPdf,
    this.isExportingPdf = false,
    this.appBarActions,
    super.key,
  });

  final Vehicle? vehicle;
  final VoidCallback? onExportPdf;
  final bool isExportingPdf;
  final List<Widget>? appBarActions;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final activeVehicle = vehicle;

    if (activeVehicle == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'التحليلات' : 'Analytics'),
          actions: appBarActions,
        ),
        body: EmptyStateWidget(
          icon: Icons.bar_chart_rounded,
          title: isArabic ? 'اختر سيارة أولاً' : 'No active vehicle',
          subtitle: isArabic
              ? 'أضف سيارة لعرض إحصائيات المصاريف ومعدل الاستهلاك.'
              : 'Add a vehicle to view spending analytics and fuel efficiency trends.',
        ),
      );
    }

    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        final colors = context.appColors;
        final isPro = context.watch<EntitlementCubit>().state.isPro;
        final wholeFormat = NumberFormat('#,##0');

        return Scaffold(
          appBar: AppBar(
            title: Text(isArabic ? 'التحليلات' : 'Analytics'),
            actions: appBarActions,
          ),
          body: state.status == AnalyticsLoadStatus.loading &&
                  state.monthlySpend.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    // 2x2 KPI Grid
                    Row(
                      children: [
                        Expanded(
                          child: _KpiTile(
                            label: isArabic ? 'مصاريف الشهر' : 'Monthly spend',
                            value: wholeFormat.format(state.thisMonthSpend),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiTile(
                            label: isArabic ? 'الإجمالي الكلي' : 'All-time',
                            value: wholeFormat.format(state.allTimeSpend),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _KpiTile(
                            label: isArabic
                                ? 'متوسط كم/لتر'
                                : 'Avg km/L',
                            value: state.avgKmPerL != null
                                ? state.avgKmPerL!.toStringAsFixed(1)
                                : '—',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiTile(
                            label: isArabic
                                ? 'التكلفة لكل ${activeVehicle.distanceUnit}'
                                : 'Cost per ${activeVehicle.distanceUnit}',
                            value: state.costPerKm != null
                                ? state.costPerKm!.toStringAsFixed(2)
                                : '—',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Spend, last 6 months card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'المصاريف، آخر 6 أشهر'
                                  : 'Spend, last 6 months',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 14,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 156,
                              child: _MonthlySpendBarChart(
                                points: state.monthlySpend,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isArabic
                                  ? 'الوقود · الصيانة · أخرى'
                                  : 'Fuel · Maintenance · Other',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 13,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resale Report Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isArabic
                                            ? 'تقرير إعادة البيع'
                                            : 'Resale report',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isArabic
                                            ? 'ملف PDF مقاس A4 بالعربية والإنجليزية'
                                            : 'A4 PDF, English and Arabic',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: colors.textSecondary,
                                              fontSize: 13.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                ProBadgeWidget(
                                  label: isArabic ? 'برو' : 'Pro',
                                  onTap: isPro
                                      ? null
                                      : () => PaywallSheet.show(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: isExportingPdf ? null : onExportPdf,
                              child: isExportingPdf
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: AppColors.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      isArabic ? 'تصدير PDF' : 'Export PDF',
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlySpendBarChart extends StatelessWidget {
  const _MonthlySpendBarChart({
    required this.points,
  });

  final List<MonthlySpendPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final maxTotal = points.fold<double>(
      0,
      (maxVal, p) => math.max(maxVal, p.total),
    );
    final maxY = maxTotal <= 0 ? 100.0 : maxTotal * 1.12;

    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: List.generate(points.length, (i) {
          final p = points[i];
          // Stack order matching mockup: Fuel (bottom, Amber) -> Maintenance (Teal) -> Other/Expenses (Slate)
          final fEnd = p.fuel;
          final mEnd = fEnd + p.maintenance;
          final eEnd = mEnd + p.expenses;
          final hasData = eEnd > 0;

          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: hasData ? eEnd : maxY * 0.06,
                width: 28,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                rodStackItems: [
                  if (p.fuel > 0)
                    BarChartRodStackItem(0, fEnd, AppColors.chartFuel),
                  if (p.maintenance > 0)
                    BarChartRodStackItem(
                      fEnd,
                      mEnd,
                      AppColors.chartMaintenance,
                    ),
                  if (p.expenses > 0)
                    BarChartRodStackItem(mEnd, eEnd, AppColors.chartOther),
                ],
                color: colors.elevated,
              ),
            ],
          );
        }),
      ),
    );
  }
}
