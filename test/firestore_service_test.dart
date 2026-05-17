import 'package:flutter_test/flutter_test.dart';
import 'package:wardict_skeleton/services/firebase/firestore_service.dart';

void main() {
  group('FirestoreService.existingProfileRefreshUpdates', () {
    test('preserves existing progress fields for returning users', () {
      final updates = FirestoreService.existingProfileRefreshUpdates(
        existingData: const {
          'username': 'CustomName',
          'level': 'C1',
          'totalScore': 4200,
          'practiceScore': 900,
          'gamesPlayed': 37,
          'duelWins': 12,
          'duelLosses': 5,
          'leagueScores': {'A': 1800},
          'achievements': ['first_win'],
          'friends': ['friend-1'],
        },
        username: 'Google Display Name',
        email: 'new@example.com',
        lastPlayedAt: 'server-time',
      );

      expect(updates, {
        'lastPlayedAt': 'server-time',
        'email': 'new@example.com',
      });
    });

    test('fills username only when an existing profile is missing one', () {
      final updates = FirestoreService.existingProfileRefreshUpdates(
        existingData: const {'username': ''},
        username: 'Google Display Name',
        email: 'new@example.com',
        lastPlayedAt: 'server-time',
      );

      expect(updates, {
        'lastPlayedAt': 'server-time',
        'email': 'new@example.com',
        'username': 'Google Display Name',
      });
    });
  });
}
