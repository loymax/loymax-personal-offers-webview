# loymax_personal_offers

Flutter widgets for embedding **Loymax personal offers** into a host app
through a WebView. Ships two top-level widgets — a carousel for the home
screen and a full-screen list — plus the bridge that decodes JS events into
strongly-typed Dart objects.

🇷🇺 [Русская версия](README.ru.md)

---

## Features

- `LoymaxOffersCarousel` — horizontal carousel block, ~280 px tall, designed
  to live inside a `ListView` on the home screen.
- `LoymaxOffersView` — full-screen list, intended to be wrapped in a
  `Scaffold` by the host app.
- Three-phase state machine (`loading` / `ready` / `error`) with customisable
  `loadingBuilder` and `errorBuilder` — return `SizedBox.shrink()` to fully
  collapse the block in any phase.
- Optional `AnimatedSize` transitions between phases (tunable duration /
  curve, can be turned off).
- `LoymaxOffersController` for imperative `reload()` and phase observation.
- Cross-platform pull-to-refresh implemented through a JS injection (no
  platform-specific glue required).
- Strongly-typed events: `LoymaxViewAllTap`, `LoymaxCardTap`,
  `LoymaxActivateTap`.
- `keepAlive` flag for embedding inside lazy parents (`ListView`,
  `TabBarView`, `PageView`).

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:loymax_personal_offers/loymax_personal_offers.dart';

const LoymaxOffersConfig kLoymaxConfig = LoymaxOffersConfig(
  baseUrl: '<LOYMAX_OFFERS_BASE_URL>',
);

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.personUid});
  final String personUid;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final LoymaxOffersController _offers = LoymaxOffersController();

  @override
  void dispose() {
    _offers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: () async => _offers.reload(),
        child: ListView(
          children: [
            LoymaxOffersCarousel(
              config: kLoymaxConfig,
              controller: _offers,
              partner: '<partner>',
              personUid: widget.personUid,
              onEvent: (event) {
                if (event is LoymaxViewAllTap || event is LoymaxCardTap) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OffersPage(personUid: widget.personUid),
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class OffersPage extends StatelessWidget {
  const OffersPage({super.key, required this.personUid});
  final String personUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My offers')),
      body: LoymaxOffersView(
        config: kLoymaxConfig,
        partner: '<partner>',
        personUid: personUid,
        pullToRefreshEnabled: true,
        onEvent: (event) {
          if (event is LoymaxActivateTap) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Activated: ${event.offer.name}')),
            );
          }
        },
      ),
    );
  }
}
```

## Configuration

```dart
const LoymaxOffersConfig kLoymaxConfig = LoymaxOffersConfig(
  baseUrl: '<LOYMAX_OFFERS_BASE_URL>',
  // jsBridgeName: 'LoymaxBridge', // override only if Loymax renamed the channel
);
```

The full URL is built as `{baseUrl}/{partner}/?personUid=…&view=row&no-title`.

## Phases and builders

`LoymaxOffersPhase` has three values: `loading`, `ready`, `error`. Both
`LoymaxOffersCarousel` and `LoymaxOffersView` accept:

- `loadingBuilder: (context) => Widget` — placeholder during loading;
  return `SizedBox.shrink()` to hide the block until the WebView is ready.
- `errorBuilder: (context, retry) => Widget` — error view; call `retry()` to
  reload.

The carousel additionally wraps the result in `AnimatedSize` so that size
changes between phases are animated. Pass `resizeAnimationDuration: null`
to disable the wrapper.

See [`example/lib/demo_gallery.dart`](example/lib/demo_gallery.dart) for a
walkthrough of every builder combination.

## Events

The WebView posts JSON messages through the `LoymaxBridge` JS channel.
`LoymaxOfferEvent.tryParse` decodes them into:

| Event | When it fires |
| --- | --- |
| `LoymaxViewAllTap` | User tapped "view all" inside the carousel. |
| `LoymaxCardTap` | User tapped a card (carousel or list). |
| `LoymaxActivateTap` | User activated an offer. Contains `LoymaxOffer`. |
| `LoymaxOtherEvent` | Forward-compat wrapper for any event name the package does not recognise. Carries the raw `name` and the full decoded `payload`. |

`event.source` tells you whether the event came from the `carousel` or the
`list`.

### Forward compatibility

If Loymax adds new bridge events, the package will not throw or drop them —
they are surfaced as `LoymaxOtherEvent` so the host app can opt into
handling them without a package upgrade:

```dart
onEvent: (event) {
  switch (event) {
    case LoymaxActivateTap(:final offer):
      // ...
    case LoymaxOtherEvent(:final name, :final payload):
      if (name == 'some_new_event') {
        // Handle the new event using payload[...] yourself.
      }
    default:
      break;
  }
}
```

## Controller

`LoymaxOffersController` mirrors `ScrollController` / `TextEditingController`:

```dart
late final LoymaxOffersController _offers = LoymaxOffersController();

@override
void dispose() {
  _offers.dispose();
  super.dispose();
}

// Force reload (e.g. on auth change or pull-to-refresh):
_offers.reload();

// Observe phase (e.g. to toggle an AppBar spinner):
ListenableBuilder(
  listenable: _offers,
  builder: (_, __) => Icon(_offers.phase == LoymaxOffersPhase.loading
      ? Icons.hourglass_top
      : Icons.refresh),
);
```

Each controller can be attached to **one** widget at a time.

## Pull-to-refresh

Two options:

1. **Host scroll view.** Wrap the parent `ListView` with `RefreshIndicator`
   and call `controller.reload()` in `onRefresh`. Recommended for the
   carousel embedded on the home screen.
2. **In-WebView (full-screen mode).** Set `pullToRefreshEnabled: true` on
   `LoymaxOffersView`. The package injects JS that detects "pull down at the
   top of the page" and reloads. Customise the indicator via
   `pullToRefreshIndicatorBuilder`.

## `keepAlive`

When the widget lives inside a lazy parent (`ListView`, `TabBarView`,
`PageView`), the parent will unmount it on scroll-off and the WebView
controller will be recreated on the next mount, restarting the load. Pass
`keepAlive: true` to keep the subtree alive. Default is `false`.

## Example app

```bash
cd example
flutter run
```

The example contains two screens:

- **Home (carousel)** — a typical home screen integration.
- **Builder gallery** — six side-by-side variations of `loadingBuilder` /
  `errorBuilder` and the resize animation knob.

## License

MIT © Loymax. See [LICENSE](LICENSE).
