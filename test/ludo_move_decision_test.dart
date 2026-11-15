import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_engine.dart';
import 'package:arad_messenger/ludo_move_decision.dart';

void main() {
  LudoState base() => createLudoState([
    {'id': 'red'}, {'id': 'yellow'}
  ]);

  LudoState rolled(List<List<int>> positions, int dice) {
    final s = base();
    s['pieces'] = positions;
    s['phase'] = 'awaiting_move';
    s['dice'] = {'value': dice};
    return s;
  }

  group('authoritative legal move analysis', () {
    test('yard pieces require a six and every rejected piece has a reason', () {
      final result = getLegalMoveAnalysis(rolled([
        [-1, -1, -1, -1], [-1, -1, -1, -1]
      ], 3), 3);
      expect(result.legalMoves, isEmpty);
      expect(result.rejections, hasLength(4));
      expect(result.rejections.map((r) => r.reasonCode), everyElement('needs_six'));
    });

    test('six releases each yard piece with an explicit exit path', () {
      final result = getLegalMoveAnalysis(rolled([
        [-1, -1, -1, -1], [-1, -1, -1, -1]
      ], 6), 6);
      expect(result.legalMoves, hasLength(4));
      expect(result.legalMoves.first.to, 0);
      expect(result.legalMoves.first.path, [0]);
      expect(result.legalMoves.first.exits, isTrue);
    });

    test('path and exact home entry are calculated correctly for all dice values', () {
      for (var dice = 1; dice <= 6; dice++) {
        final valid = getLegalMoveAnalysis(rolled([
          [56, -1, -1, -1], [-1, -1, -1, -1]
        ], dice), dice);
        expect(valid.legalMoves.isNotEmpty, dice == 1);
        if (dice == 1) {
          expect(valid.legalMoves.single.to, 57);
          expect(valid.legalMoves.single.entersHome, isTrue);
        } else {
          expect(valid.rejections.first.reasonCode, 'overshoot_home');
        }
      }
    });

    test('table-driven yard, track and home-lane rules cover dice 1 through 6', () {
      for (var dice = 1; dice <= 6; dice++) {
        final yard = getLegalMoveAnalysis(rolled([
          [-1, -1, -1, -1], [-1, -1, -1, -1]
        ], dice), dice);
        expect(yard.legalMoves.isNotEmpty, dice == 6);

        final track = getLegalMoveAnalysis(rolled([
          [10, -1, -1, -1], [-1, -1, -1, -1]
        ], dice), dice);
        expect(track.legalMoves.map((m) => m.to), contains(10 + dice));

        final homeLaneProgress = 51 + (6 - dice);
        final homeLane = getLegalMoveAnalysis(rolled([
          [homeLaneProgress, -1, -1, -1], [-1, -1, -1, -1]
        ], dice), dice);
        expect(homeLane.legalMoves.single.to, 57);
        expect(homeLane.legalMoves.single.entersHome, isTrue);
      }
    });

    test('safe squares retain both pieces and suppress capture metadata', () {
      final result = getLegalMoveAnalysis(rolled([
        [7, -1, -1, -1], [34, -1, -1, -1]
      ], 1), 1);
      final move = result.legalMoves.single;
      expect(move.landsOnSafeSquare, isTrue);
      expect(move.captures, isEmpty);
    });

    test('ordinary landing reports opponent captures without mutating state', () {
      final s = rolled([[4, -1, -1, -1], [31, -1, -1, -1]], 1);
      final before = (s['pieces'] as List).map((r) => List<int>.from(r)).toList();
      final move = getLegalMoveAnalysis(s, 1).legalMoves.single;
      expect(move.captures, [{'player': 1, 'piece': 0}]);
      expect(s['pieces'], before);
    });

    test('a two-piece blockade rejects the move with a useful reason', () {
      final result = getLegalMoveAnalysis(rolled([
        [3, -1, -1, -1], [31, 31, -1, -1]
      ], 2), 2);
      expect(result.legalMoves, isEmpty);
      expect(result.rejections.single.reasonCode, 'blocked');
    });

    test('blockade passing and own-stack rules are configurable', () {
      final blocked = rolled([[3, -1, -1, -1], [31, 31, -1, -1]], 2);
      expect(getLegalMoveAnalysis(blocked, 2,
        rules: const LudoMoveRules(blockadesBlockMovement: false)
      ).legalMoves, hasLength(1));

      final stacked = rolled([[4, 5, 57, 57], [-1, -1, -1, -1]], 1);
      expect(getLegalMoveAnalysis(stacked, 1,
        rules: const LudoMoveRules(allowOwnStack: true)
      ).legalMoves, hasLength(1));
      expect(getLegalMoveAnalysis(stacked, 1,
        rules: const LudoMoveRules(allowOwnStack: false)
      ).legalMoves, isEmpty);
    });
  });

  group('automatic move decision', () {
    test('zero moves waits one second and preserves extra-roll on six', () {
      final s = rolled([[-1, -1, -1, -1], [-1, -1, -1, -1]], 6);
      final a = getLegalMoveAnalysis(s, 6);
      final d = decideLudoMove(s, 6, a);
      expect(d.kind, LudoAutoMoveKind.noMove);
      expect(d.delay, const Duration(seconds: 1));
      expect(d.retainTurn, isTrue);
    });

    test('zero moves on non-six advances turn after the same delay', () {
      final s = rolled([[-1, -1, -1, -1], [-1, -1, -1, -1]], 2);
      final d = decideLudoMove(s, 2, getLegalMoveAnalysis(s, 2));
      expect(d.kind, LudoAutoMoveKind.noMove);
      expect(d.retainTurn, isFalse);
    });

    test('one legal move is automatic after 400ms by default', () {
      final s = rolled([[10, 56, 57, 57], [-1, -1, -1, -1]], 2);
      final d = decideLudoMove(s, 2, getLegalMoveAnalysis(s, 2));
      expect(d.kind, LudoAutoMoveKind.automatic);
      expect(d.delay, const Duration(milliseconds: 400));
      expect(d.move!.pieceId, 'red:0');
    });

    test('manual-selection setting can disable single-move auto play', () {
      final s = rolled([[10, 57, 57, 57], [-1, -1, -1, -1]], 2);
      final d = decideLudoMove(s, 2, getLegalMoveAnalysis(s, 2),
        autoMoveSingle: false);
      expect(d.kind, LudoAutoMoveKind.manual);
    });

    test('multiple different moves require manual selection', () {
      final s = rolled([[5, 10, 57, 57], [-1, -1, -1, -1]], 2);
      final d = decideLudoMove(s, 2, getLegalMoveAnalysis(s, 2));
      expect(d.kind, LudoAutoMoveKind.manual);
    });

    test('equivalent moves from stacked pieces auto-select deterministically', () {
      final s = rolled([[5, 5, 57, 57], [-1, -1, -1, -1]], 2);
      final a = getLegalMoveAnalysis(s, 2);
      expect(a.legalMoves, hasLength(2));
      final d = decideLudoMove(s, 2, a);
      expect(d.kind, LudoAutoMoveKind.automatic);
      expect(d.reason, 'equivalent_moves');
      expect(d.move!.pieceId, 'red:0');
    });

    test('last remaining piece and fast-game mode always auto-select', () {
      final s = rolled([[5, 57, 57, 57], [-1, -1, -1, -1]], 2);
      expect(decideLudoMove(s, 2, getLegalMoveAnalysis(s, 2),
        autoMoveSingle: false).kind, LudoAutoMoveKind.automatic);
      final multi = rolled([[5, 10, 57, 57], [-1, -1, -1, -1]], 2);
      expect(decideLudoMove(multi, 2, getLegalMoveAnalysis(multi, 2),
        fastGame: true).kind, LudoAutoMoveKind.automatic);
    });
  });
}
