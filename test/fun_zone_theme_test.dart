import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/fun_zone_theme.dart';

void main() {
  group('Fun backdrop access', () {
    test('unverified users unlock backdrops one level at a time', () {
      const levelOne = FunBackdropAccess(verified: false, points: 0, level: 1);
      expect(levelOne.canUse(FunBackdrop.emerald), isTrue);
      expect(levelOne.canUse(FunBackdrop.stadium), isFalse);
      expect(levelOne.canUse(FunBackdrop.snow), isFalse);

      const levelThree = FunBackdropAccess(verified: false, points: 120, level: 3);
      expect(levelThree.canUse(FunBackdrop.emerald), isTrue);
      expect(levelThree.canUse(FunBackdrop.stadium), isTrue);
      expect(levelThree.canUse(FunBackdrop.snow), isTrue);
      expect(levelThree.canUse(FunBackdrop.aurora), isFalse);
    });

    test('verified users can use every backdrop regardless of points', () {
      const verified = FunBackdropAccess(verified: true, points: 0, level: 1);
      for (final backdrop in FunBackdrop.values) {
        expect(verified.canUse(backdrop), isTrue);
      }
    });

    test('points map to the configured progression levels', () {
      expect(FunBackdropAccess.levelFor(0), 1);
      expect(FunBackdropAccess.levelFor(49), 1);
      expect(FunBackdropAccess.levelFor(50), 2);
      expect(FunBackdropAccess.levelFor(120), 3);
      expect(FunBackdropAccess.levelFor(220), 4);
      expect(FunBackdropAccess.levelFor(350), 5);
      expect(FunBackdropAccess.levelFor(520), 6);
    });
  });
}
