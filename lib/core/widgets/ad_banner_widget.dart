import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pitstop/core/services/monetization_service.dart';
import 'package:pitstop/features/paywall/cubit/entitlement_cubit.dart';
import 'package:pitstop/features/paywall/cubit/entitlement_state.dart';

/// Displays an AdMob banner ad for Free users and automatically collapses
/// to [SizedBox.shrink] whenever `EntitlementCubit.state.isPro == true`.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({
    this.adUnitId,
    super.key,
  });

  final String? adUnitId;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  bool get _isMobileSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isPro = context.read<EntitlementCubit>().state.isPro;
      if (!isPro) {
        _loadBanner();
      }
    });
  }

  void _loadBanner() {
    if (!_isMobileSupported || _bannerAd != null) return;
    final unitId = widget.adUnitId ?? MonetizationService.bannerAdUnitId;
    if (unitId.isEmpty) return;

    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: unitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );

    _bannerAd = banner;
    banner.load();
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EntitlementCubit, EntitlementState>(
      listenWhen: (prev, curr) => prev.isPro != curr.isPro,
      listener: (context, state) {
        if (state.isPro) {
          _disposeBanner();
        } else {
          _loadBanner();
        }
      },
      builder: (context, state) {
        if (state.isPro || !_isLoaded || _bannerAd == null) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          top: false,
          child: SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        );
      },
    );
  }
}
