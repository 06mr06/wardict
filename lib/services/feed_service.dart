import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed_item.dart';

class FeedService {
  static final FeedService instance = FeedService._();
  FeedService._();

  static const String _feedKey = 'user_activity_feed';

  /// Aktivite akışını getirir
  Future<List<FeedItem>> getFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_feedKey);

    if (jsonStr == null) {
      return await _generateInitialFeed();
    }

    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => FeedItem.fromJson(e)).toList();
  }

  /// Başlangıç (simüle edilmiş) akışını oluşturur
  Future<List<FeedItem>> _generateInitialFeed() async {
    final now = DateTime.now();
    final items = [
      FeedItem(
        id: 'f1',
        username: 'WordMaster42',
        avatarEmoji: '🦁',
        type: FeedType.leagueUp,
        content: 'Platin Ligine yükseldi! 🏆',
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
      FeedItem(
        id: 'f2',
        username: 'VocabNinja',
        avatarEmoji: '🥷',
        type: FeedType.duelWin,
        content: 'Büyük bir düello kazandı! ⚔️',
        timestamp: now.subtract(const Duration(minutes: 45)),
      ),
      FeedItem(
        id: 'f3',
        username: 'EnglishPro',
        avatarEmoji: '🎓',
        type: FeedType.achievementUnlock,
        content: '"Sözcüklerin Efendisi" başarısını açtı! ✨',
        timestamp: now.subtract(const Duration(minutes: 10)),
      ),
    ];

    await _saveFeed(items);
    return items;
  }

  /// Akışı kaydeder
  Future<void> _saveFeed(List<FeedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feedKey, jsonEncode(items.map((i) => i.toJson()).toList()));
  }

  /// Yeni bir akış öğesi ekler
  Future<void> addFeedItem(FeedItem item) async {
    final items = await getFeed();
    items.insert(0, item); // En başa ekle
    
    // Maksimum 50 öğe tutalım
    if (items.length > 50) {
      items.removeRange(50, items.length);
    }
    
    await _saveFeed(items);
  }
  
  /// Kullanıcı aktivitesi için akış öğesi oluşturur
  Future<void> logUserActivity(FeedType type, String content, {String? relatedId}) async {
    final item = FeedItem(
      id: 'uf_${DateTime.now().millisecondsSinceEpoch}',
      username: 'Sen',
      avatarEmoji: '👤',
      type: type,
      content: content,
      timestamp: DateTime.now(),
      relatedId: relatedId,
    );
    await addFeedItem(item);
  }
}
