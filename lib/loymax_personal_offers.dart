/// Widgets for embedding Loymax personal offers via a WebView.
///
/// See `Loymax · WebView · Integration Guide` (section 4 — carousel,
/// section 5 — full-screen view, section 6 — events).
library;

export 'src/loymax_offer.dart';
export 'src/loymax_offer_event.dart';
export 'src/loymax_offers_carousel.dart';
export 'src/loymax_offers_config.dart';
export 'src/loymax_offers_controller.dart';
export 'src/loymax_offers_screen.dart' show LoymaxOffersView;
export 'src/loymax_offers_webview.dart'
    show
        LoymaxErrorBuilder,
        LoymaxLoadingBuilder,
        LoymaxOffersPhase,
        LoymaxPullToRefreshIndicatorBuilder,
        buildLoymaxOffersUrl;
