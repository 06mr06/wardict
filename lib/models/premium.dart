/// Premium üyelik durumu
enum PremiumTier {
  free('Ücretsiz', 0),
  premium('Premium', 4.99);

  final String name;
  final double monthlyPriceUSD;

  const PremiumTier(this.name, this.monthlyPriceUSD);
  
  /// VIP'ten premium'a geçiş için uyumluluk
  /// Eski VIP kullanıcıları premium olarak kabul edilir
  static PremiumTier fromLegacy(String name) {
    if (name == 'vip') return premium;
    return values.firstWhere(
      (t) => t.name == name,
      orElse: () => free,
    );
  }
}

/// Premium özellikleri
class PremiumFeatures {
  /// Ücretsiz kullanıcılarda bu özellikler kilitli
  /// Artık tüm özellikler Premium'da açık
  static const Map<String, PremiumTier> featureRequirements = {
    'profile_photo': PremiumTier.premium,      // Profil fotoğrafı yükleme
    'custom_avatar': PremiumTier.premium,       // Özel avatar seçimi
    'unlimited_duels': PremiumTier.premium,     // Sınırsız duel
    'ad_free': PremiumTier.premium,             // Reklamsız deneyim
    'exclusive_powerups': PremiumTier.premium,  // Özel powerup'lar
    'leaderboard_badge': PremiumTier.premium,   // Liderlik tablosu rozeti
    'custom_themes': PremiumTier.premium,       // Özel temalar
    'priority_matching': PremiumTier.premium,   // Öncelikli eşleşme
    'stats_export': PremiumTier.premium,        // İstatistik dışa aktarma
    'offline_mode': PremiumTier.premium,        // Çevrimdışı mod
  };

  /// Kullanıcının bir özelliğe erişimi var mı?
  static bool hasAccess(PremiumTier userTier, String feature) {
    final required = featureRequirements[feature];
    if (required == null) return true; // Özellik listede yoksa herkese açık
    return userTier.index >= required.index;
  }
}

/// Premium abonelik bilgisi
class PremiumSubscription {
  final PremiumTier tier;
  final DateTime? expiresAt;
  final bool autoRenew;
  final String? transactionId;

  const PremiumSubscription({
    this.tier = PremiumTier.free,
    this.expiresAt,
    this.autoRenew = false,
    this.transactionId,
  });

  bool get isActive {
    if (tier == PremiumTier.free) return true;
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt!);
  }

  bool get isExpired {
    if (tier == PremiumTier.free) return false;
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt!);
  }

  int get daysRemaining {
    if (expiresAt == null) return 0;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier.name,
      'expiresAt': expiresAt?.toIso8601String(),
      'autoRenew': autoRenew,
      'transactionId': transactionId,
    };
  }

  factory PremiumSubscription.fromJson(Map<String, dynamic> json) {
    return PremiumSubscription(
      tier: PremiumTier.fromLegacy(json['tier'] ?? 'free'),
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt']) 
          : null,
      autoRenew: json['autoRenew'] ?? false,
      transactionId: json['transactionId'],
    );
  }
}
