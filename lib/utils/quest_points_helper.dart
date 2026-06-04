import '../models/powerup.dart';

/// One correct round; same rules as [GameProvider._answerInternal]
/// (time multiplier, speed bonus, streak bonus, streak combo mult, optional x2 power-up).
int duelStyleRoundPoints({
  required int remainingSeconds,
  required int streakAfterCorrect,
  List<PowerupType> usedPowerups = const [],
}) {
  if (streakAfterCorrect < 1) return 0;

  double multiplier = 1.0;
  if (remainingSeconds >= 8) {
    multiplier = 1.5;
  } else if (remainingSeconds >= 5) {
    multiplier = 1.2;
  } else if (remainingSeconds >= 3) {
    multiplier = 1.0;
  } else {
    multiplier = 0.7;
  }

  int speedBonus = 0;
  if (remainingSeconds >= 5) {
    speedBonus = 5;
  } else if (remainingSeconds >= 3) {
    speedBonus = 3;
  } else if (remainingSeconds >= 1) {
    speedBonus = 1;
  }

  int streakBonus =
      (streakAfterCorrect > 1) ? (streakAfterCorrect - 1) * 2 : 0;
  if (streakBonus > 10) streakBonus = 10;

  bool hasMultiplier = usedPowerups.contains(PowerupType.multiplier);
  double multValue = hasMultiplier ? 2.0 : 1.0;

  if (streakAfterCorrect >= 10) {
    multValue *= 3.0;
  } else if (streakAfterCorrect >= 7) {
    multValue *= 2.0;
  } else if (streakAfterCorrect >= 5) {
    multValue *= 1.5;
  } else if (streakAfterCorrect >= 3) {
    multValue *= 1.2;
  }

  return ((10 + speedBonus + streakBonus) * multValue * multiplier).round();
}

/// Daily quests / fill-blank: duel-style, no power-ups.
int questPointsForCorrectAnswer({
  required int remainingSeconds,
  required int streakAfterCorrect,
}) {
  return duelStyleRoundPoints(
    remainingSeconds: remainingSeconds,
    streakAfterCorrect: streakAfterCorrect,
  );
}