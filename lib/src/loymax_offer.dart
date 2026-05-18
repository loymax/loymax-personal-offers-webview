/// A personal offer delivered from the WebView.
class LoymaxOffer {
  const LoymaxOffer({required this.id, required this.name});

  factory LoymaxOffer.fromJson(Map<String, dynamic> json) => LoymaxOffer(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
  );

  final String id;
  final String name;

  @override
  String toString() => 'LoymaxOffer(id: $id, name: $name)';
}

/// Event source: which view the event originated from.
enum LoymaxOfferSource {
  carousel,
  list;

  static LoymaxOfferSource fromString(String? raw) {
    switch (raw) {
      case 'list':
        return LoymaxOfferSource.list;
      case 'carousel':
      default:
        return LoymaxOfferSource.carousel;
    }
  }
}
