import 'package:flutter/material.dart';

import 'keep_alive.dart';
import 'loymax_offer_event.dart';
import 'loymax_offers_config.dart';
import 'loymax_offers_controller.dart';
import 'loymax_offers_webview.dart';

/// Carousel of Loymax personal offers.
///
/// Designed for the home screen of the host app. By default it occupies
/// [height] (recommended 240–300 px), but the actual size of the block is
/// driven by the builder for the current phase:
///
/// - **`ready`** — the WebView is laid out with [height].
/// - **`loading`** — renders [loadingBuilder] (if provided) or the default
///   spinner sized at [height]. To collapse the block while loading, return
///   `SizedBox.shrink()`:
///   ```dart
///   loadingBuilder: (_) => const SizedBox.shrink(),
///   ```
/// - **`error`** — same idea for [errorBuilder]. `SizedBox.shrink()` removes
///   the block from the home screen on load failure.
///
/// Transitions between phases are animated by default through [AnimatedSize]
/// (duration — [resizeAnimationDuration], curve — [resizeAnimationCurve]).
/// Set `resizeAnimationDuration: null` to drop the [AnimatedSize] wrapper
/// and resize instantly.
///
/// [config] — endpoint / JS channel (required).
/// [backgroundColor] — background colour of the WebView and the default
/// placeholders; `null` means transparent.
/// [onPhaseChange] — phase observer for analytics, etc.
class LoymaxOffersCarousel extends StatelessWidget {
  const LoymaxOffersCarousel({
    super.key,
    required this.config,
    required this.partner,
    required this.personUid,
    required this.onEvent,
    this.height = 280,
    this.backgroundColor,
    this.loadingBuilder,
    this.errorBuilder,
    this.resizeAnimationDuration = const Duration(milliseconds: 200),
    this.resizeAnimationCurve = Curves.easeInOut,
    this.keepAlive = false,
    this.controller,
    this.onPhaseChange,
  }) : assert(
         resizeAnimationDuration == null ||
             resizeAnimationDuration >= Duration.zero,
         'resizeAnimationDuration must be non-negative or null',
       );

  final LoymaxOffersConfig config;
  final String partner;
  final String personUid;
  final ValueChanged<LoymaxOfferEvent> onEvent;
  final double height;
  final Color? backgroundColor;
  final LoymaxLoadingBuilder? loadingBuilder;
  final LoymaxErrorBuilder? errorBuilder;

  /// Duration of the resize animation between phases.
  /// `null` skips the [AnimatedSize] wrapper and resizes instantly.
  final Duration? resizeAnimationDuration;
  final Curve resizeAnimationCurve;

  /// If `true`, the widget is kept in the tree when it scrolls out of a lazy
  /// parent's viewport (`ListView`, `GridView`, `TabBarView`, etc.) — the
  /// WebView and its loaded content are not recreated.
  ///
  /// Defaults to `false` so memory is not wasted where it is not needed (for
  /// example, a carousel inside a bottom sheet that is reopened frequently
  /// with fresh data). Enable it when the carousel is a permanent block of
  /// the home screen inside a lazy feed.
  final bool keepAlive;

  /// External controller for imperative `reload()` and phase subscription.
  final LoymaxOffersController? controller;

  final ValueChanged<LoymaxOffersPhase>? onPhaseChange;

  @override
  Widget build(BuildContext context) {
    final Widget webView = LoymaxOffersWebView(
      url: buildLoymaxOffersUrl(
        config: config,
        partner: partner,
        personUid: personUid,
        asCarousel: true,
      ),
      onEvent: onEvent,
      config: config,
      eagerGestures: true,
      backgroundColor: backgroundColor,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      onPhaseChange: onPhaseChange,
      readyHeight: height,
      controller: controller,
    );

    Widget result = webView;

    if (resizeAnimationDuration != null) {
      result = AnimatedSize(
        duration: resizeAnimationDuration!,
        alignment: Alignment.topCenter,
        curve: resizeAnimationCurve,
        child: result,
      );
    }

    if (keepAlive) {
      result = LoymaxKeepAlive(child: result);
    }

    return result;
  }
}
