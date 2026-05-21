import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wardict_skeleton/models/user_level.dart';
import 'package:wardict_skeleton/services/shop_service.dart';
import 'package:wardict_skeleton/services/user_profile_service.dart';

void main() {
  group('persistence regressions', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      UserProfileService.instance.clearCache();
    });

    test('markPlacementTestCompleted persists the profile flag', () async {
      await UserProfileService.instance.updateLevel(UserLevel.b2);

      await UserProfileService.instance.markPlacementTestCompleted();
      UserProfileService.instance.clearCache();

      final profile = await UserProfileService.instance.loadProfile();
      expect(profile.hasCompletedPlacementTest, isTrue);
      expect(profile.level, UserLevel.b2);
      expect(
        await UserProfileService.instance.hasCompletedPlacementTest(),
        isTrue,
      );
    });

    test('first coin initialization preserves preexisting balance', () async {
      SharedPreferences.setMockInitialValues({'user_coins': 115});

      final coins = await ShopService.instance.getCoins();

      expect(coins, 115);
    });
  });
}
