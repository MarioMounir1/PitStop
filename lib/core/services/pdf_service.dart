import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/utils/currency_formatter.dart';

/// Generates A4 Resale Maintenance Reports in Arabic (RTL) or English (LTR)
/// with optional PitStop Free watermarking.
class PdfService {
  static const PdfColor _navyDark = PdfColor.fromInt(0xFF0B0F17);
  static const PdfColor _navyCard = PdfColor.fromInt(0xFF141A26);
  static const PdfColor _accentBlue = PdfColor.fromInt(0xFF3B82F6);
  static const PdfColor _borderLight = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _surfaceLight = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _textPrimary = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _textSecondary = PdfColor.fromInt(0xFF475569);

  pw.Font? _cairoRegular;
  pw.Font? _cairoBold;

  Future<void> _ensureFontsLoaded() async {
    if (_cairoRegular != null && _cairoBold != null) return;
    final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    _cairoRegular = pw.Font.ttf(regularData);
    _cairoBold = pw.Font.ttf(boldData);
  }

  /// Generates an A4 Resale Maintenance Report PDF as bytes.
  Future<Uint8List> generateResaleReport({
    required Vehicle vehicle,
    required List<MaintenanceRecord> maintenanceRecords,
    required List<FuelLog> fuelLogs,
    required bool isPro,
    required bool isArabic,
  }) async {
    await _ensureFontsLoaded();

    final locale = isArabic ? 'ar' : 'en';
    final textDirection =
        isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final sortedRecords = List<MaintenanceRecord>.from(maintenanceRecords)
      ..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));

    final totalMaintenanceCost = sortedRecords.fold<double>(
      0,
      (sum, r) => sum + r.cost,
    );
    final totalFuelCost = fuelLogs.fold<double>(
      0,
      (sum, f) => sum + f.totalCost,
    );
    final totalSpent = totalMaintenanceCost + totalFuelCost;

    final validEconomyLogs = fuelLogs
        .where((f) => f.consumptionKmPerL != null && f.consumptionKmPerL! > 0)
        .toList();
    final avgKmPerL = validEconomyLogs.isEmpty
        ? null
        : validEconomyLogs.fold<double>(
              0,
              (sum, f) => sum + f.consumptionKmPerL!,
            ) /
            validEconomyLogs.length;

    final dateFormat = DateFormat('yyyy-MM-dd');
    final numberFormat = NumberFormat('#,##0', locale);

    final theme = pw.ThemeData.withFont(
      base: _cairoRegular!,
      bold: _cairoBold!,
    );

    final pdf = pw.Document(
      title: '${vehicle.make} ${vehicle.model} (${vehicle.year}) - Resale Report',
      author: 'PitStop',
      theme: theme,
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          textDirection: textDirection,
          theme: theme,
          buildBackground: !isPro
              ? (context) => _buildWatermarkLayer()
              : null,
        ),
        header: (context) => pw.Directionality(
          textDirection: textDirection,
          child: _buildPageHeader(isArabic: isArabic, dateFormat: dateFormat),
        ),
        footer: (context) => pw.Directionality(
          textDirection: textDirection,
          child: _buildPageFooter(
            context: context,
            isArabic: isArabic,
            isPro: isPro,
          ),
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: textDirection,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildVehicleHeaderCard(
                  vehicle: vehicle,
                  isArabic: isArabic,
                  numberFormat: numberFormat,
                ),
                pw.SizedBox(height: 16),
                _buildSummaryKpis(
                  vehicle: vehicle,
                  totalSpent: totalSpent,
                  avgKmPerL: avgKmPerL,
                  isArabic: isArabic,
                  locale: locale,
                  numberFormat: numberFormat,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  isArabic
                      ? 'سجل الصيانة الزمني'
                      : 'Chronological Service History',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                pw.SizedBox(height: 8),
                if (sortedRecords.isEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: _surfaceLight,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: _borderLight),
                    ),
                    child: pw.Text(
                      isArabic
                          ? 'لا توجد سجلات صيانة مسجلة لهذه السيارة.'
                          : 'No maintenance records logged for this vehicle.',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: _textSecondary,
                      ),
                    ),
                  )
                else
                  _buildServiceHistoryTable(
                    records: sortedRecords,
                    vehicle: vehicle,
                    isArabic: isArabic,
                    locale: locale,
                    dateFormat: dateFormat,
                    numberFormat: numberFormat,
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Opens the native print / PDF preview dialog via `printing`.
  Future<void> previewOrPrint({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    await Printing.layoutPdf(
      name: fileName,
      onLayout: (_) async => pdfBytes,
    );
  }

  /// Saves the generated PDF to a temporary file and opens the native share sheet.
  Future<File> sharePdf({
    required Uint8List pdfBytes,
    required String fileName,
    String? subject,
  }) async {
    final safeName =
        fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}${Platform.pathSeparator}$safeName');
    await file.writeAsBytes(pdfBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject ?? safeName,
      ),
    );

    return file;
  }

  pw.Widget _buildWatermarkLayer() {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: -math.pi / 5,
          child: pw.Opacity(
            opacity: 0.12,
            child: pw.Text(
              'Generated with PitStop Free',
              style: pw.TextStyle(
                fontSize: 38,
                fontWeight: pw.FontWeight.bold,
                color: _navyCard,
              ),
            ),
          ),
        ),
      ),
    );
  }

  pw.Widget _buildPageHeader({
    required bool isArabic,
    required DateFormat dateFormat,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderLight, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: _accentBlue,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                isArabic
                    ? 'بيت ستوب — تقرير صيانة لإعادة البيع'
                    : 'PITSTOP — Vehicle Resale Maintenance Report',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _navyDark,
                ),
              ),
            ],
          ),
          pw.Text(
            '${isArabic ? 'تاريخ الإصدار' : 'Generated'}: ${dateFormat.format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPageFooter({
    required pw.Context context,
    required bool isArabic,
    required bool isPro,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _borderLight, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            isPro
                ? (isArabic ? 'تقرير موثّق عبر بيت ستوب برو' : 'Verified with PitStop Pro')
                : 'Generated with PitStop Free',
            style: const pw.TextStyle(fontSize: 8.5, color: _textSecondary),
          ),
          pw.Text(
            isArabic
                ? 'صفحة ${context.pageNumber} من ${context.pagesCount}'
                : 'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildVehicleHeaderCard({
    required Vehicle vehicle,
    required bool isArabic,
    required NumberFormat numberFormat,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _navyCard,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${vehicle.make} ${vehicle.model}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${isArabic ? 'الموديل' : 'Year'}: ${vehicle.year}'
                '${vehicle.plateNumber != null && vehicle.plateNumber!.isNotEmpty ? '  •  ${isArabic ? 'اللوحة' : 'Plate'}: ${vehicle.plateNumber}' : ''}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFFCBD5E1),
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: _accentBlue,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  vehicle.fuelType.replaceAll('_', ' ').toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${numberFormat.format(vehicle.currentOdometer)} ${vehicle.distanceUnit}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryKpis({
    required Vehicle vehicle,
    required double totalSpent,
    required double? avgKmPerL,
    required bool isArabic,
    required String locale,
    required NumberFormat numberFormat,
  }) {
    final totalSpentStr = CurrencyFormatter.format(
      totalSpent,
      currencyCode: vehicle.currencyCode,
      locale: locale,
      decimalDigits: 0,
    );
    final avgEconomyStr = avgKmPerL == null
        ? '—'
        : '${avgKmPerL.toStringAsFixed(1)} ${isArabic ? 'كم/لتر' : 'km/L'}';
    final odometerStr =
        '${numberFormat.format(vehicle.currentOdometer)} ${vehicle.distanceUnit}';

    return pw.Row(
      children: [
        pw.Expanded(
          child: _kpiTile(
            label: isArabic ? 'إجمالي المصروفات' : 'Total Spent',
            value: totalSpentStr,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _kpiTile(
            label: isArabic ? 'متوسط الاستهلاك' : 'Avg Economy',
            value: avgEconomyStr,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _kpiTile(
            label: isArabic ? 'العداد الحالي' : 'Current Odometer',
            value: odometerStr,
          ),
        ),
      ],
    );
  }

  pw.Widget _kpiTile({
    required String label,
    required String value,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _surfaceLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderLight),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: _textSecondary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildServiceHistoryTable({
    required List<MaintenanceRecord> records,
    required Vehicle vehicle,
    required bool isArabic,
    required String locale,
    required DateFormat dateFormat,
    required NumberFormat numberFormat,
  }) {
    final headers = isArabic
        ? ['التاريخ', 'الخدمة', 'العداد', 'مركز الصيانة', 'التكلفة']
        : ['Date', 'Service', 'Odometer', 'Service Center', 'Cost'];

    final rows = records.map((r) {
      return [
        dateFormat.format(r.serviceDate),
        r.title,
        '${numberFormat.format(r.odometerAtService)} ${vehicle.distanceUnit}',
        (r.serviceCenter != null && r.serviceCenter!.isNotEmpty)
            ? r.serviceCenter!
            : '—',
        CurrencyFormatter.format(
          r.cost,
          currencyCode: vehicle.currencyCode,
          locale: locale,
          decimalDigits: 0,
        ),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: _borderLight, width: 0.6),
      headerDecoration: const pw.BoxDecoration(color: _navyCard),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9.5,
      ),
      cellStyle: const pw.TextStyle(
        color: _textPrimary,
        fontSize: 9,
      ),
      oddRowDecoration: const pw.BoxDecoration(color: _surfaceLight),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellAlignment:
          isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      headerAlignment:
          isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    );
  }
}
