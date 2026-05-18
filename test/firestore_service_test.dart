import 'package:flutter_test/flutter_test.dart';
import 'package:wardict_skeleton/services/firebase/firestore_service.dart';

void main() {
  group('FirestoreService.buildExistingUserProfileUpdate', () {
    test('does not include progress fields that would reset returning users', () {
      final update = FirestoreService.buildExistingUserProfileUpdate(
        username: 'Ada',
        email: 'ada@example.com',
      );

      expect(update['username'], 'Ada');
      expect(update['email'], 'ada@example.com');
      expect(update.containsKey('lastPlayedAt'), isTrue);

      for (final key in [
        'totalScore',
        'practiceScore',
        'gamesPlayed',
        'duelWins',
        'duelLosses',
        'leagueScores',
        'achievements',
        'friends',
        'createdAt',
        'level',
      ]) {
        expect(update.containsKey(key), isFalse, reason: key);
      }
    });

    test('does not overwrite an existing email with a blank value', () {
      final update = FirestoreService.buildExistingUserProfileUpdate(
        username: 'GoogleUser',
        email: '',
      );

      expect(update['username'], 'GoogleUser');
      expect(update.containsKey('email'), isFalse);
      expect(update.containsKey('lastPlayedAt'), isTrue);
    });
  });
}
