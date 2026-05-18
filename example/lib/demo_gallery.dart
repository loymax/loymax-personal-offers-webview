import 'package:flutter/material.dart';
import 'package:loymax_personal_offers/loymax_personal_offers.dart';

import 'demo_config.dart';

/// Gallery of loadingBuilder / errorBuilder variations.
class DemoGalleryPage extends StatelessWidget {
  const DemoGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loymax · builder gallery')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: <Widget>[
          _Variant(
            title: '1. Default',
            hint:
                'No builders — the default spinner is shown while loading and '
                'the default error screen on failure.',
            child: LoymaxOffersCarousel(
              keepAlive: true,
              config: kLoymaxConfig,
              partner: kPartner,
              personUid: kPersonUid,
              backgroundColor: Theme.of(context).colorScheme.surface,
              onEvent: (LoymaxOfferEvent event) => _onEvent(context, event),
            ),
          ),
          _Variant(
            title: '2. Skeleton placeholder',
            hint: 'Custom shimmer instead of the spinner, same 280 height.',
            child: LoymaxOffersCarousel(
              keepAlive: true,
              config: kLoymaxConfig,
              partner: kPartner,
              personUid: kPersonUid,
              loadingBuilder: (_) => const _SkeletonCarousel(),
              onEvent: (LoymaxOfferEvent event) => _onEvent(context, event),
            ),
          ),
          _Variant(
            title: '3. Hidden while loading',
            hint:
                'loadingBuilder returns SizedBox.shrink() — the block only '
                'appears when the WebView is ready. AnimatedSize smoothly '
                'expands the slot.',
            child: LoymaxOffersCarousel(
              keepAlive: true,
              config: kLoymaxConfig,
              partner: kPartner,
              personUid: kPersonUid,
              loadingBuilder: (_) => const SizedBox.shrink(),
              onEvent: (LoymaxOfferEvent event) => _onEvent(context, event),
            ),
          ),
          _Variant(
            title: '4. Compact error',
            hint:
                'Deliberately broken baseUrl. Custom errorBuilder — 80 px '
                'inline banner with an icon and a "Retry" button.',
            child: LoymaxOffersCarousel(
              keepAlive: true,
              config: kBrokenLoymaxConfig,
              partner: kPartner,
              personUid: kPersonUid,
              errorBuilder:
                  (_, VoidCallback retry) => _InlineErrorBanner(onRetry: retry),
              onEvent: (LoymaxOfferEvent event) => _onEvent(context, event),
            ),
          ),
          _Variant(
            title: '5. Hidden on error',
            hint:
                'errorBuilder returns SizedBox.shrink() — the block disappears '
                'from the home screen when the WebView fails to load. No '
                'retry UI is shown.',
            child: LoymaxOffersCarousel(
              keepAlive: true,
              config: kBrokenLoymaxConfig,
              partner: kPartner,
              personUid: kPersonUid,
              errorBuilder: (_, _) => const SizedBox.shrink(),
              onEvent: (LoymaxOfferEvent event) => _onEvent(context, event),
            ),
          ),
          _Variant(
            title: '6. No resize animation',
            hint:
                'resizeAnimationDuration: null — the AnimatedSize wrapper is '
                'omitted, transitions are instant.',
            child: LoymaxOffersCarousel(
              keepAlive: true,
              config: kLoymaxConfig,
              partner: kPartner,
              personUid: kPersonUid,
              loadingBuilder: (_) => const SizedBox.shrink(),
              resizeAnimationDuration: null,
              onEvent: (LoymaxOfferEvent event) => _onEvent(context, event),
            ),
          ),
          const SizedBox(height: 400),
        ],
      ),
    );
  }

  void _onEvent(BuildContext context, LoymaxOfferEvent event) {
    switch (event) {
      case LoymaxViewAllTap():
      case LoymaxCardTap():
        // The gallery does not open the full-screen view — the focus is on
        // carousel states.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Card / "View all" tap')));
      case LoymaxActivateTap(offer: final LoymaxOffer offer):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Activated: ${offer.name}')));
      case LoymaxOtherEvent(name: final String name):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Other event: $name')));
    }
  }
}

class _Variant extends StatelessWidget {
  const _Variant({
    required this.title,
    required this.hint,
    required this.child,
  });

  final String title;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SkeletonCarousel extends StatefulWidget {
  const _SkeletonCarousel();

  @override
  State<_SkeletonCarousel> createState() => _SkeletonCarouselState();
}

class _SkeletonCarouselState extends State<_SkeletonCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) {
          final Color base = Theme.of(context).colorScheme.surfaceContainerHigh;
          final Color highlight =
              Theme.of(context).colorScheme.surfaceContainerHighest;
          final Color color = Color.lerp(base, highlight, _controller.value)!;

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: 4,
            itemBuilder:
                (BuildContext context, int _) => _SkeletonCard(color: color),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
          );
        },
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _SkeletonLine(width: double.infinity),
            const SizedBox(height: 6),
            _SkeletonLine(width: 60),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to load offers',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
