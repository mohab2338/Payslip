class ReferenceGood {
  final String id;
  final String name;
  final String categoryId;
  final Map<String, double> shopPrices;
  final String? bestQualityShop;
  final DateTime updatedAt;

  const ReferenceGood({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.shopPrices,
    this.bestQualityShop,
    required this.updatedAt,
  });

  String? get cheapestShop {
    if (shopPrices.isEmpty) return null;
    return shopPrices.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
  }

  double? get cheapestPrice {
    final shop = cheapestShop;
    return shop == null ? null : shopPrices[shop];
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'shopPrices': shopPrices,
        'bestQualityShop': bestQualityShop,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ReferenceGood.fromMap(Map<String, dynamic> map) => ReferenceGood(
        id: map['id'] as String,
        name: map['name'] as String,
        categoryId: map['categoryId'] as String,
        shopPrices: (map['shopPrices'] as Map? ?? {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
        bestQualityShop: map['bestQualityShop'] as String?,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
}
