import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import '../services/ads.dart';
import '../services/progress.dart';

/// Bottom banner; renders nothing for premium users or while not loaded.
class BannerBox extends StatefulWidget {
  const BannerBox({super.key});
  @override
  State<BannerBox> createState() => _BannerBoxState();
}

class _BannerBoxState extends State<BannerBox> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final premium = context.read<AppState>().premium;
    if (!premium) {
      _ad = AdService.instance.createBanner(
        onLoaded: (_) => setState(() => _loaded = true),
        onFailed: (ad, e) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      );
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<AppState>().premium;
    if (premium || _ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
