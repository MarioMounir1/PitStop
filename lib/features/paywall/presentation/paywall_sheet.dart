import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:torq/core/theme/app_colors.dart';
import 'package:torq/core/widgets/pro_badge_widget.dart';
import 'package:torq/features/paywall/cubit/entitlement_cubit.dart';
import 'package:torq/features/paywall/cubit/entitlement_state.dart';

enum _PaywallPlan { monthly, yearly, lifetime }

/// Dark glassmorphic Material 3 paywall comparing Torq Free vs Pro.
class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key});

  /// Presents the paywall as a full-height dark glassmorphic bottom sheet.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const PaywallSheet(),
    );
  }

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  _PaywallPlan _selectedPlan = _PaywallPlan.yearly;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<EntitlementCubit>();
    if (cubit.state.offerings == null && !cubit.state.isLoading) {
      cubit.loadEntitlements();
    }
  }

  Package? _packageForPlan(Offerings? offerings, _PaywallPlan plan) {
    final current = offerings?.current;
    if (current == null) return null;
    return switch (plan) {
      _PaywallPlan.monthly => current.monthly,
      _PaywallPlan.yearly => current.annual,
      _PaywallPlan.lifetime => current.lifetime,
    };
  }

  Future<void> _onPurchasePressed(
    BuildContext context,
    EntitlementState state,
  ) async {
    final cubit = context.read<EntitlementCubit>();
    final selectedPackage = _packageForPlan(state.offerings, _selectedPlan);

    final bool upgraded;
    if (selectedPackage != null) {
      upgraded = await cubit.purchasePackage(selectedPackage);
    } else if (cubit.isDebugFallback) {
      upgraded = await cubit.purchaseDebugFallback();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store packages are unavailable right now.'),
        ),
      );
      return;
    }

    if (upgraded && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _onRestorePressed(BuildContext context) async {
    final cubit = context.read<EntitlementCubit>();
    final restored = await cubit.restorePurchases();
    if (!context.mounted) return;
    if (restored) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active Pro subscription found to restore.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return BlocConsumer<EntitlementCubit, EntitlementState>(
      listenWhen: (prev, curr) =>
          curr.error != null && curr.error != prev.error,
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
          context.read<EntitlementCubit>().clearError();
        }
      },
      builder: (context, state) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              ),
              decoration: BoxDecoration(
                color: AppColors.darkBackground.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.darkBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const ProBadgeWidget(),
                            const SizedBox(width: 10),
                            Text(
                              isArabic ? 'تورك برو' : 'Torq Pro',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppColors.darkTextPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArabic
                          ? 'احصل على تجربة كاملة بلا إعلانات وتقارير بيع احترافية.'
                          : 'Unlock unlimited vehicles, clean resale PDFs, backups, and zero ads.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _ComparisonTable(isArabic: isArabic),
                    const SizedBox(height: 20),
                    _buildPlanCard(
                      plan: _PaywallPlan.yearly,
                      title: isArabic ? 'سنوي' : 'Yearly',
                      subtitle: isArabic ? 'أفضل قيمة — وفر 40%' : 'Best Value — Save 40%',
                      price: _packageForPlan(
                                state.offerings,
                                _PaywallPlan.yearly,
                              )?.storeProduct.priceString ??
                          r'$19.99 / yr',
                      badge: isArabic ? 'الأكثر توفيراً' : 'POPULAR',
                    ),
                    const SizedBox(height: 10),
                    _buildPlanCard(
                      plan: _PaywallPlan.monthly,
                      title: isArabic ? 'شهري' : 'Monthly',
                      subtitle: isArabic ? 'إلغاء في أي وقت' : 'Cancel anytime',
                      price: _packageForPlan(
                                state.offerings,
                                _PaywallPlan.monthly,
                              )?.storeProduct.priceString ??
                          r'$2.99 / mo',
                    ),
                    const SizedBox(height: 10),
                    _buildPlanCard(
                      plan: _PaywallPlan.lifetime,
                      title: isArabic ? 'مدى الحياة' : 'Lifetime',
                      subtitle: isArabic
                          ? 'دفعة واحدة فقط — ملكك للأبد'
                          : 'One-time purchase — yours forever',
                      price: _packageForPlan(
                                state.offerings,
                                _PaywallPlan.lifetime,
                              )?.storeProduct.priceString ??
                          r'$49.99',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: state.isLoading
                          ? null
                          : () => _onPurchasePressed(context, state),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.primary,
                      ),
                      child: state.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isArabic
                                  ? 'الترقية إلى تورك برو'
                                  : 'Continue with Torq Pro',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: state.isLoading
                          ? null
                          : () => _onRestorePressed(context),
                      child: Text(
                        isArabic ? 'استعادة المشتريات' : 'Restore Purchases',
                        style: const TextStyle(
                          color: AppColors.darkTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard({
    required _PaywallPlan plan,
    required String title,
    required String subtitle,
    required String price,
    String? badge,
  }) {
    final isSelected = _selectedPlan == plan;

    return InkWell(
      onTap: () => setState(() => _selectedPlan = plan),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.darkCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.darkBorder,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color:
                  isSelected ? AppColors.primary : AppColors.darkTextMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ok.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: AppColors.ok,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                color: AppColors.darkTextPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, bool, bool)>[
      (isArabic ? 'سيارات غير محدودة' : 'Unlimited Cars', false, true),
      (isArabic ? 'تقرير بيع PDF بدون علامة مائية' : 'Clean Resale PDF', false, true),
      (isArabic ? 'حفظ صور الفواتير' : 'Receipt Photos', false, true),
      (isArabic ? 'نسخ احتياطي واستعادة JSON' : 'JSON Backup & Restore', false, true),
      (isArabic ? 'بدون إعلانات نهائياً' : 'Zero Ads', false, true),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isArabic ? 'الميزة' : 'Feature',
                  style: const TextStyle(
                    color: AppColors.darkTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  isArabic ? 'مجاني' : 'Free',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.darkTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  isArabic ? 'برو' : 'Pro',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.darkBorder),
          for (final (label, freeHas, proHas) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Icon(
                      freeHas ? Icons.check_rounded : Icons.remove_rounded,
                      size: 18,
                      color: freeHas
                          ? AppColors.ok
                          : AppColors.darkTextMuted,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Icon(
                      proHas
                          ? Icons.check_circle_rounded
                          : Icons.remove_rounded,
                      size: 18,
                      color: proHas
                          ? AppColors.ok
                          : AppColors.darkTextMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
