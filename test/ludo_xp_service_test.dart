import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_xp_service.dart';

void main() {
  group('Ludo XP rules', () {
    test('level curve follows ceil(100 * n^1.4)', () {
      expect(LudoXpService.xpRequiredForLevel(1), 100);
      expect(LudoXpService.xpRequiredForLevel(2), 264);
      expect(LudoXpService.xpRequiredForLevel(10), 2512);
      expect(LudoXpService.xpRequiredForLevel(100), 0);
    });

    test('placement and action XP are calculated correctly', () {
      expect(LudoXpService.calculateBaseXp(
        placement: 1, piecesHome: 2, captures: 1,
      ), 235);
      expect(LudoXpService.calculateBaseXp(
        placement: 2, piecesHome: 1, captures: 2,
      ), 170);
    });

    test('friend bonus and bot reduction are applied in order', () {
      expect(LudoXpService.calculateBaseXp(
        placement: 1, piecesHome: 0, captures: 0, friendMatch: true,
      ), 240);
      expect(LudoXpService.calculateBaseXp(
        placement: 1, piecesHome: 0, captures: 0, botMatch: true,
      ), 50);
      expect(LudoXpService.calculateBaseXp(
        placement: 1, piecesHome: 0, captures: 0,
        botMatch: true, friendMatch: true,
      ), 50);
    });

    test('abandoned or incomplete matches award no XP', () {
      expect(LudoXpService.calculateBaseXp(
        placement: 1, piecesHome: 4, captures: 4, completed: false,
      ), 0);
      expect(LudoXpService.calculateBaseXp(
        placement: 1, piecesHome: 4, captures: 4, abandoned: true,
      ), 0);
    });

    test('bot match reduction is not stacked with friend bonus', () {
      final botOnly = LudoXpService.calculateBaseXp(
        placement: 1, piecesHome: 0, captures: 0, botMatch: true,
      );
      final botAndFriend = LudoXpService.calculateBaseXp(
        placement: 1, piecesHome: 0, captures: 0,
        botMatch: true, friendMatch: true,
      );
      expect(botAndFriend, botOnly);
    });

    test('daily cap is safe even if stored counter is already over cap', () {
      final result = LudoXpService.calculateProgress(
        currentLevel: 1, xpIntoLevel: 0, totalXp: 900,
        dailyXp: 700, baseXp: 120,
      );
      expect(result.awardedXp, 0);
      expect(result.totalXp, 900);
    });

    test('level curve is monotonic until the level cap', () {
      for (var level = 1; level < 99; level++) {
        expect(
          LudoXpService.xpRequiredForLevel(level + 1),
          greaterThan(LudoXpService.xpRequiredForLevel(level)),
        );
      }
    });

    test('invalid progression state is rejected', () {
      expect(() => LudoXpService.calculateProgress(
        currentLevel: 0, xpIntoLevel: 0, totalXp: 0, dailyXp: 0, baseXp: 0,
      ), throwsArgumentError);
    });

    test('daily XP cap prevents overflow', () {
      final result = LudoXpService.calculateProgress(
        currentLevel: 3, xpIntoLevel: 0, totalXp: 500, dailyXp: 480,
        baseXp: 100,
      );
      expect(result.awardedXp, 20);
      expect(result.totalXp, 520);
    });

    test('level-ups can unlock multiple level rewards', () {
      final result = LudoXpService.calculateProgress(
        currentLevel: 1, xpIntoLevel: 0, totalXp: 0, dailyXp: 0,
        baseXp: 400,
      );
      expect(result.newLevel, 3);
      expect(result.unlockedLevels, [2, 3]);
      expect(result.xpIntoLevel, 36);
    });

    test('level 100 is a hard cap', () {
      final result = LudoXpService.calculateProgress(
        currentLevel: 99, xpIntoLevel: 999999, totalXp: 0,
        dailyXp: 0, baseXp: 400,
      );
      expect(result.newLevel, 100);
      expect(result.xpIntoLevel, 0);
    });

    test('invalid match counters are rejected', () {
      expect(() => LudoXpService.calculateBaseXp(
        placement: 1, piecesHome: 5, captures: 0,
      ), throwsArgumentError);
    });
  });
}
