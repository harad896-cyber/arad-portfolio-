import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_engine.dart';
import 'package:arad_messenger/ludo_move_decision.dart';

void main() {
  LudoState baseState() => createLudoState([
    {'id': 'red'}, {'id': 'yellow'},
  ]);

  LudoState pending({
    required List<int> red,
    List<int>? yellow,
    int dice = 1,
  }) {
    final state = baseState()
      ..['pieces'] = [red, yellow ?? [-1, -1, -1, -1]]
      ..['turn'] = 0
      ..['phase'] = 'awaiting_move'
      ..['dice'] = {'value': dice, 'burned': false}
      ..['sixStreak'] = dice == 6 ? 1 : 0;
    return state;
  }

  group('Detailed legal move analysis', () {
    test('yard, shared route and final lane are checked for every die value', () {
      for (var dice = 1; dice <= 6; dice++) {
        final yard = getLegalMoveAnalysis(
          pending(red: [-1, -1, -1, -1], dice: dice), dice,
        );
        expect(
          yard.legalMoves.length,
          dice == 6 ? 4 : 0,
          reason: 'yard with die $dice',
        );

        final shared = getLegalMoveAnalysis(
          pending(red: [10, 57, 57, 57], dice: dice), dice,
        );
        expect(shared.legalMoves.map((move) => move.pieceIndex), [0],
            reason: 'shared route with die $dice');

        final finalLane = getLegalMoveAnalysis(
          pending(red: [52, 57, 57, 57], dice: dice), dice,
        );
        expect(
          finalLane.legalMoves.map((move) => move.pieceIndex),
          dice <= 5 ? [0] : isEmpty,
          reason: 'final lane with die $dice',
        );
      }
    });

    test('yard pieces require a six and report a reason for every rejected piece', () {
      final analysis = getLegalMoveAnalysis(
        pending(red: [-1, -1, -1, -1], dice: 3), 3,
      );
      expect(analysis.legalMoves, isEmpty);
      expect(analysis.rejectedMoves, hasLength(4));
      expect(analysis.rejectedMoves.every(
        (move) => move.code == LudoMoveRejectCode.needsSix &&
            move.message.contains('۶'),
      ), isTrue);
    });

    test('six releases a piece with an explicit exit path', () {
      final analysis = getLegalMoveAnalysis(
        pending(red: [-1, -1, -1, -1], dice: 6), 6,
      );
      expect(analysis.legalMoves, hasLength(4));
      expect(analysis.legalMoves.first.exits, isTrue);
      expect(analysis.legalMoves.first.path, [0]);
      expect(analysis.legalMoves.first.to, 0);
    });

    test('normal route movement returns every traversed progress square', () {
      final analysis = getLegalMoveAnalysis(
        pending(red: [4, -1, -1, -1]), 1,
      );
      expect(analysis.legalMoves.single.path, [5]);
      expect(analysis.legalMoves.single.from, 4);
      expect(analysis.legalMoves.single.to, 5);
    });

    test('overshooting the center is rejected with an exact-finish reason', () {
      final analysis = getLegalMoveAnalysis(
        pending(red: [56, 57, 57, 57], dice: 2), 2,
      );
      expect(analysis.legalMoves, isEmpty);
      expect(analysis.rejectedMoves.first.code,
          LudoMoveRejectCode.overshootsCenter);
    });

    test('exact finish enters the home center', () {
      final analysis = getLegalMoveAnalysis(
        pending(red: [56, 57, 57, 57]), 1,
      );
      expect(analysis.legalMoves.single.to, 57);
      expect(analysis.legalMoves.single.entersHome, isTrue);
      expect(analysis.legalMoves.single.reachesCenter, isTrue);
    });

    test('captures an opponent on an unsafe shared square', () {
      final analysis = getLegalMoveAnalysis(
        pending(red: [4, -1, -1, -1], yellow: [31, -1, -1, -1]),
        1,
      );
      expect(analysis.legalMoves.single.captures, hasLength(1));
      expect(analysis.legalMoves.single.captures.single.playerIndex, 1);
      expect(analysis.legalMoves.single.captures.single.pieceIndex, 0);
    });

    test('safe squares never produce capture targets', () {
      final analysis = getLegalMoveAnalysis(
        pending(red: [7, -1, -1, -1], yellow: [34, -1, -1, -1]),
        1,
      );
      expect(analysis.legalMoves.single.landsOnSafeSquare, isTrue);
      expect(analysis.legalMoves.single.captures, isEmpty);
    });

    test('friendly blockade blocks the path', () {
      final analysis = getLegalMoveAnalysis(
        pending(red: [2, -1, -1, -1], yellow: [30, 30, -1, -1], dice: 3),
        3,
      );
      expect(analysis.legalMoves, isEmpty);
      expect(analysis.rejectedMoves.first.code,
          LudoMoveRejectCode.blockedPath);
    });

    test('blockade pass option allows crossing but not landing on blockade', () {
      final state = pending(
        red: [2, -1, -1, -1], yellow: [30, 30, -1, -1], dice: 3,
      );
      final crossed = getLegalMoveAnalysis(
        state, 3,
        rules: const LudoMoveRules(allowPassBlockades: true),
      );
      expect(crossed.legalMoves, hasLength(1));

      final landsOnBlock = getLegalMoveAnalysis(
        pending(red: [1, -1, -1, -1], yellow: [30, 30, -1, -1], dice: 3),
        3,
        rules: const LudoMoveRules(allowPassBlockades: true),
      );
      expect(landsOnBlock.legalMoves, isEmpty);
    });

    test('roll calculation uses the configured blockade passing rule', () {
      final state = baseState()
        ..['pieces'] = [
          [2, -1, -1, -1],
          [30, 30, -1, -1],
        ];
      final strict = applyLudoRoll(state, 3);
      expect(strict['turn'], 0);
      expect(strict['phase'], 'awaiting_move');
      expect(getLegalMoves(strict, 3), isEmpty);
      final passed = applyLudoNoMoveDecision(strict);
      expect(passed['turn'], 1);
      expect(passed['phase'], 'awaiting_roll');

      final passing = applyLudoRoll(state, 3, allowPassBlockades: true);
      expect(passing['turn'], 0);
      expect(passing['phase'], 'awaiting_move');
      expect(getLegalMoves(passing, 3, allowPassBlockades: true), [0]);
      expect(() => applyLudoMove(passing, 0), throwsStateError);
      final applied = applyLudoMove(
        passing, 0, allowPassBlockades: true,
      );
      expect((applied['pieces'] as List)[0][0], 5);
    });

    test('own stack is configurable and authoritative move validation agrees', () {
      final stackState = pending(red: [4, 5, 57, 57], dice: 1);
      final strict = getLegalMoveAnalysis(stackState, 1);
      expect(strict.legalMoves.map((move) => move.pieceIndex), [1]);
      expect(strict.rejectedMoves.firstWhere((move) => move.pieceIndex == 0).code,
          LudoMoveRejectCode.ownPieceAtDestination);
      expect(getLegalMoves(stackState, 1), [1]);
      expect(() => applyLudoMove(stackState, 0), throwsStateError);

      final stacking = getLegalMoveAnalysis(
        stackState, 1,
        rules: const LudoMoveRules(allowOwnStack: true),
      );
      expect(stacking.legalMoves.map((move) => move.pieceIndex), [0, 1]);
      expect(getLegalMoves(stackState, 1, allowOwnStack: true), [0, 1]);
      final applied = applyLudoMove(stackState, 0, allowOwnStack: true);
      expect((applied['pieces'] as List)[0][0], 5);
      expect((applied['pieces'] as List)[0][1], 5);
    });

    test('rejects a stale or mismatched dice value', () {
      final analysis = getLegalMoveAnalysis(
        pending(red: [4, -1, -1, -1], dice: 2), 1,
      );
      expect(analysis.isValid, isFalse);
      expect(analysis.error, isNotNull);
    });

    test('analysis never mutates the source state', () {
      final state = pending(red: [4, -1, -1, -1]);
      final before = state.toString();
      getLegalMoveAnalysis(state, 1);
      expect(state.toString(), before);
    });
  });

  group('Automatic move decision', () {
    test('zero legal moves passes the turn on a non-six', () {
      final state = pending(red: [-1, -1, -1, -1], dice: 3);
      final analysis = getLegalMoveAnalysis(state, 3);
      final decision = decideLudoMove(state, analysis);
      expect(decision.action, LudoAutoAction.passTurn);
      expect(decision.delay, const Duration(seconds: 1));
    });

    test('zero legal moves on a six requests another roll', () {
      final state = pending(red: [-1, -1, -1, -1], dice: 6);
      final noMoves = const LudoMoveAnalysis(
        legalMoves: [], rejectedMoves: [],
      );
      final decision = decideLudoMove(state, noMoves);
      expect(decision.action, LudoAutoAction.repeatRoll);
      expect(decision.delay, const Duration(seconds: 1));
    });

    test('one legal move is automatic by default', () {
      final state = pending(red: [5, -1, -1, -1]);
      final analysis = getLegalMoveAnalysis(state, 1);
      final decision = decideLudoMove(state, analysis);
      expect(decision.action, LudoAutoAction.moveAutomatically);
      expect(decision.move!.pieceIndex, 0);
      expect(decision.delay, const Duration(milliseconds: 400));
    });

    test('single-move auto can be disabled for manual selection', () {
      final state = pending(red: [5, -1, -1, -1]);
      final decision = decideLudoMove(
        state, getLegalMoveAnalysis(state, 1),
        autoMoveSinglePiece: false,
      );
      expect(decision.action, LudoAutoAction.askPlayer);
    });

    test('only one unfinished piece remains: it is always automatic', () {
      final state = pending(red: [57, 57, 57, 5]);
      final decision = decideLudoMove(
        state, getLegalMoveAnalysis(state, 1),
        autoMoveSinglePiece: false,
      );
      expect(decision.action, LudoAutoAction.moveAutomatically);
      expect(decision.move!.pieceIndex, 3);
    });

    test('four equivalent yard exits automatically choose a stable piece', () {
      final state = pending(red: [-1, -1, -1, -1], dice: 6);
      final decision = decideLudoMove(
        state, getLegalMoveAnalysis(state, 6),
      );
      expect(decision.action, LudoAutoAction.moveAutomatically);
      expect(decision.move!.pieceIndex, 0);
    });

    test('different legal paths require player selection', () {
      final state = pending(red: [2, 10, -1, -1], dice: 1);
      final decision = decideLudoMove(
        state, getLegalMoveAnalysis(state, 1),
      );
      expect(decision.action, LudoAutoAction.askPlayer);
    });
  });
}
