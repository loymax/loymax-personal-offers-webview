# Changelog

## 1.0.0

- Initial release as `loymax_personal_offers` package.
- Extracted carousel/full-screen widgets, controller, config and event types
  from the original `loymax_webview_demo` app.
- All internal comments and default UI strings translated to English.
- Demo moved to `example/`.
- Added `LoymaxOtherEvent` for forward compatibility: unknown bridge events
  are surfaced with their raw name and payload instead of being dropped.
- Added MIT LICENSE.
