import 'package:flutter_test/flutter_test.dart';
import 'package:wardict_skeleton/screens/game/online_duel_screen.dart';

void main() {
  group('canonicalSelectedOptionIndexForOnlineDuel', () {
    test('maps a shuffled display option back to its canonical option index', () {
      const canonicalOptionIndexes = [2, 0, 3, 1];

      expect(
        canonicalSelectedOptionIndexForOnlineDuel(canonicalOptionIndexes, 1),
        0,
      );
      expect(
        canonicalSelectedOptionIndexForOnlineDuel(canonicalOptionIndexes, 3),
        1,
      );
    });

    test('returns -1 when no valid display option was selected', () {
      const canonicalOptionIndexes = [2, 0, 3, 1];

      expect(
        canonicalSelectedOptionIndexForOnlineDuel(canonicalOptionIndexes, null),
        -1,
      );
      expect(
        canonicalSelectedOptionIndexForOnlineDuel(canonicalOptionIndexes, -1),
        -1,
      );
      expect(
        canonicalSelectedOptionIndexForOnlineDuel(canonicalOptionIndexes, 4),
        -1,
      );
    });
  });
}
