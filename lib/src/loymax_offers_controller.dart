import 'package:flutter/foundation.dart';

import 'loymax_offers_webview.dart' show LoymaxOffersPhase;

/// Imperative controller for the Loymax personal offers widgets.
///
/// Lets you force a WebView reload (pull-to-refresh, auth changes, cache
/// invalidation, etc.) and subscribe to the current phase via the
/// `ChangeNotifier` interface.
///
/// Lifecycle mirrors [TextEditingController] / [ScrollController]: create it
/// in `State.initState`, pass it to the widget, and dispose it in
/// `State.dispose` via [dispose].
///
/// ```dart
/// class _HomeState extends State<HomePage> {
///   late final LoymaxOffersController _offers;
///
///   @override
///   void initState() {
///     super.initState();
///     _offers = LoymaxOffersController();
///   }
///
///   @override
///   void dispose() {
///     _offers.dispose();
///     super.dispose();
///   }
///
///   Future<void> _refresh() async {
///     _offers.reload();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return RefreshIndicator(
///       onRefresh: _refresh,
///       child: ListView(children: [
///         LoymaxOffersCarousel(
///           controller: _offers,
///           ...,
///         ),
///       ]),
///     );
///   }
/// }
/// ```
class LoymaxOffersController extends ChangeNotifier {
  VoidCallback? _reloadHandler;
  LoymaxOffersPhase _phase = LoymaxOffersPhase.loading;

  /// Current phase of the attached widget. Before attach and after detach
  /// it returns [LoymaxOffersPhase.loading].
  LoymaxOffersPhase get phase => _phase;

  /// Whether the controller is currently attached to a widget.
  bool get isAttached => _reloadHandler != null;

  /// Reload the WebView with the same URL. Resets the phase to `loading`
  /// and re-issues `loadRequest`. If the controller is not attached to a
  /// widget the call is silently ignored (with an assert in debug mode).
  void reload() {
    assert(
      _reloadHandler != null,
      'LoymaxOffersController.reload() was called while the controller is '
      'not attached to a widget (the widget has not been built yet or has '
      'already been unmounted).',
    );
    _reloadHandler?.call();
  }

  // --- Implementation detail. Only invoked by the package widgets. ---
  // Mirrors `ScrollController.attach()` — these methods are technically
  // public, but application code should not call them.

  /// @nodoc
  void attach({required VoidCallback onReload}) {
    assert(
      _reloadHandler == null,
      'LoymaxOffersController is already attached to another widget. Use a '
      'separate controller per widget instance.',
    );
    _reloadHandler = onReload;
  }

  /// @nodoc
  void detach() {
    _reloadHandler = null;
  }

  /// @nodoc
  void updatePhase(LoymaxOffersPhase phase) {
    if (_phase == phase) {
      return;
    }
    _phase = phase;
    notifyListeners();
  }
}
