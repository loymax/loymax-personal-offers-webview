/// Configuration for the Loymax personal offers widgets.
///
/// Holds endpoints that are specific to the environment (prod / staging /
/// partner test CDN). Both `LoymaxOffersCarousel` and `LoymaxOffersView`
/// require this struct via their `config` parameter — there is no default
/// URL; the integrator must pick the environment explicitly.
class LoymaxOffersConfig {
  const LoymaxOffersConfig({
    required this.baseUrl,
    this.jsBridgeName = _kDefaultJsBridgeName,
  });

  /// Base URL without trailing slash and without the `partner` segment.
  ///
  /// The full URL is built as
  /// `{baseUrl}/{partner}/?personUid=…&view=row&no-title`.
  final String baseUrl;

  /// Name of the JS channel the web page posts events into via
  /// `LoymaxBridge.postMessage(...)`. Defaults to `LoymaxBridge`.
  /// Only worth changing if Loymax has renamed the channel on their side.
  final String jsBridgeName;

  LoymaxOffersConfig copyWith({String? baseUrl, String? jsBridgeName}) =>
      LoymaxOffersConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        jsBridgeName: jsBridgeName ?? this.jsBridgeName,
      );
}

const String _kDefaultJsBridgeName = 'LoymaxBridge';
