import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_game.dart';

void main() {
  group('LudoRules', () {
    test('a token leaves the yard only with a six', () {
      expect(LudoRules.legalTokens([-1, -1, -1, -1], 5), isEmpty);
      expect(LudoRules.legalTokens([-1, -1, -1, -1], 6), [0, 1, 2, 3]);
    });

    test('requires an exact roll to enter home', () {
      expect(LudoRules.legalTokens([56, -1, -1, -1], 1), contains(0));
      expect(LudoRules.legalTokens([56, -1, -1, -1], 2), isEmpty);
    });

    test('captures an opponent on a non-safe square', () {
      final result = LudoRules.move(
        positions: [
          [4, -1, -1, -1],
          [31, -1, -1, -1],
        ],
        player: 0,
        token: 0,
        dice: 1,
      );
      expect(result.positions[0][0], 5);
      expect(result.positions[1][0], -1);
      expect(result.captured, isTrue);
    });

    test('does not capture an opponent on a safe square', () {
      final result = LudoRules.move(
        positions: [
          [7, -1, -1, -1],
          [34, -1, -1, -1],
        ],
        player: 0,
        token: 0,
        dice: 1,
      );
      expect(result.positions[0][0], 8);
      expect(result.positions[1][0], 47);
      expect(result.captured, isFalse);
    });

    test('a two-token blockade cannot be crossed', () {
      final positions = [
        [3, -1, -1, -1],
        [31, 31, -1, -1],
      ];
      expect(LudoRules.legalTokensInGame(positions, 0, 2), isEmpty);
      expect(
        () => LudoRules.move(positions: positions, player: 0, token: 0, dice: 2),
        throwsStateError,
      );
    });

    test('wins only after all four tokens reach home', () {
      final result = LudoRules.move(
        positions: [
          [57, 57, 57, 56],
          [-1, -1, -1, -1],
        ],
        player: 0,
        token: 3,
        dice: 1,
      );
      expect(result.finished, isTrue);
      expect(result.won, isTrue);
    });

    test('rejects an illegal move', () {
      expect(
        () => LudoRules.move(
          positions: [
            [-1, -1, -1, -1],
            [-1, -1, -1, -1],
          ],
          player: 0,
          token: 0,
          dice: 4,
        ),
        throwsStateError,
      );
    });
  });
}
