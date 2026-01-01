enum AchievementCategory {
  career, // Toplam galibiyet vb.
  skill, // Seri, doğruluk vb.
  social, // Arkadaş sayısı vb.
  economy, // Harcanan coin vb.
  level // Dil seviyesi rozetleri
}

enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final AchievementTier tier;
  final int goal;
  final int currentProgress;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int rewardCoins;
  final String badgeIcon;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.tier,
    required this.goal,
    this.currentProgress = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.rewardCoins,
    required this.badgeIcon,
  });

  double get progressPercentage => (currentProgress / goal).clamp(0.0, 1.0);

  Achievement copyWith({
    int? currentProgress,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      category: category,
      tier: tier,
      goal: goal,
      currentProgress: currentProgress ?? this.currentProgress,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      rewardCoins: rewardCoins,
      badgeIcon: badgeIcon,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.index,
    'tier': tier.index,
    'goal': goal,
    'currentProgress': currentProgress,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'rewardCoins': rewardCoins,
    'badgeIcon': badgeIcon,
  };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    category: AchievementCategory.values[json['category']],
    tier: AchievementTier.values[json['tier']],
    goal: json['goal'],
    currentProgress: json['currentProgress'],
    isUnlocked: json['isUnlocked'],
    unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
    rewardCoins: json['rewardCoins'],
    badgeIcon: json['badgeIcon'],
  );
}
