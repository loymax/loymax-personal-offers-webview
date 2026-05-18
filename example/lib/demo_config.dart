import 'package:loymax_personal_offers/loymax_personal_offers.dart';

// TODO: replace the placeholders below with the values for your environment
// before running the example. Provided by your Loymax integration manager.

/// Short tenant name, e.g. `acme`.
const String kPartner = '<partner>';

/// Customer identifier obtained from `GET /v1.2/user`.
const String kPersonUid = '<person-uid>';

/// Working baseUrl for the personal offers page.
const LoymaxOffersConfig kLoymaxConfig = LoymaxOffersConfig(
  baseUrl: '<LOYMAX_OFFERS_BASE_URL>',
);

/// Deliberately broken baseUrl used in the gallery to demonstrate the
/// `error` phase. Any unreachable host works.
const LoymaxOffersConfig kBrokenLoymaxConfig = LoymaxOffersConfig(
  baseUrl: 'https://invalid.example/personalOffers-does-not-exist',
);
