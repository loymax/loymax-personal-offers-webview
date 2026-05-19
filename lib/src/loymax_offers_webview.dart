import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'loymax_offer_event.dart';
import 'loymax_offers_config.dart';
import 'loymax_offers_controller.dart';

/// Builder for the loading placeholder.
typedef LoymaxLoadingBuilder = Widget Function(BuildContext context);

/// Builder for the error screen. [retry] reloads the page.
typedef LoymaxErrorBuilder =
    Widget Function(BuildContext context, VoidCallback retry);

/// Builder for the pull-to-refresh indicator. [progress] is the fraction of
/// the trigger threshold (`0..1`). When `progress >= 1` the user has dragged
/// past the trigger; releasing the gesture invokes `reload()`.
///
/// The widget returned by the builder is placed inside a `Stack` with
/// `alignment: Alignment.topCenter` on top of the WebView — fine-grained
/// positioning (top inset, etc.) is the builder's responsibility.
typedef LoymaxPullToRefreshIndicatorBuilder =
    Widget Function(BuildContext context, double progress);

/// Builds the URL for the personal offers page.
///
/// [config] — configuration (baseUrl, JS channel name).
/// [partner] — short tenant name (for example, `samberi`).
/// [personUid] — customer identifier obtained from `GET /v1.2/user`.
/// [asCarousel] — render in carousel mode (`view=row`).
/// [hideTitle] — hide the page's built-in title (`no-title`).
String buildLoymaxOffersUrl({
  required LoymaxOffersConfig config,
  required String partner,
  required String personUid,
  bool asCarousel = false,
  bool hideTitle = true,
}) {
  final Map<String, String> params = <String, String>{
    'personUid': personUid,
    if (asCarousel) 'view': 'row',
  };

  final String query = <String>[
    ...params.entries.map(
      (MapEntry<String, String> e) => '${e.key}=${e.value}',
    ),
    if (hideTitle) 'no-title',
  ].join('&');

  return '${config.baseUrl}/$partner/?$query';
}

/// Internal widget that wraps a configured [WebViewController].
///
/// Drives three phases: `loading` (the page has not rendered yet), `error`
/// (fatal main-frame load failure) and `ready` (content is visible).
///
/// During `loading` / `error` the appropriate builder is rendered while the
/// WebView itself is kept in the tree via `Visibility(maintainState: true)`,
/// so the controller is not recreated and loading does not restart. The size
/// of the outer container in those phases is determined by the builder — if
/// the builder returns `SizedBox.shrink()`, the widget collapses to 0×0.
/// Wrap [LoymaxOffersWebView] in an external `AnimatedSize` to animate
/// phase-driven size changes.
///
/// Network/domain errors that surface after the first successful load are
/// not part of this state machine — they are drawn by the Loymax page
/// itself.
class LoymaxOffersWebView extends StatefulWidget {
  const LoymaxOffersWebView({
    super.key,
    required this.url,
    required this.onEvent,
    required this.config,
    this.eagerGestures = false,
    this.backgroundColor,
    this.loadingBuilder,
    this.errorBuilder,
    this.onPhaseChange,
    this.readyHeight,
    this.controller,
    this.pullToRefreshEnabled = false,
    this.pullToRefreshIndicatorBuilder,
  });

  final String url;
  final ValueChanged<LoymaxOfferEvent> onEvent;
  final LoymaxOffersConfig config;

  /// Called on every [LoymaxOffersPhase] change. Useful for analytics or
  /// external layout control (for example, collapsing the carousel on the
  /// home screen while content is loading).
  final ValueChanged<LoymaxOffersPhase>? onPhaseChange;

  /// Height the WebView is sized to in the `ready` phase and that the
  /// default loading placeholder receives. `null` means fill the parent
  /// (used by the full-screen view).
  final double? readyHeight;

  /// Forward horizontal/vertical gestures directly to the WebView without
  /// letting the parent intercept them. Enable for a carousel embedded in a
  /// scrolling parent.
  final bool eagerGestures;

  /// Background colour of the WebView (and the loading/error placeholders).
  /// `null` is transparent (the default).
  final Color? backgroundColor;

  final LoymaxLoadingBuilder? loadingBuilder;
  final LoymaxErrorBuilder? errorBuilder;

  /// External controller for imperative `reload()` and phase subscription.
  final LoymaxOffersController? controller;

  /// If `true`, JS is injected into the WebView to catch "pull down" at the
  /// top of the page and invoke `reload()`. An indicator is drawn on top of
  /// the WebView (see [pullToRefreshIndicatorBuilder]).
  ///
  /// Useful for [LoymaxOffersView] (full-screen mode). Not needed in the
  /// carousel — pull-to-refresh is expected to come from the host
  /// `RefreshIndicator` on the parent `ListView`.
  final bool pullToRefreshEnabled;

  /// Custom pull-to-refresh indicator. If omitted, a default round "pill"
  /// with a filling arc is used. The builder is only invoked while
  /// `pullToRefreshEnabled == true` and `progress > 0`.
  final LoymaxPullToRefreshIndicatorBuilder? pullToRefreshIndicatorBuilder;

  @override
  State<LoymaxOffersWebView> createState() => _LoymaxOffersWebViewState();
}

/// Current lifecycle phase of the Loymax WebView.
///
/// - [loading] — the page has not rendered yet (including retries after an
///   error);
/// - [ready] — `onPageFinished` fired and the content is visible;
/// - [error] — fatal main-frame load failure or 4xx/5xx HTTP response.
enum LoymaxOffersPhase { loading, ready, error }

class _LoymaxOffersWebViewState extends State<LoymaxOffersWebView> {
  late final WebViewController _controller;
  LoymaxOffersPhase _phase = LoymaxOffersPhase.loading;

  /// Whether a fatal error has already happened in the current load cycle.
  /// Needed so that an `onPageFinished` arriving afterwards does not flip
  /// the `error` phase back to `ready` — the WebView happily renders the
  /// 404 page body and considers the navigation successfully finished.
  bool _hadFatalError = false;

  /// Pull-to-refresh progress as a fraction of the trigger threshold
  /// (`0..1`). Grows while the user drags the page down; resets on release.
  double _pullProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
    widget.controller?.attach(onReload: _reload);
  }

  @override
  void didUpdateWidget(LoymaxOffersWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(onReload: _reload);
      widget.controller?.updatePhase(_phase);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    super.dispose();
  }

  /// Invoked externally (via [LoymaxOffersController.reload]) or internally
  /// (`_reload` from errorBuilder).
  void _reload() {
    _hadFatalError = false;
    _setPhase(LoymaxOffersPhase.loading);
    _controller.loadRequest(Uri.parse(widget.url));
  }

  WebViewController _buildController() {
    final WebViewController controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor ?? const Color(0x00000000))
      ..addJavaScriptChannel(
        widget.config.jsBridgeName,
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('LoymaxBridge raw: ${message.message}');
          final LoymaxOfferEvent? event = LoymaxOfferEvent.tryParse(
            message.message,
          );
          if (event != null) {
            widget.onEvent(event);
          }
        },
      )
      ..addJavaScriptChannel(
        _kPullToRefreshChannel,
        onMessageReceived:
            (JavaScriptMessage message) =>
                _handlePullToRefreshMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String _) {
            _hadFatalError = false;
            // Early injection — the document is not rendered yet but the JS
            // engine already accepts evaluate. If the document is missing,
            // the script bails out via its own guard.
            controller.runJavaScript(_hideScrollbarsScript);
            if (widget.pullToRefreshEnabled) {
              controller.runJavaScript(_pullToRefreshScript);
            }
            _setPhase(LoymaxOffersPhase.loading);
          },
          onPageFinished: (String _) {
            // Re-inject — if onPageStarted fired before DOM-ready,
            // document.head is definitely available now.
            controller.runJavaScript(_hideScrollbarsScript);
            if (widget.pullToRefreshEnabled) {
              controller.runJavaScript(_pullToRefreshScript);
            }
            if (_hadFatalError) {
              return;
            }
            _setPhase(LoymaxOffersPhase.ready);
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == false) {
              return;
            }
            debugPrint(
              'Loymax WebView error: ${error.errorCode} ${error.description}',
            );
            _hadFatalError = true;
            _setPhase(LoymaxOffersPhase.error);
          },
          onHttpError: (HttpResponseError error) {
            final int? status = error.response?.statusCode;
            if (status == null || status < 400) {
              return;
            }
            if (!_isMainFrameRequest(error.request?.uri)) {
              return;
            }
            debugPrint('Loymax WebView HTTP error: $status');
            _hadFatalError = true;
            _setPhase(LoymaxOffersPhase.error);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    _disableNativeScrollbars(controller);

    return controller;
  }

  Future<void> _disableNativeScrollbars(WebViewController controller) async {
    if (await controller.supportsSetScrollBarsEnabled()) {
      await controller.setHorizontalScrollBarEnabled(false);
      await controller.setVerticalScrollBarEnabled(false);
    }
  }

  void _setPhase(LoymaxOffersPhase phase) {
    if (!mounted || _phase == phase) {
      return;
    }
    setState(() => _phase = phase);
    widget.controller?.updatePhase(phase);
    widget.onPhaseChange?.call(phase);
  }

  void _handlePullToRefreshMessage(String raw) {
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      switch (json['type']) {
        case 'progress':
          final double dy = (json['dy'] as num?)?.toDouble() ?? 0;
          final double next = (dy / _kPullToRefreshThreshold).clamp(0.0, 1.0);
          if (next == _pullProgress || !mounted) {
            return;
          }
          setState(() => _pullProgress = next);
        case 'trigger':
          if (!mounted) {
            return;
          }
          setState(() => _pullProgress = 0);
          _reload();
        case 'cancel':
          if (!mounted || _pullProgress == 0) {
            return;
          }
          setState(() => _pullProgress = 0);
      }
    } on FormatException catch (e) {
      debugPrint('LoymaxPullToRefresh parse error: $e');
    }
  }

  /// `HttpResponseError` is emitted for both the main resource (the page)
  /// and sub-resources (images, fonts, scripts). The platform's
  /// `WebResourceRequest` does not expose `isForMainFrame`, so we identify
  /// the main frame by URL — if host+path matches what we passed to
  /// `loadRequest`, it is the main frame; otherwise it is a third-party
  /// resource that the page can handle on its own and we should not tear
  /// the block down.
  bool _isMainFrameRequest(Uri? requestUri) {
    if (requestUri == null) {
      return true;
    }
    final Uri loaded = Uri.parse(widget.url);

    return requestUri.host == loaded.host && requestUri.path == loaded.path;
  }

  @override
  Widget build(BuildContext context) {
    final Widget webView = WebViewWidget(
      controller: _controller,
      gestureRecognizers:
          widget.eagerGestures
              ? <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              }
              : const <Factory<OneSequenceGestureRecognizer>>{},
    );

    final Widget sizedWebView =
        widget.readyHeight != null
            ? SizedBox(height: widget.readyHeight, child: webView)
            : webView;

    switch (_phase) {
      case LoymaxOffersPhase.ready:
        return _wrapWithPullIndicator(sizedWebView);
      case LoymaxOffersPhase.error:
        // The WebView is taken out of the tree — the page already failed,
        // and on retry `controller.loadRequest` starts over. Preserving the
        // platform view across `ListView`s and navigation is the
        // integrator's job (KeepAlive).
        return widget.errorBuilder?.call(context, _reload) ??
            SizedBox(
              height: widget.readyHeight,
              child: _DefaultLoymaxError(
                onRetry: _reload,
                backgroundColor: widget.backgroundColor,
              ),
            );
      case LoymaxOffersPhase.loading:
        // Keep the WebView in the tree (hidden, taking no space) so that
        // loading continues behind the placeholder.
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            Visibility(
              visible: false,
              maintainState: true,
              maintainAnimation: true,
              child: sizedWebView,
            ),
            widget.loadingBuilder?.call(context) ??
                SizedBox(
                  height: widget.readyHeight,
                  child: _DefaultLoymaxLoading(
                    backgroundColor: widget.backgroundColor,
                  ),
                ),
          ],
        );
    }
  }

  /// Overlays a Material "pull to refresh" indicator on top of the WebView
  /// when pull-to-refresh is enabled. The indicator is only visible while
  /// `_pullProgress > 0` (the user is dragging the page down) — on trigger
  /// it resets and is replaced by the regular loading placeholder via a
  /// phase change.
  Widget _wrapWithPullIndicator(Widget webView) {
    if (!widget.pullToRefreshEnabled) {
      return webView;
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        webView,
        if (_pullProgress > 0)
          (widget.pullToRefreshIndicatorBuilder ??
                  _defaultPullToRefreshIndicatorBuilder)
              .call(context, _pullProgress),
      ],
    );
  }
}

Widget _defaultPullToRefreshIndicatorBuilder(
  BuildContext context,
  double progress,
) {
  return Padding(
    padding: const EdgeInsets.only(top: 24),
    child: _PullToRefreshIndicator(progress: progress),
  );
}

/// Circular pull-to-refresh indicator. Unlike `RefreshProgressIndicator` it
/// does not spin as value grows — it just fills its arc. Visibly "rises" up
/// from below the top edge as progress increases.
class _PullToRefreshIndicator extends StatelessWidget {
  const _PullToRefreshIndicator({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      type: MaterialType.circle,
      color: theme.colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2.5,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _DefaultLoymaxLoading extends StatelessWidget {
  const _DefaultLoymaxLoading({this.backgroundColor});

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DefaultLoymaxError extends StatelessWidget {
  const _DefaultLoymaxError({required this.onRetry, this.backgroundColor});

  final VoidCallback onRetry;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Failed to load personal offers',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Name of the JS channel used for pull-to-refresh messages.
const String _kPullToRefreshChannel = 'LoymaxPullToRefresh';

/// Pull-down threshold in pixels at which refresh triggers.
const double _kPullToRefreshThreshold = 80;

/// "Dead zone" in pixels — short random touches and micro finger drifts
/// must not light up the indicator.
const double _kPullToRefreshDeadzone = 16;

/// Rubber-band multiplier: the effective travel used for progress is
/// `(raw_dy − deadzone) * factor`. ~0.5 mimics the feel of native iOS
/// pull-to-refresh where the page recedes with a bit of drag.
const double _kPullToRefreshDampening = 0.5;

/// JS injected into the WebView page to detect the pull-down gesture.
///
/// Listens to `touchstart` / `touchmove` / `touchend` on the document. If
/// the user starts the gesture at `scrollY == 0` and pulls down, it sends
/// `progress` with the effective `dy` (after deadzone and dampening). On
/// release above the threshold — `trigger`; otherwise — `cancel`.
///
/// Listeners are passive (`{passive: true}`), so the native bounce /
/// overscroll behaviour is preserved. The `__loymaxPullToRefreshInstalled`
/// guard protects against double installation if the script is injected
/// twice on the same page.
///
/// Messages are throttled by `dy >= 4 px` deltas to avoid hammering the
/// Dart side on every sub-pixel.
const String _pullToRefreshScript = '''
(function() {
  if (window.__loymaxPullToRefreshInstalled) return;
  window.__loymaxPullToRefreshInstalled = true;

  var THRESHOLD = $_kPullToRefreshThreshold;
  var DEADZONE = $_kPullToRefreshDeadzone;
  var DAMPING = $_kPullToRefreshDampening;
  var THROTTLE = 4;

  var startY = null;
  var lastEffective = 0;

  function effective(rawDy) {
    var d = rawDy - DEADZONE;
    if (d <= 0) return 0;
    return d * DAMPING;
  }

  document.addEventListener('touchstart', function (e) {
    if (window.scrollY > 0) { startY = null; return; }
    startY = e.touches[0].clientY;
    lastEffective = 0;
  }, { passive: true });

  document.addEventListener('touchmove', function (e) {
    if (startY === null) return;
    if (window.scrollY > 0) {
      startY = null;
      LoymaxPullToRefresh.postMessage(JSON.stringify({ type: 'cancel' }));
      return;
    }
    var dy = effective(e.touches[0].clientY - startY);
    if (Math.abs(dy - lastEffective) < THROTTLE) return;
    lastEffective = dy;
    LoymaxPullToRefresh.postMessage(JSON.stringify({ type: 'progress', dy: dy }));
  }, { passive: true });

  function finish(e) {
    if (startY === null) return;
    var touch = (e.changedTouches && e.changedTouches[0]) || null;
    var dy = touch ? effective(touch.clientY - startY) : 0;
    startY = null;
    lastEffective = 0;
    if (dy >= THRESHOLD) {
      LoymaxPullToRefresh.postMessage(JSON.stringify({ type: 'trigger' }));
    } else {
      LoymaxPullToRefresh.postMessage(JSON.stringify({ type: 'cancel' }));
    }
  }
  document.addEventListener('touchend', finish, { passive: true });
  document.addEventListener('touchcancel', finish, { passive: true });
})();
''';

const String _hideScrollbarsScript = '''
(function() {
  var STYLE_ID = '__loymaxHideScrollbars';
  function inject(target) {
    if (!target || target.querySelector('#' + STYLE_ID)) return;
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.innerHTML =
      '::-webkit-scrollbar { width: 0 !important; height: 0 !important; display: none !important; } ' +
      'html, body, * { scrollbar-width: none !important; -ms-overflow-style: none !important; }';
    target.appendChild(style);
  }
  if (document.head) {
    inject(document.head);
  } else {
    document.addEventListener('DOMContentLoaded', function () {
      inject(document.head);
    });
  }
})();
''';
