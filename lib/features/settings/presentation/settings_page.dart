import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:torq/core/services/backup_service.dart';
import 'package:torq/core/theme/app_colors.dart';
import 'package:torq/core/widgets/ad_banner_widget.dart';
import 'package:torq/core/widgets/pro_badge_widget.dart';
import 'package:torq/features/paywall/cubit/entitlement_cubit.dart';
import 'package:torq/features/paywall/cubit/entitlement_state.dart';
import 'package:torq/features/paywall/presentation/paywall_sheet.dart';
import 'package:torq/features/settings/cubit/settings_cubit.dart';
import 'package:torq/features/settings/cubit/settings_state.dart';

/// Grouped Material 3 settings screen for language, theme, units, currency,
/// Pro-gated JSON backup/restore, and Torq Pro upgrade.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    this.backupService,
    this.onBackupRestored,
    super.key,
  });

  final BackupService? backupService;
  final VoidCallback? onBackupRestored;

  Future<void> _handleExportBackup(BuildContext context, bool isPro) async {
    if (!isPro) {
      await PaywallSheet.show(context);
      return;
    }
    final service = backupService;
    if (service == null) return;

    try {
      await service.exportAndShare();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup export failed: $e')),
      );
    }
  }

  Future<void> _handleRestoreBackup(BuildContext context, bool isPro) async {
    if (!isPro) {
      await PaywallSheet.show(context);
      return;
    }
    final service = backupService;
    if (service == null) return;

    final isArabic = context.read<SettingsCubit>().state.isArabic;
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArabic ? 'استعادة نسخة احتياطية' : 'Restore JSON Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic
                  ? 'أدخل مسار ملف JSON أو الصق محتوى النسخة الاحتياطية. سيؤدي ذلك إلى استبدال البيانات الحالية.'
                  : 'Enter a JSON backup file path or paste the JSON backup content. This will replace current data.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: isArabic
                    ? '{"app": "torq", ...} أو مسار الملف'
                    : '{"app": "torq", ...} or file path',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isArabic ? 'استعادة' : 'Restore'),
          ),
        ],
      ),
    );

    final input = controller.text.trim();
    controller.dispose();

    if (confirmed != true || input.isEmpty || !context.mounted) return;

    try {
      final BackupRestoreSummary summary;
      if (input.startsWith('{')) {
        summary = await service.restoreFromJsonString(input);
      } else {
        final file = File(input);
        summary = await service.restoreFromFile(file);
      }
      onBackupRestored?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تمت الاستعادة: ${summary.vehiclesCount} سيارة و ${summary.maintenanceCount} صيانة'
                : 'Restored ${summary.vehiclesCount} vehicles and ${summary.maintenanceCount} service records.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final isArabic = settings.isArabic;

        return BlocBuilder<EntitlementCubit, EntitlementState>(
          builder: (context, entitlement) {
            return Scaffold(
              appBar: AppBar(
                title: Text(isArabic ? 'الإعدادات' : 'Settings'),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _ProUpgradeCard(
                          isPro: entitlement.isPro,
                          isArabic: isArabic,
                          onTap: () => PaywallSheet.show(context),
                        ),
                        const SizedBox(height: 20),
                        _SectionHeader(
                          title: isArabic ? 'المظهر واللغة' : 'Appearance & Language',
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.language_rounded,
                                          size: 20,
                                          color: colors.textSecondary,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          isArabic ? 'اللغة' : 'Language',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: SegmentedButton<String>(
                                        segments: const [
                                          ButtonSegment<String>(
                                            value: 'en',
                                            label: Text('English'),
                                          ),
                                          ButtonSegment<String>(
                                            value: 'ar',
                                            label: Text('العربية'),
                                          ),
                                        ],
                                        selected: {settings.locale.languageCode},
                                        onSelectionChanged: (selection) {
                                          context
                                              .read<SettingsCubit>()
                                              .setLocale(
                                                Locale(selection.first),
                                              );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.contrast_rounded,
                                          size: 20,
                                          color: colors.textSecondary,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          isArabic ? 'المظهر' : 'Theme',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: SegmentedButton<ThemeMode>(
                                        segments: [
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.dark,
                                            icon: const Icon(
                                              Icons.dark_mode_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isArabic ? 'داكن' : 'Dark',
                                            ),
                                          ),
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.light,
                                            icon: const Icon(
                                              Icons.light_mode_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isArabic ? 'فاتح' : 'Light',
                                            ),
                                          ),
                                        ],
                                        selected: {settings.themeMode},
                                        onSelectionChanged: (selection) {
                                          context
                                              .read<SettingsCubit>()
                                              .setThemeMode(selection.first);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionHeader(
                          title: isArabic ? 'الوحدات والعملة' : 'Units & Currency',
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: Icon(
                                  Icons.speed_rounded,
                                  color: colors.textSecondary,
                                ),
                                title: Text(
                                  isArabic ? 'وحدة المسافة الافتراضية' : 'Default Distance Unit',
                                ),
                                trailing: SegmentedButton<String>(
                                  showSelectedIcon: false,
                                  segments: [
                                    ButtonSegment(
                                      value: 'km',
                                      label: Text(isArabic ? 'كم' : 'km'),
                                    ),
                                    ButtonSegment(
                                      value: 'mi',
                                      label: Text(isArabic ? 'ميل' : 'mi'),
                                    ),
                                  ],
                                  selected: {settings.distanceUnit},
                                  onSelectionChanged: (selection) {
                                    context
                                        .read<SettingsCubit>()
                                        .setDistanceUnit(selection.first);
                                  },
                                ),
                              ),
                              const Divider(),
                              ListTile(
                                leading: Icon(
                                  Icons.payments_outlined,
                                  color: colors.textSecondary,
                                ),
                                title: Text(
                                  isArabic ? 'العملة الافتراضية' : 'Default Currency',
                                ),
                                trailing: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: settings.currencyCode,
                                    dropdownColor: colors.elevated,
                                    borderRadius: BorderRadius.circular(12),
                                    items: SettingsCubit.supportedCurrencies
                                        .map(
                                          (code) => DropdownMenuItem<String>(
                                            value: code,
                                            child: Text(
                                              code,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        context
                                            .read<SettingsCubit>()
                                            .setCurrencyCode(value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionHeader(
                          title: isArabic
                              ? 'البيانات والنسخ الاحتياطي'
                              : 'Data & Backup',
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: Icon(
                                  Icons.upload_file_rounded,
                                  color: colors.textSecondary,
                                ),
                                title: Text(
                                  isArabic
                                      ? 'تصدير نسخة احتياطية (JSON)'
                                      : 'Export JSON Backup',
                                ),
                                subtitle: Text(
                                  isArabic
                                      ? 'حفظ ومشاركة جميع سياراتك وسجلاتك'
                                      : 'Save and share all vehicles and records',
                                ),
                                trailing: entitlement.isPro
                                    ? const Icon(Icons.chevron_right_rounded)
                                    : const ProBadgeWidget(compact: true),
                                onTap: () => _handleExportBackup(
                                  context,
                                  entitlement.isPro,
                                ),
                              ),
                              const Divider(),
                              ListTile(
                                leading: Icon(
                                  Icons.download_for_offline_outlined,
                                  color: colors.textSecondary,
                                ),
                                title: Text(
                                  isArabic
                                      ? 'استعادة من نسخة احتياطية (JSON)'
                                      : 'Restore JSON Backup',
                                ),
                                subtitle: Text(
                                  isArabic
                                      ? 'استيراد بياناتك بأمان داخل قاعدة البيانات'
                                      : 'Safely restore records into local storage',
                                ),
                                trailing: entitlement.isPro
                                    ? const Icon(Icons.chevron_right_rounded)
                                    : const ProBadgeWidget(compact: true),
                                onTap: () => _handleRestoreBackup(
                                  context,
                                  entitlement.isPro,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Center(child: AdBannerWidget()),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.appColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ProUpgradeCard extends StatelessWidget {
  const _ProUpgradeCard({
    required this.isPro,
    required this.isArabic,
    required this.onTap,
  });

  final bool isPro;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isPro) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.ok.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ok.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              color: AppColors.ok,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'تورك برو مفعّل' : 'Torq Pro Active',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ok,
                        ),
                  ),
                  Text(
                    isArabic
                        ? 'جميع المزايا الاحترافية متاحة بدون إعلانات.'
                        : 'All Pro features unlocked with zero ads.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const ProBadgeWidget(),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF1E2638)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProBadgeWidget(),
                  const SizedBox(height: 10),
                  Text(
                    isArabic ? 'ترقية إلى تورك برو' : 'Upgrade to Torq Pro',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? 'سيارات غير محدودة، تقارير PDF نظيفة، نسخ احتياطي، وبدون إعلانات.'
                        : 'Unlimited cars, clean resale PDFs, JSON backups, and zero ads.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFCBD5E1),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
