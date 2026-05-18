import 'dart:convert';

import 'loymax_offer.dart';

/// Events that the Loymax WebView dispatches to the host app via the
/// `LoymaxBridge` JS channel.
///
/// See section 6 of the integration guide.
///
/// Forward compatibility: any event the package does not recognise is
/// surfaced as [LoymaxOtherEvent] with the raw payload, so the host app can
/// handle newly introduced events without waiting for a package update.
/// `tryParse` only returns `null` when the message is not valid JSON or its
/// root is not a JSON object.
sealed class LoymaxOfferEvent {
  const LoymaxOfferEvent({required this.source});

  /// Parses raw JSON received from `LoymaxBridge.postMessage(...)`.
  ///
  /// Returns one of the typed events for known `event` names, a
  /// [LoymaxOtherEvent] carrying the raw payload for any unknown name, or
  /// `null` if the message is malformed (invalid JSON / non-object root).
  static LoymaxOfferEvent? tryParse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final Map<String, dynamic> json = decoded;
    final LoymaxOfferSource source = LoymaxOfferSource.fromString(
      json['source'] as String?,
    );
    final Object? rawName = json['event'];

    switch (rawName) {
      case 'view_all_tap':
        return LoymaxViewAllTap(source: source);
      case 'carousel_card_tap':
        return LoymaxCardTap(
          source: source,
          offer: LoymaxOffer.fromJson(
            (json['personal_offer'] as Map<String, dynamic>?) ??
                <String, dynamic>{},
          ),
        );
      case 'activate_card_tap':
        return LoymaxActivateTap(
          source: source,
          offer: LoymaxOffer.fromJson(
            (json['personal_offer'] as Map<String, dynamic>?) ??
                <String, dynamic>{},
          ),
        );
    }

    if (rawName is! String || rawName.isEmpty) {
      // Missing or non-string event name — can't reasonably surface this as
      // a forward-compat event because the host has nothing to switch on.
      return null;
    }

    return LoymaxOtherEvent(source: source, name: rawName, payload: json);
  }

  final LoymaxOfferSource source;
}

/// "View all" tap inside the carousel.
class LoymaxViewAllTap extends LoymaxOfferEvent {
  const LoymaxViewAllTap({required super.source});
}

/// Tap on a card in the carousel or the full list.
class LoymaxCardTap extends LoymaxOfferEvent {
  const LoymaxCardTap({required super.source, required this.offer});

  final LoymaxOffer offer;
}

/// Successful activation of an offer.
class LoymaxActivateTap extends LoymaxOfferEvent {
  const LoymaxActivateTap({required super.source, required this.offer});

  final LoymaxOffer offer;
}

/// An event whose `event` name is not recognised by this version of the
/// package. Forwarded verbatim so the host app can implement support for new
/// events introduced by Loymax without upgrading the package.
///
/// [name] is the raw `event` field; [payload] is the full decoded JSON
/// object as delivered by the JS bridge — including `event`, `source` and
/// any event-specific fields.
class LoymaxOtherEvent extends LoymaxOfferEvent {
  const LoymaxOtherEvent({
    required super.source,
    required this.name,
    required this.payload,
  });

  final String name;
  final Map<String, dynamic> payload;
}
