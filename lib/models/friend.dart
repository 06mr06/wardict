/// Online durum
enum OnlineStatus {
  online('Çevrimiçi', 0xFF4CAF50),
  away('Uzakta', 0xFFFF9800),
  busy('Meşgul', 0xFFF44336),
  offline('Çevrimdışı', 0xFF9E9E9E);

  final String label;
  final int colorValue;

  const OnlineStatus(this.label, this.colorValue);
}

/// Arkadaşlık durumu
enum FriendStatus {
  none,          // Arkadaş değil
  pending,       // İstek gönderildi, bekliyor
  requested,     // İstek geldi, onay bekliyor
  accepted,      // Arkadaş
  blocked,       // Engellenmiş
}

/// Arkadaş modeli
class Friend {
  final String userId;
  final String username;
  final String? avatarUrl;
  final OnlineStatus status;
  final FriendStatus friendStatus;
  final DateTime? lastOnline;
  final int? lpRating;
  final String? currentLeague;

  const Friend({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.status = OnlineStatus.offline,
    this.friendStatus = FriendStatus.none,
    this.lastOnline,
    this.lpRating,
    this.currentLeague,
  });

  bool get isOnline => status == OnlineStatus.online;
  bool get canDuel => isOnline && friendStatus == FriendStatus.accepted;

  String get lastSeenText {
    if (status == OnlineStatus.online) return 'Çevrimiçi';
    if (lastOnline == null) return 'Bilinmiyor';
    
    final diff = DateTime.now().difference(lastOnline!);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${lastOnline!.day}/${lastOnline!.month}/${lastOnline!.year}';
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'status': status.name,
      'friendStatus': friendStatus.name,
      'lastOnline': lastOnline?.toIso8601String(),
      'lpRating': lpRating,
      'currentLeague': currentLeague,
    };
  }

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatarUrl'],
      status: OnlineStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OnlineStatus.offline,
      ),
      friendStatus: FriendStatus.values.firstWhere(
        (s) => s.name == json['friendStatus'],
        orElse: () => FriendStatus.none,
      ),
      lastOnline: json['lastOnline'] != null 
          ? DateTime.parse(json['lastOnline']) 
          : null,
      lpRating: json['lpRating'] ?? json['eloRating'],
      currentLeague: json['currentLeague'],
    );
  }

  Friend copyWith({
    String? userId,
    String? username,
    String? avatarUrl,
    OnlineStatus? status,
    FriendStatus? friendStatus,
    DateTime? lastOnline,
    int? lpRating,
    String? currentLeague,
  }) {
    return Friend(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      friendStatus: friendStatus ?? this.friendStatus,
      lastOnline: lastOnline ?? this.lastOnline,
      lpRating: lpRating ?? this.lpRating,
      currentLeague: currentLeague ?? this.currentLeague,
    );
  }
}

