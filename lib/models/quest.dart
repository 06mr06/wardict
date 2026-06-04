
enum QuestType {
  winDuels,
  answerQuestions,
  earnPoints,
  playPractice,
  streakCount,
  speedAnswer,
  perfectPractice,
  daily123Play,
  addWord,
  buyItem,
  usePowerup,
  equipItem,
  buddyDuel
}

class Quest {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final int goal;
  final int currentProgress;
  final int rewardCoins;
  final String? rewardPowerupType; // Powerup ID (reveal, fifty, etc)
  final int? rewardPowerupCount;
  final bool isCompleted;
  final DateTime lastUpdated;

  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.goal,
    this.currentProgress = 0,
    required this.rewardCoins,
    this.rewardPowerupType,
    this.rewardPowerupCount,
    this.isCompleted = false,
    required this.lastUpdated,
  });

  double get progressPercentage => (currentProgress / goal).clamp(0.0, 1.0);

  Quest copyWith({
    String? id,
    int? currentProgress,
    bool? isCompleted,
    DateTime? lastUpdated,
    int? rewardCoins,
    String? rewardPowerupType,
    int? rewardPowerupCount,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title,
      description: description,
      type: type,
      goal: goal,
      currentProgress: currentProgress ?? this.currentProgress,
      rewardCoins: rewardCoins ?? this.rewardCoins,
      rewardPowerupType: rewardPowerupType ?? this.rewardPowerupType,
      rewardPowerupCount: rewardPowerupCount ?? this.rewardPowerupCount,
      isCompleted: isCompleted ?? this.isCompleted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.index,
    'goal': goal,
    'currentProgress': currentProgress,
    'rewardCoins': rewardCoins,
    'rewardPowerupType': rewardPowerupType,
    'rewardPowerupCount': rewardPowerupCount,
    'isCompleted': isCompleted,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    type: QuestType.values[json['type']],
    goal: json['goal'],
    currentProgress: json['currentProgress'],
    rewardCoins: json['rewardCoins'],
    rewardPowerupType: json['rewardPowerupType'],
    rewardPowerupCount: json['rewardPowerupCount'],
    isCompleted: json['isCompleted'],
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}
