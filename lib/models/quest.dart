import 'package:flutter/material.dart';

enum QuestType {
  winDuels,
  answerQuestions,
  earnPoints,
  playPractice,
  streakCount,
  speedAnswer,      // Hızlı cevap verme
  perfectPractice,  // Hatasız pratik
  daily123Play,     // Günlük 123 oynama
  addWord,          // Kelime ekleme
  buyItem,          // Marketten ürün alma
  usePowerup        // Güçlendirici kullanma
}

class Quest {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final int goal;
  final int currentProgress;
  final int rewardCoins;
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
    this.isCompleted = false,
    required this.lastUpdated,
  });

  double get progressPercentage => (currentProgress / goal).clamp(0.0, 1.0);

  Quest copyWith({
    String? id,
    int? currentProgress,
    bool? isCompleted,
    DateTime? lastUpdated,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title,
      description: description,
      type: type,
      goal: goal,
      currentProgress: currentProgress ?? this.currentProgress,
      rewardCoins: rewardCoins,
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
    isCompleted: json['isCompleted'],
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}
