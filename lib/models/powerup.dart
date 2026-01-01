/// Powerup türleri
enum PowerupType {
  revealAnswer('reveal', 'Doğru Cevap', 'Doğru cevabı gösterir', 200, '🎯'),
  fiftyFifty('fifty', '%50', '2 yanlış şıkkı eler', 150, '✂️'),
  doubleChance('double', 'İkinci Şans', '2 cevap hakkı verir', 150, '🔄'),
  freezeTime('freeze', 'Zaman Durdur', 'Süreyi 5 saniye dondurur', 100, '❄️'),
  multiplier('multi', '2x Puan', 'Doğru cevaba 2x puan', 250, '⚡');

  final String id;
  final String name;
  final String description;
  final int price; // Coin cinsinden fiyat
  final String emoji;

  const PowerupType(this.id, this.name, this.description, this.price, this.emoji);

  static PowerupType fromId(String id) {
    return PowerupType.values.firstWhere(
      (p) => p.id == id,
      orElse: () => PowerupType.revealAnswer,
    );
  }
}

/// Kullanıcının powerup envanteri
class PowerupInventory {
  final Map<PowerupType, int> items;

  const PowerupInventory({this.items = const {}});

  int getCount(PowerupType type) => items[type] ?? 0;

  bool hasAny(PowerupType type) => getCount(type) > 0;

  PowerupInventory add(PowerupType type, int count) {
    final newItems = Map<PowerupType, int>.from(items);
    newItems[type] = (newItems[type] ?? 0) + count;
    return PowerupInventory(items: newItems);
  }

  PowerupInventory use(PowerupType type) {
    if (!hasAny(type)) return this;
    final newItems = Map<PowerupType, int>.from(items);
    newItems[type] = (newItems[type] ?? 1) - 1;
    if (newItems[type] == 0) newItems.remove(type);
    return PowerupInventory(items: newItems);
  }

  Map<String, dynamic> toJson() {
    return items.map((key, value) => MapEntry(key.id, value));
  }

  factory PowerupInventory.fromJson(Map<String, dynamic> json) {
    final items = <PowerupType, int>{};
    for (final entry in json.entries) {
      try {
        final type = PowerupType.fromId(entry.key);
        items[type] = entry.value as int;
      } catch (_) {}
    }
    return PowerupInventory(items: items);
  }
}

/// Market öğesi
class ShopItem {
  final PowerupType powerup;
  final int quantity;
  final int? discountPrice;
  final bool isPopular;
  final bool isLimited;

  const ShopItem({
    required this.powerup,
    this.quantity = 1,
    this.discountPrice,
    this.isPopular = false,
    this.isLimited = false,
  });

  int get totalPrice => discountPrice ?? (powerup.price * quantity);
  bool get hasDiscount => discountPrice != null;
  int get savings => (powerup.price * quantity) - totalPrice;
}

/// Coin paketi
class CoinPackage {
  final String id;
  final int coins;
  final double priceUSD;
  final int? bonusCoins;
  final bool isBestValue;

  const CoinPackage({
    required this.id,
    required this.coins,
    required this.priceUSD,
    this.bonusCoins,
    this.isBestValue = false,
  });

  int get totalCoins => coins + (bonusCoins ?? 0);

  static const List<CoinPackage> packages = [
    CoinPackage(id: 'coins_100', coins: 100, priceUSD: 0.99),
    CoinPackage(id: 'coins_500', coins: 500, priceUSD: 3.99, bonusCoins: 50),
    CoinPackage(id: 'coins_1200', coins: 1200, priceUSD: 7.99, bonusCoins: 200, isBestValue: true),
    CoinPackage(id: 'coins_3000', coins: 3000, priceUSD: 17.99, bonusCoins: 600),
  ];
}
