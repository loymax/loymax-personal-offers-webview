# loymax_personal_offers

Flutter-виджеты для встраивания **персональных предложений Loymax** в
хост-приложение через WebView. Пакет даёт два публичных виджета — карусель
для главного экрана и полноэкранный список — а также мост, который
декодирует JS-события Loymax в типизированные Dart-объекты.

🇬🇧 [English version](README.md)

---

## Возможности

- `LoymaxOffersCarousel` — горизонтальная карусель ~280 px, рассчитана на
  размещение внутри `ListView` главного экрана.
- `LoymaxOffersView` — полноэкранный список, оборачивайте в `Scaffold` на
  стороне приложения.
- Машина состояний из четырёх фаз (`loading` / `ready` / `error` /
  `empty`) с кастомными `loadingBuilder`, `errorBuilder` и `emptyBuilder` —
  вернув `SizedBox.shrink()`, можно полностью скрыть блок в любой фазе.
- Опциональные `AnimatedSize`-переходы между фазами (длительность / кривая
  настраиваются, обёртку можно отключить).
- `LoymaxOffersController` для императивного `reload()` и наблюдения за
  фазой.
- Кроссплатформенный pull-to-refresh через JS-инъекцию (без платформенного
  кода).
- Типизированные события: `LoymaxViewAllTap`, `LoymaxCardTap`,
  `LoymaxActivateTap`, `LoymaxNoContent`.
- Флаг `keepAlive` для встраивания в ленивых родителей (`ListView`,
  `TabBarView`, `PageView`).
- Переключатель `hideTitle` на обоих виджетах — оставить или скрыть
  встроенный заголовок страницы Loymax (по умолчанию скрыт).

## Быстрый старт

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
      appBar: AppBar(title: const Text('Главная')),
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
      appBar: AppBar(title: const Text('Мои предложения')),
      body: LoymaxOffersView(
        config: kLoymaxConfig,
        partner: '<partner>',
        personUid: personUid,
        pullToRefreshEnabled: true,
        onEvent: (event) {
          if (event is LoymaxActivateTap) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Активировано: ${event.offer.name}')),
            );
          }
        },
      ),
    );
  }
}
```

## Конфигурация

```dart
const LoymaxOffersConfig kLoymaxConfig = LoymaxOffersConfig(
  baseUrl: '<LOYMAX_OFFERS_BASE_URL>',
  // jsBridgeName: 'LoymaxBridge', // менять только если Loymax переименовал канал
);
```

Полный URL собирается как `{baseUrl}/{partner}/?personUid=…&view=row&no-title`.
Передайте `hideTitle: false` в виджет, если нужно оставить встроенный
заголовок страницы (флаг `no-title` тогда из query убирается).

## Фазы и builder'ы

`LoymaxOffersPhase` принимает значения `loading`, `ready`, `error`,
`empty`. И `LoymaxOffersCarousel`, и `LoymaxOffersView` принимают:

- `loadingBuilder: (context) => Widget` — плейсхолдер во время загрузки;
  верните `SizedBox.shrink()`, чтобы прятать блок до готовности WebView.
- `errorBuilder: (context, retry) => Widget` — экран ошибки; вызов `retry()`
  перезагружает страницу.
- `emptyBuilder: (context) => Widget` — показывается, когда страница
  присылает `no_content` (загрузилась, но предложений для пользователя
  нет). Если `null`, WebView остаётся видимым со своим пустым состоянием;
  верните `SizedBox.shrink()`, чтобы схлопнуть блок.

Карусель дополнительно оборачивает результат в `AnimatedSize`, чтобы смена
размера между фазами анимировалась. `resizeAnimationDuration: null`
отключает обёртку.

Все варианты builder'ов вживую — в
[`example/lib/demo_gallery.dart`](example/lib/demo_gallery.dart).

## События

WebView шлёт JSON-сообщения через JS-канал `LoymaxBridge`.
`LoymaxOfferEvent.tryParse` декодирует их:

| Событие | Когда срабатывает |
| --- | --- |
| `LoymaxViewAllTap` | Тап по «смотреть все» в карусели. |
| `LoymaxCardTap` | Тап по карточке (карусель или список). |
| `LoymaxActivateTap` | Активация предложения. Содержит `LoymaxOffer`. |
| `LoymaxNoContent` | Страница загрузилась, но предложений нет. Параллельно переводит виджет в `LoymaxOffersPhase.empty`. |
| `LoymaxOtherEvent` | Forward-compat обёртка для неизвестных пакету событий. Содержит сырое `name` и полный декодированный `payload`. |

`event.source` различает источник: `carousel` или `list`.

### Прямая совместимость

Если Loymax добавит новые события моста, пакет не упадёт и не «съест» их —
они придут как `LoymaxOtherEvent`, и приложение может обрабатывать их без
обновления пакета:

```dart
onEvent: (event) {
  switch (event) {
    case LoymaxActivateTap(:final offer):
      // ...
    case LoymaxOtherEvent(:final name, :final payload):
      if (name == 'some_new_event') {
        // Обрабатываем новое событие, читая поля из payload.
      }
    default:
      break;
  }
}
```

## Контроллер

`LoymaxOffersController` живёт по аналогии со `ScrollController` /
`TextEditingController`:

```dart
late final LoymaxOffersController _offers = LoymaxOffersController();

@override
void dispose() {
  _offers.dispose();
  super.dispose();
}

// Перезагрузка вручную (смена авторизации, pull-to-refresh и т.п.):
_offers.reload();

// Подписка на фазу (например, спиннер в AppBar):
ListenableBuilder(
  listenable: _offers,
  builder: (_, __) => Icon(_offers.phase == LoymaxOffersPhase.loading
      ? Icons.hourglass_top
      : Icons.refresh),
);
```

Один контроллер можно прикрепить к **одному** виджету одновременно.

## Pull-to-refresh

Два варианта:

1. **Внешний скролл.** Оберните родительский `ListView` в
   `RefreshIndicator` и вызовите `controller.reload()` из `onRefresh`.
   Рекомендуется для карусели на главном экране.
2. **Внутри WebView (полноэкранный режим).** Установите
   `pullToRefreshEnabled: true` на `LoymaxOffersView`. Пакет инжектит JS,
   который ловит «потяните вниз» в верхней части страницы и перезагружает
   её. Индикатор можно подменить через `pullToRefreshIndicatorBuilder`.

## `keepAlive`

Если виджет находится внутри ленивого родителя (`ListView`, `TabBarView`,
`PageView`), при уходе за вьюпорт родитель его размонтирует, а на следующем
монтировании контроллер WebView пересоздастся, и загрузка пойдёт заново.
`keepAlive: true` оставляет поддерево живым. По умолчанию — `false`.

## Пример

```bash
cd example
flutter run
```

В примере два экрана:

- **Home (carousel)** — типовая интеграция на главном экране.
- **Builder gallery** — восемь вариантов `loadingBuilder` / `errorBuilder` /
  `emptyBuilder` рядом + переключатель анимации смены размера.

## Лицензия

MIT © Loymax. См. [LICENSE](LICENSE).
