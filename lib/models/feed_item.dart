enum FeedType {
  duelWin,
  leagueUp,
  achievementUnlock,
  friendRequest,
  questComplete
}

class FeedItem {
  final String id;
  final String username;
  final String? avatarEmoji;
  final FeedType type;
  final String content;
  final DateTime timestamp;
  final String? relatedId; // Match ID, Achievement ID etc.

  FeedItem({
    required this.id,
    required this.username,
    this.avatarEmoji,
    required this.type,
    required this.content,
    required this.timestamp,
    this.relatedId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'avatarEmoji': avatarEmoji,
    'type': type.index,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'relatedId': relatedId,
  };

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
    id: json['id'],
    username: json['username'],
    avatarEmoji: json['avatarEmoji'],
    type: FeedType.values[json['type']],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    relatedId: json['relatedId'],
  );
}
