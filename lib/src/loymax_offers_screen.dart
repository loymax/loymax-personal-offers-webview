import 'package:flutter/material.dart';

import 'keep_alive.dart';
import 'loymax_offer_event.dart';
import 'loymax_offers_config.dart';
import 'loymax_offers_controller.dart';
import 'loymax_offers_webview.dart';

/// Full-screen list of Loymax personal offers.
///
/// Opened from the carousel in response to [LoymaxViewAllTap] /
/// [LoymaxCardTap] events. The widget has no built-in AppBar — wrap it in a
/// `Scaffold` on the application side.
///
/// [config] — endpoint / JS channel (required).
/// [backgroundColor] — background colour of the WebView and placeholders;
/// `null` means transparent.
/// [loadingBuilder] / [errorBuilder] — customise the states shown while the
/// page is loading and on fatal load errors.
///
/// Example:
/// ```dart
/// Scaffold(
///   appBar: AppBar(title: const Text('My offers')),
///   body: LoymaxOffersView(
///     config: kLoymaxConfig,
///     partner: 'samberi',
///     personUid: user.personUid,
///     onEvent: (event) {
///       if (event is LoymaxActivateTap) {
///         showSnack('Activated: ${event.offer.name}');
///       }
///     },
///   ),
/// )
/// ```
class LoymaxOffersView extends StatelessWidget {
  const LoymaxOffersView({
    super.key,
    required this.config,
    required this.partner,
    required this.personUid,
    required this.onEvent,
    this.backgroundColor,
    this.loadingBuilder,
    this.errorBuilder,
    this.keepAlive = false,
    this.controller,
    this.pullToRefreshEnabled = false,
    this.pullToRefreshIndicatorBuilder,
  });

  final LoymaxOffersConfig config;
  final String partner;
  final String personUid;
  final ValueChanged<LoymaxOfferEvent> onEvent;
  final Color? backgroundColor;
  final LoymaxLoadingBuilder? loadingBuilder;
  final LoymaxErrorBuilder? errorBuilder;

  /// If `true`, the widget is kept in the tree when it scrolls out of a lazy
  /// parent's viewport (`TabBarView`, `PageView`, etc.). Defaults to `false`.
  final bool keepAlive;

  /// External controller for imperative `reload()` and phase subscription.
  final LoymaxOffersController? controller;

  /// Enable pull-to-refresh inside the WebView. Implemented via a JS
  /// injection, works cross-platform. An indicator is drawn on top of the
  /// WebView (see [pullToRefreshIndicatorBuilder]).
  final bool pullToRefreshEnabled;

  /// Custom pull-to-refresh indicator. If omitted, the default indicator is
  /// used. See the docs on [LoymaxPullToRefreshIndicatorBuilder].
  final LoymaxPullToRefreshIndicatorBuilder? pullToRefreshIndicatorBuilder;

  @override
  Widget build(BuildContext context) {
    final Widget view = LoymaxOffersWebView(
      url: buildLoymaxOffersUrl(
        config: config,
        partner: partner,
        personUid: personUid,
      ),
      onEvent: onEvent,
      config: config,
      backgroundColor: backgroundColor,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      controller: controller,
      pullToRefreshEnabled: pullToRefreshEnabled,
      pullToRefreshIndicatorBuilder: pullToRefreshIndicatorBuilder,
    );

    return keepAlive ? LoymaxKeepAlive(child: view) : view;
  }
}
