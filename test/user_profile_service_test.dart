import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wardict_skeleton/models/user_level.dart';
import 'package:wardict_skeleton/services/user_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserProfileService.instance.clearCache();
  });

  test('markPlacementTestCompleted preserves the selected level', () async {
    await UserProfileService.instance.saveProfile(
      UserProfile(level: UserLevel.b2),
    );

    await UserProfileService.instance.markPlacementTestCompleted();

    final profile = await UserProfileService.instance.reloadProfile();
    expect(profile.level, UserLevel.b2);
    expect(profile.hasCompletedPlacementTest, isTrue);
    expect(await UserProfileService.instance.hasCompletedPlacementTest(), isTrue);
  });

  test('hasCompletedPlacementTest migrates the legacy preference flag', () async {
    await UserProfileService.instance.saveProfile(
      UserProfile(level: UserLevel.c1),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_placement_test', true);

    expect(await UserProfileService.instance.hasCompletedPlacementTest(), isTrue);

    final profile = await UserProfileService.instance.reloadProfile();
    expect(profile.level, UserLevel.c1);
    expect(profile.hasCompletedPlacementTest, isTrue);
  });
}
