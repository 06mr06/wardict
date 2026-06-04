import 'package:shared_preferences/shared_preferences.dart';

class SeasonService {
  static SeasonService? _instance;
  static SeasonService get instance => _instance ??= SeasonService._();
  SeasonService._();

  static const String _seasonIdKey = 'current_season_id';
  static const String _seasonPointsKey = 'season_points';
  static const String _seasonStartKey = 'season_start_date';
  static const String _seasonEndKey = 'season_end_date';
  static const String _seasonRankKey = 'season_rank';
  static const String _seasonBestRankKey = 'season_best_rank';
  static const String _seasonWinsKey = 'season_wins';
  static const String _seasonGamesKey = 'season_games';
  static const String _seasonBadgesKey = 'season_badges';

  int _seasonPoints = 0;
  int get seasonPoints => _seasonPoints;

  int _seasonRank = 0;
  int get seasonRank => _seasonRank;

  int _seasonBestRank = 0;
  int get seasonBestRank => _seasonBestRank;

  int _seasonWins = 0;
  int get seasonWins => _seasonWins;

  int _seasonGames = 0;
  int get seasonGames => _seasonGames;

  List<String> _seasonBadges = [];
  List<String> get seasonBadges => _seasonBadges;

  String _currentSeasonId = '';
  String get currentSeasonId => _currentSeasonId;

  DateTime? _seasonEndDate;
  DateTime? get seasonEndDate => _seasonEndDate;

  Future<void> loadSeasonData() async {
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final savedSeasonId = prefs.getString(_seasonIdKey) ?? '';
    final seasonEndStr = prefs.getString(_seasonEndKey);

    if (seasonEndStr != null) {
      _seasonEndDate = DateTime.tryParse(seasonEndStr);
    }

    if (_seasonEndDate == null || now.isAfter(_seasonEndDate!)) {
      await _startNewSeason();
      return;
    }

    _currentSeasonId = savedSeasonId;
    _seasonPoints = prefs.getInt(_seasonPointsKey) ?? 0;
    _seasonRank = prefs.getInt(_seasonRankKey) ?? 0;
    _seasonBestRank = prefs.getInt(_seasonBestRankKey) ?? 0;
    _seasonWins = prefs.getInt(_seasonWinsKey) ?? 0;
    _seasonGames = prefs.getInt(_seasonGamesKey) ?? 0;
    _seasonBadges = prefs.getStringList(_seasonBadgesKey) ?? [];
  }

  Future<void> _startNewSeason() async {
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final endOfNextMonth = DateTime(now.year, now.month + 2, 0);

    _currentSeasonId = 'S${now.year}${now.month.toString().padLeft(2, '0')}';
    _seasonEndDate = lastDayOfMonth;
    _seasonPoints = 0;
    _seasonRank = 0;
    _seasonBestRank = 0;
    _seasonWins = 0;
    _seasonGames = 0;
    _seasonBadges = [];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seasonIdKey, _currentSeasonId);
    await prefs.setString(_seasonEndKey, _seasonEndDate!.toIso8601String());
    await prefs.setInt(_seasonPointsKey, 0);
    await prefs.setInt(_seasonRankKey, 0);
    await prefs.setInt(_seasonBestRankKey, 0);
    await prefs.setInt(_seasonWinsKey, 0);
    await prefs.setInt(_seasonGamesKey, 0);
    await prefs.setStringList(_seasonBadgesKey, []);
  }

  Future<void> addPoints(int points) async {
    _seasonPoints += points;
    _updateRank();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seasonPointsKey, _seasonPoints);

    if (_seasonRank < _seasonBestRank || _seasonBestRank == 0) {
      _seasonBestRank = _seasonRank;
      await prefs.setInt(_seasonBestRankKey, _seasonBestRank);
    }
  }

  Future<void> addWin() async {
    _seasonWins++;
    _seasonGames++;
    await addPoints(100);
    _checkBadges();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seasonWinsKey, _seasonWins);
    await prefs.setInt(_seasonGamesKey, _seasonGames);
  }

  Future<void> addGame() async {
    _seasonGames++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seasonGamesKey, _seasonGames);
  }

  void _updateRank() {
    if (_seasonPoints >= 5000) {
      _seasonRank = 1;
    } else if (_seasonPoints >= 3000) {
      _seasonRank = 2;
    } else if (_seasonPoints >= 1500) {
      _seasonRank = 3;
    } else if (_seasonPoints >= 500) {
      _seasonRank = 4;
    } else if (_seasonPoints >= 100) {
      _seasonRank = 5;
    } else {
      _seasonRank = 6;
    }
  }

  void _checkBadges() {
    if (_seasonWins >= 1 && !_seasonBadges.contains('first_win')) {
      _seasonBadges.add('first_win');
    }
    if (_seasonWins >= 10 && !_seasonBadges.contains('veteran')) {
      _seasonBadges.add('veteran');
    }
    if (_seasonWins >= 50 && !_seasonBadges.contains('champion')) {
      _seasonBadges.add('champion');
    }
    if (_seasonPoints >= 1000 && !_seasonBadges.contains('high_scorer')) {
      _seasonBadges.add('high_scorer');
    }
    if (_seasonRank <= 3 && !_seasonBadges.contains('top_3')) {
      _seasonBadges.add('top_3');
    }
  }

  String get seasonName {
    if (_currentSeasonId.isEmpty) return 'Sezon';
    return 'Sezon ${_currentSeasonId.substring(1)}';
  }

  String get seasonStatus {
    if (_seasonEndDate == null) return '';
    final now = DateTime.now();
    final daysLeft = _seasonEndDate!.difference(now).inDays;
    if (daysLeft <= 0) return 'Sezon bitmek üzere!';
    if (daysLeft == 1) return '1 gün kaldı';
    return '$daysLeft gün kaldı';
  }

  double get progressPercentage {
    if (_seasonEndDate == null) return 0;
    final now = DateTime.now();
    final total = _seasonEndDate!
        .difference(DateTime(
            now.year,
            now.month - 1 < 1 ? now.year - 1 : now.year,
            now.month - 1 < 1 ? 12 : now.month - 1,
            1))
        .inDays;
    final elapsed = now
        .difference(DateTime(
            now.year,
            now.month - 1 < 1 ? now.year - 1 : now.year,
            now.month - 1 < 1 ? 12 : now.month - 1,
            1))
        .inDays;
    if (total <= 0) return 1;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

enum SeasonBadge {
  firstWin('İlk Zafer', '🏆', 'İlk düello galibiyeti'),
  veteran('Veteran', '🎖️', '10 düello galibiyeti'),
  champion('Şampiyon', '👑', '50 düello galibiyeti'),
  highScorer('Yüksek Puan', '⭐', '1000+ sezon puanı'),
  top3('İlk 3', '🥇', 'Sezonu ilk 3te bitir');

  final String name;
  final String icon;
  final String description;

  const SeasonBadge(this.name, this.icon, this.description);
}
