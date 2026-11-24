import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/theme/app_colors.dart';
import 'package:torq/core/utils/currency_formatter.dart';
import 'package:torq/core/widgets/empty_state_widget.dart';
import 'package:torq/features/analytics/domain/models/analytics_models.dart';
import 'package:torq/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:torq/features/analytics/presentation/bloc/analytics_state.dart';

/// Analytics dashboard displaying spend KPIs, 6-month spend bar chart,
/// fuel efficiency (`km/L`) line chart, and Resale Maintenance PDF export CTA.
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
          icon: Icons.insights_outlined,
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
        final locale = isArabic ? 'ar' : 'en';

        return Scaffold(
          appBar: AppBar(
            title: Text(isArabic ? 'التحليلات' : 'Analytics'),
            actions: appBarActions,
          ),
          body: state.status == AnalyticsLoadStatus.loading &&
                  state.monthlySpend.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                  children: [
                    // Prominent Export Resale PDF CTA
                    FilledButton.icon(
                      onPressed: isExportingPdf ? null : onExportPdf,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.primary,
                      ),
                      icon: isExportingPdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(
                        isArabic
                            ? 'تصدير تقرير صيانة لإعادة البيع (PDF)'
                            : 'Export Resale Maintenance Report (PDF)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // KPI Grid (This Month, All Time, Avg km/L, Cost/km)
                    Row(
                      children: [
                        Expanded(
                          child: _KpiTile(
                            label: isArabic ? 'هذا الشهر' : 'This Month',
                            value: CurrencyFormatter.formatCompact(
                              state.thisMonthSpend,
                              currencyCode: activeVehicle.currencyCode,
                              locale: locale,
                            ),
                            accent: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _KpiTile(
                            label: isArabic ? 'الإجمالي الكلي' : 'All Time',
                            value: CurrencyFormatter.formatCompact(
                              state.allTimeSpend,
                              currencyCode: activeVehicle.currencyCode,
                              locale: locale,
                            ),
                            accent: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _KpiTile(
                            label:
                                isArabic ? 'متوسط الاستهلاك' : 'Avg Economy',
                            value: state.avgKmPerL != null
                                ? '${state.avgKmPerL!.toStringAsFixed(1)} ${isArabic ? 'كم/لتر' : 'km/L'}'
                                : '—',
                            accent: AppColors.ok,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _KpiTile(
                            label: isArabic
                                ? 'التكلفة / ${activeVehicle.distanceUnit}'
                                : 'Cost / ${activeVehicle.distanceUnit}',
                            value: state.costPerKm != null
                                ? CurrencyFormatter.format(
                                    state.costPerKm!,
                                    currencyCode: activeVehicle.currencyCode,
                                    locale: locale,
                                    decimalDigits: 2,
                                  )
                                : '—',
                            accent: AppColors.dueSoon,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Monthly Spend BarChart (Last 6 Months)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'المصاريف الشهرية (آخر 6 أشهر)'
                                  : 'Monthly Spend (Last 6 Months)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 14,
                              runSpacing: 6,
                              children: [
                                _LegendDot(
                                  color: AppColors.primary,
                                  label: isArabic ? 'الصيانة' : 'Maintenance',
                                ),
                                _LegendDot(
                                  color: AppColors.ok,
                                  label: isArabic ? 'الوقود' : 'Fuel',
                                ),
                                _LegendDot(
                                  color: AppColors.dueSoon,
                                  label: isArabic ? 'المصاريف' : 'Expenses',
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 200,
                              child: _MonthlySpendBarChart(
                                points: state.monthlySpend,
                                locale: locale,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fuel Efficiency LineChart
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'تطور كفاءة الوقود (كم/لتر)'
                                  : 'Fuel Efficiency Trend (km/L)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 14),
                            if (state.fuelTrend.length < 2)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 28),
                                child: Center(
                                  child: Text(
                                    isArabic
                                        ? 'سجّل عمليتي تفويل كامل على الأقل لعرض المنحنى.'
                                        : 'Log at least 2 full-tank fill-ups to view the trend.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: colors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 190,
                                child: _FuelEfficiencyLineChart(
                                  points: state.fuelTrend,
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
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _MonthlySpendBarChart extends StatelessWidget {
  const _MonthlySpendBarChart({
    required this.points,
    required this.locale,
  });

  final List<MonthlySpendPoint> points;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final maxTotal = points.fold<double>(
      0,
      (maxVal, p) => math.max(maxVal, p.total),
    );
    final maxY = maxTotal <= 0 ? 100.0 : maxTotal * 1.2;
    final monthFormat = DateFormat('MMM', locale);

    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.border,
            strokeWidth: 0.8,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    monthFormat.format(points[idx].month),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(points.length, (i) {
          final p = points[i];
          final mEnd = p.maintenance;
          final fEnd = mEnd + p.fuel;
          final eEnd = fEnd + p.expenses;

          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: eEnd,
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                rodStackItems: [
                  if (p.maintenance > 0)
                    BarChartRodStackItem(0, mEnd, AppColors.primary),
                  if (p.fuel > 0)
                    BarChartRodStackItem(mEnd, fEnd, AppColors.ok),
                  if (p.expenses > 0)
                    BarChartRodStackItem(fEnd, eEnd, AppColors.dueSoon),
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

class _FuelEfficiencyLineChart extends StatelessWidget {
  const _FuelEfficiencyLineChart({required this.points});

  final List<FuelTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spots = List<FlSpot>.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].kmPerL),
    );

    final minVal = points.map((p) => p.kmPerL).reduce(math.min);
    final maxVal = points.map((p) => p.kmPerL).reduce(math.max);
    final minY = math.max(0.0, (minVal - 2).floorToDouble());
    final maxY = (maxVal + 2).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.border,
            strokeWidth: 0.8,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.ok,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.ok.withValues(alpha: 0.28),
                  AppColors.ok.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
