import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_game.dart';

void main() {
  group('LudoRules', () {
    test('four-player turn order follows red, blue, yellow, green without skipping', () {
      var turn = 0;
      final order = <int>[];
      for (var i = 0; i < 8; i++) {
        order.add(turn);
        turn = LudoRules.nextPlayer(turn, 4);
      }
      expect(order, [0, 1, 2, 3, 0, 1, 2, 3]);
      expect(LudoRules.nextPlayer(1, 2), 0);
    });

    test('two-player games use opposite start squares', () {
      expect(LudoRules.trackIndex(0, 0, playerCount: 2), 0);
      expect(LudoRules.trackIndex(1, 0, playerCount: 2), 26);
      expect(LudoRules.trackIndex(1, 0, playerCount: 4), 39);
    });

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
      expect(result.positions[1][0], 34);
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

    test('leaving the yard checks only the entry square, not six squares ahead', () {
      // In a two-player game, opponent progress 27 maps to track square 1.
      // That blockade is after player zero's entry square and must not prevent
      // the token from entering directly onto square 0.
      final positions = [
        [-1, -1, -1, -1],
        [27, 27, -1, -1],
      ];
      expect(LudoRules.legalTokensInGame(positions, 0, 6), contains(0));
    });

    test('a blockade on the entry square prevents leaving the yard', () {
      // Opponent progress 26 maps to player zero's start square in a 2-player game.
      final positions = [
        [-1, -1, -1, -1],
        [26, 26, -1, -1],
      ];
      expect(LudoRules.legalTokensInGame(positions, 0, 6), isEmpty);
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


    test('a safe-square stack from different players is not a blockade', () {
      final positions = [
        [8, -1, -1, -1],
        [47, -1, -1, -1],
        [33, -1, -1, -1],
      ];
      expect(LudoRules.legalTokensInGame(positions, 2, 1), contains(0));
    });

    test('invalid player counts, indices, and dice values are rejected safely', () {
      expect(LudoRules.trackIndex(3, 0, playerCount: 2), isNull);
      expect(LudoRules.trackIndex(0, 0, playerCount: 1), isNull);
      expect(
        LudoRules.legalTokensInGame([[-1, -1, -1, -1]], 0, 6),
        isEmpty,
      );
      expect(
        LudoRules.legalTokensInGame(
          [[-1, -1, -1], [-1, -1, -1]],
          0,
          6,
        ),
        isEmpty,
      );
      expect(
        LudoRules.legalTokensInGame(
          [[-1, -1, -1, -1], [-1, -1, -1, -1]],
          0,
          7,
        ),
        isEmpty,
      );
    });

    test('stacked tokens stay tightly grouped and centered', () {
      for (final count in [2, 3, 4]) {
        final offsets = LudoBoardGeometry.compactStackOffsets(count, 300);
        expect(offsets, hasLength(count));
        expect(
          offsets.every((offset) => offset.distance <= 13),
          isTrue,
          reason: '$count tokens should stay within a compact 13px radius',
        );
        final averageX =
            offsets.fold<double>(0, (sum, offset) => sum + offset.dx) / count;
        final averageY =
            offsets.fold<double>(0, (sum, offset) => sum + offset.dy) / count;
        expect(averageX.abs(), lessThan(.001));
        expect(averageY.abs(), lessThan(.001));
        for (var i = 0; i < offsets.length; i++) {
          for (var j = i + 1; j < offsets.length; j++) {
            expect(
              (offsets[i] - offsets[j]).distance,
              greaterThanOrEqualTo(17),
              reason: 'tokens should remain visually distinguishable',
            );
          }
        }
      }
    });

    test('four player start squares align with their matching colored home lanes', () {
      expect(LudoRules.startOffsets, [0, 39, 26, 13]);
      for (var player = 0; player < 4; player++) {
        final start = LudoBoardGeometry.trackCells[LudoRules.trackIndex(player, 0)!];
        final lane = LudoBoardGeometry.homeLanes[player].first;
        final distance = (start.$1 - lane.$1).abs() + (start.$2 - lane.$2).abs();
        expect(distance, 1, reason: 'player $player start must touch its home lane');
      }
    });

    test('premium board geometry has 52 unique track cells and four separate home lanes', () {
      expect(LudoBoardGeometry.trackCells.length, 52);
      expect(LudoBoardGeometry.trackCells.toSet().length, 52);
      expect(LudoBoardGeometry.homeLanes.length, 4);
      for (final lane in LudoBoardGeometry.homeLanes) {
        expect(lane.length, 6);
        expect(lane.toSet().length, 6);
      }
      expect(LudoRules.trackIndex(1, 0, playerCount: 2), 26);
      expect(LudoBoardGeometry.trackCells[0], (13, 6)); // red / bottom
      expect(LudoBoardGeometry.trackCells[13], (6, 1)); // green / left
      expect(LudoBoardGeometry.trackCells[26], (1, 8)); // yellow / top
      expect(LudoBoardGeometry.trackCells[39], (8, 13)); // blue / right
      expect(LudoBoardGeometry.trackCells[24], (0, 7));
    });
  });
}
