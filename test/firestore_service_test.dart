import 'package:flutter_test/flutter_test.dart';
import 'package:wardict_skeleton/services/firebase/firestore_service.dart';

void main() {
  group('FirestoreService.existingUserProfileUpdateData', () {
    test('does not include fields that would reset saved progress', () {
      final data = FirestoreService.existingUserProfileUpdateData(
        username: 'Existing Player',
        email: 'player@example.com',
      );

      expect(data['username'], 'Existing Player');
      expect(data['email'], 'player@example.com');
      expect(data, contains('lastPlayedAt'));

      expect(data, isNot(contains('level')));
      expect(data, isNot(contains('totalScore')));
      expect(data, isNot(contains('practiceScore')));
      expect(data, isNot(contains('gamesPlayed')));
      expect(data, isNot(contains('duelWins')));
      expect(data, isNot(contains('duelLosses')));
      expect(data, isNot(contains('leagueScores')));
      expect(data, isNot(contains('achievements')));
      expect(data, isNot(contains('friends')));
      expect(data, isNot(contains('createdAt')));
      expect(data, isNot(contains('avatarId')));
      expect(data, isNot(contains('photoURL')));
    });

    test('does not overwrite an existing email with an empty provider value', () {
      final data = FirestoreService.existingUserProfileUpdateData(
        username: 'Existing Player',
        email: '',
      );

      expect(data, isNot(contains('email')));
    });
  });
}
