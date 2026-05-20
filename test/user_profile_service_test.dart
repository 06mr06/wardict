import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wardict_skeleton/models/user_level.dart';
import 'package:wardict_skeleton/services/user_profile_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserProfileService.instance.clearCache();
  });

  test('migrates existing placement completion flag into profile JSON', () async {
    final storedProfile = UserProfile(
      level: UserLevel.b2,
      hasCompletedPlacementTest: false,
    );

    SharedPreferences.setMockInitialValues({
      'user_profile': jsonEncode(storedProfile.toJson()),
      'has_completed_placement_test': true,
    });
    UserProfileService.instance.clearCache();

    final profile = await UserProfileService.instance.loadProfile();

    expect(profile.level, UserLevel.b2);
    expect(profile.hasCompletedPlacementTest, isTrue);

    final prefs = await SharedPreferences.getInstance();
    final persistedProfile = UserProfile.fromJson(
      jsonDecode(prefs.getString('user_profile')!) as Map<String, dynamic>,
    );
    expect(persistedProfile.hasCompletedPlacementTest, isTrue);
  });

  test('markPlacementTestCompleted preserves the current level', () async {
    final storedProfile = UserProfile(
      level: UserLevel.c1,
      hasCompletedPlacementTest: false,
    );

    SharedPreferences.setMockInitialValues({
      'user_profile': jsonEncode(storedProfile.toJson()),
    });
    UserProfileService.instance.clearCache();

    await UserProfileService.instance.markPlacementTestCompleted();
    final profile = await UserProfileService.instance.loadProfile();

    expect(profile.level, UserLevel.c1);
    expect(profile.hasCompletedPlacementTest, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('has_completed_placement_test'), isTrue);
  });
}
