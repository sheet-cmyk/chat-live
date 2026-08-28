import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../home/presentation/widgets/promo_banner.dart';
import '../../data/models/banner_model.dart';
import '../providers/banner_provider.dart';

/// Replaces the static PromoBanner. Streams banners from Firebase,
/// auto-rotates per each banner's durationSeconds, supports images
/// and YouTube videos. Falls back to the static PromoBanner while
/// loading or when Firebase has no active banners.
class FirebaseBanner extends ConsumerStatefulWidget {
  const FirebaseBanner({super.key});

  @override
  ConsumerState<FirebaseBanner> createState() => _FirebaseBannerState();
}

class _FirebaseBannerState extends ConsumerState<FirebaseBanner> {
  int _currentIndex = 0;
  Timer? _timer;
  bool _timerStarted = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Recursive single-shot timer: fires after current banner's duration,
  // advances index, then re-schedules for the new current banner.
  void _schedule(List<BannerModel> banners) {
    _timer?.cancel();
    if (!mounted || banners.isEmpty) return;
    final idx = _currentIndex.clamp(0, banners.length - 1);
    final secs = banners[idx].durationSeconds.clamp(1, 120);
    _timer = Timer(Duration(seconds: secs), () {
      if (!mounted) return;
      setState(() => _currentIndex = (_currentIndex + 1) % banners.length);
      _schedule(banners);
    });
  }

  @override
  Widget build(BuildContext context) {
    // React to real-time Firebase changes (e.g., admin adds/removes a banner).
    ref.listen<AsyncValue<List<BannerModel>>>(activeBannersProvider, (_, next) {
      final banners = next.valueOrNull;
      if (banners == null || banners.isEmpty) {
        _timer?.cancel();
        return;
      }
      if (_currentIndex >= banners.length) _currentIndex = 0;
      _schedule(banners);
    });

    final bannersAsync = ref.watch(activeBannersProvider);

    return bannersAsync.when(
      loading: () => const PromoBanner(),
      error: (_, __) => const PromoBanner(),
      data: (banners) {
        if (banners.isEmpty) return const PromoBanner();

        // Start timer once after first successful data load.
        if (!_timerStarted) {
          _timerStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _schedule(banners);
          });
        }

        final idx = _currentIndex.clamp(0, banners.length - 1);
        final current = banners[idx];

        return Column(
          children: [
            SizedBox(
              height: 160,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
                  child: child,
                ),
                child: _BannerCard(
                  key: ValueKey('${current.id}_$idx'),
                  banner: current,
                ),
              ),
            ),
            if (banners.length > 1) ...[
              const SizedBox(height: 10),
              _DotsIndicator(count: banners.length, current: idx),
            ],
          ],
        );
      },
    );
  }
}

// ── Banner card dispatcher ─────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  const _BannerCard({super.key, required this.banner});
  final BannerModel banner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: banner.type == 'youtube' &&
                (banner.youtubeVideoId?.isNotEmpty ?? false)
            ? _YoutubeBannerCard(videoId: banner.youtubeVideoId!)
            : _ImageBannerCard(imageUrl: banner.imageUrl),
      ),
    );
  }
}

// ── Image banner ───────────────────────────────────────────────────────────

class _ImageBannerCard extends StatelessWidget {
  const _ImageBannerCard({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _Placeholder();
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 160,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: const Color(0xFFF0F2FF),
        highlightColor: Colors.white,
        child: Container(color: const Color(0xFFF0F2FF)),
      ),
      errorWidget: (_, __, ___) => _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: const BoxDecoration(gradient: AppColors.heroBannerGradient),
      child: const Center(
        child: Icon(Icons.image_rounded, size: 48, color: Color(0xFFDDD6FE)),
      ),
    );
  }
}

// ── YouTube banner via WebView ─────────────────────────────────────────────
// Uses webview_flutter (already in project) to embed the YouTube IFrame API.
// No extra dependency needed — avoids flutter_inappwebview's AGP conflict.

class _YoutubeBannerCard extends StatefulWidget {
  const _YoutubeBannerCard({required this.videoId});
  final String videoId;

  @override
  State<_YoutubeBannerCard> createState() => _YoutubeBannerCardState();
}

class _YoutubeBannerCardState extends State<_YoutubeBannerCard> {
  late WebViewController _controller;

  // YouTube embed with autoplay + mute (mute required for browser autoplay policy).
  // loop=1 + playlist= repeats the single video indefinitely.
  String get _embedUrl =>
      'https://www.youtube.com/embed/${widget.videoId}'
      '?autoplay=1&mute=1&loop=1&playlist=${widget.videoId}'
      '&controls=0&showinfo=0&rel=0&modestbranding=1&playsinline=1';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse(_embedUrl));
  }

  // WebViewController has no explicit dispose; WebView cleanup happens
  // automatically when the widget is removed from the tree.

  @override
  Widget build(BuildContext context) {
    // FittedBox + SizedBox scales the 16:9 WebView to cover the 160 px banner.
    // IgnorePointer prevents accidental fullscreen/pause taps from the user.
    return IgnorePointer(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: 320,
          height: 180,
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}

// ── Animated dots indicator ────────────────────────────────────────────────

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 28 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : const Color(0xFFDDD6FE),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
