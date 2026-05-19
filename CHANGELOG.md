# Changelog

## 1.0.2

- Removed stale root `ios/` directory (leftover from the original app
  scaffold). Only generated/ephemeral Xcode artifacts lived there and were
  shipped in the published archive by mistake.

## 1.0.1

- Removed direct dependency on `webview_flutter_android`; native scrollbars are
  now disabled via the cross-platform `WebViewController.setHorizontalScrollBarEnabled`
  / `setVerticalScrollBarEnabled` API (guarded by `supportsSetScrollBarsEnabled`).

## 1.0.0

- Initial release as `loymax_personal_offers` package.
- Extracted carousel/full-screen widgets, controller, config and event types
  from the original `loymax_webview_demo` app.
- All internal comments and default UI strings translated to English.
- Demo moved to `example/`.
- Added `LoymaxOtherEvent` for forward compatibility: unknown bridge events
  are surfaced with their raw name and payload instead of being dropped.
- Added MIT LICENSE.
