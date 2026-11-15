import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_game.dart';

void main() {
  group('LudoRules', () {
    test('four players start at four distinct track entries', () {
      expect(
        List<int>.generate(4, (player) => LudoRules.trackIndex(player, 0)!),
        [0, 39, 26, 13],
      );
    });

    test('a six is required to leave the yard', () {
      final positions = List.generate(4, (_) => List<int>.filled(4, -1));
      expect(LudoRules.legalTokensInGame(positions, 0, 5), isEmpty);
      expect(LudoRules.legalTokensInGame(positions, 0, 6), [0, 1, 2, 3]);
    });

    test('leaving the yard places the selected token on its start square', () {
      final positions = List.generate(4, (_) => List<int>.filled(4, -1));
      final result = LudoRules.move(
        positions: positions,
        player: 0,
        token: 2,
        dice: 6,
      );
      expect(result.positions[0], [-1, -1, 0, -1]);
      expect(result.captured, isFalse);
      expect(result.won, isFalse);
    });

    test('an unsafe landing captures an opponent token', () {
      final positions = List.generate(4, (_) => List<int>.filled(4, -1));
      positions[0][0] = 0;
      positions[1][0] = 14; // Same global square as player 0 progress 1.
      final result = LudoRules.move(
        positions: positions,
        player: 0,
        token: 0,
        dice: 1,
      );
      expect(result.positions[0][0], 1);
      expect(result.positions[1][0], -1);
      expect(result.captured, isTrue);
    });

    test('safe squares protect opponent tokens from capture', () {
      final positions = List.generate(4, (_) => List<int>.filled(4, -1));
      positions[0][0] = 7;
      positions[1][0] = 21; // Both resolve to global safe square 8 after landing.
      final result = LudoRules.move(
        positions: positions,
        player: 0,
        token: 0,
        dice: 1,
      );
      expect(result.positions[0][0], 8);
      expect(result.positions[1][0], 21);
      expect(result.captured, isFalse);
    });

    test('a token must roll the exact distance to finish', () {
      expect(LudoRules.legalTokens([56, -1, -1, -1], 1), isEmpty);
      expect(LudoRules.legalTokens([56, -1, -1, -1], 2), isEmpty);
      expect(LudoRules.legalTokens([55, -1, -1, -1], 2), [0]);
    });
  });
}
