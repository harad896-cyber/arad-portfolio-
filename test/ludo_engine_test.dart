import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_engine.dart';

void main() {
  LudoState state2() => createLudoState([
        {'id': 'red', 'color': 'red'},
        {'id': 'yellow', 'color': 'yellow'},
      ]);

  LudoState state4() => createLudoState([
        {'id': 'red'},
        {'id': 'yellow'},
        {'id': 'blue'},
        {'id': 'green'},
      ]);

  group('Ludo engine: state and purity', () {
    test('creates exactly the canonical JSON state shape', () {
      final state = state2();
      expect(state.keys.toSet(), {
        'players',
        'pieces',
        'turn',
        'dice',
        'phase',
        'sixStreak',
        'winners',
      });
      expect(() => jsonEncode(state), returnsNormally);
      expect(isValidLudoState(state), isTrue);
    });

    test('rejects invalid player counts and duplicate IDs', () {
      expect(() => createLudoState([]), throwsArgumentError);
      expect(
        () => createLudoState([
          {'id': 'same'},
          {'id': 'same'},
        ]),
        throwsArgumentError,
      );
      expect(
        () => createLudoState([
          {'id': ''},
          {'id': 'yellow'},
        ]),
        throwsArgumentError,
      );
    });

    test('deep-copies nested player metadata and never mutates input', () {
      final source = state2();
      (source['players'][0] as Map)['profile'] = {'badges': ['one']};
      final before = jsonEncode(source);
      final rolled = applyLudoRoll(source, 6);
      expect(jsonEncode(source), before);
      ((rolled['players'][0] as Map)['profile'] as Map)['badges'].add('two');
      expect(
        ((source['players'][0] as Map)['profile'] as Map)['badges'],
        ['one'],
      );
    });

    test('rejects malformed or internally inconsistent states', () {
      final badPieces = state2()..['pieces'] = [[-1, -1], [-1, -1]];
      expect(isValidLudoState(badPieces), isFalse);

      final badTurn = state2()..['turn'] = 8;
      expect(isValidLudoState(badTurn), isFalse);

      final badPhase = state2()..['phase'] = 'moving';
      expect(isValidLudoState(badPhase), isFalse);

      final badDice = state2()
        ..['phase'] = 'awaiting_move'
        ..['dice'] = {'value': 9};
      expect(isValidLudoState(badDice), isFalse);

      final badWinner = state2()..['winners'] = [0, 0];
      expect(isValidLudoState(badWinner), isFalse);
    });

    test('illegal moves throw and leave the original JSON unchanged', () {
      final rolled = applyLudoRoll(state2(), 6);
      final before = jsonEncode(rolled);
      expect(() => applyLudoMove(rolled, 99), throwsStateError);
      expect(() => applyLudoMove(rolled, 4), throwsStateError);
      expect(jsonEncode(rolled), before);
    });
  });

  group('Ludo engine: route and movement rules', () {
    test('all 52 shared squares are addressable, including square 51', () {
      for (var player = 0; player < 4; player++) {
        expect(
          ludoTrackIndex(player, 0, playerCount: 4),
          ludoStartOffsets[player],
        );
        expect(ludoTrackIndex(player, 51, playerCount: 4), isNotNull);
        expect(ludoTrackIndex(player, 52, playerCount: 4), isNull);
      }
      expect(
        List.generate(
          52,
          (progress) => ludoTrackIndex(0, progress, playerCount: 4),
        ).toSet(),
        hasLength(52),
      );
      expect(ludoTrackIndex(1, 0, playerCount: 2), 26);
      expect(ludoSafeSquares, hasLength(8));
    });

    test('only a six releases a piece from the yard', () {
      final noMove = applyLudoRoll(state2(), 5);
      expect(noMove['turn'], 1);
      expect(noMove['phase'], 'awaiting_roll');

      final six = applyLudoRoll(state2(), 6);
      expect(getLegalMoves(six, 6), [0, 1, 2, 3]);
      final released = applyLudoMove(six, 0);
      expect((released['pieces'] as List)[0], [0, -1, -1, -1]);
    });

    test('a six grants another roll; the third consecutive six burns', () {
      var state = applyLudoRoll(state2(), 6);
      state = applyLudoMove(state, 0);
      expect(state['turn'], 0);
      expect(state['sixStreak'], 1);

      state = applyLudoRoll(state, 6);
      expect(state['sixStreak'], 2);
      state = applyLudoMove(state, 1);
      final third = applyLudoRoll(state, 6);

      expect(third['turn'], 1);
      expect(third['sixStreak'], 0);
      expect((third['dice'] as Map)['burned'], isTrue);
      expect((third['pieces'] as List)[0], [0, 0, -1, -1]);
    });

    test('a non-six resets the six streak even when that move captures', () {
      var state = state2();
      state['pieces'] = [
        [4, -1, -1, -1],
        [31, -1, -1, -1],
      ];
      state['sixStreak'] = 2;
      final rolled = applyLudoRoll(state, 1);
      final captured = applyLudoMove(rolled, 0);
      expect((captured['dice'] as Map)['captured'], [
        {'player': 1, 'piece': 0}
      ]);
      expect(captured['sixStreak'], 0);
      expect(captured['turn'], 0); // capture grants another roll
    });

    test('third six burns the turn without moving a piece', () {
      var state = applyLudoRoll(state2(), 6);
      state = applyLudoMove(state, 0);
      state = applyLudoRoll(state, 6);
      state = applyLudoMove(state, 1);
      final before = jsonEncode(state['pieces']);
      final burned = applyLudoRoll(state, 6);
      expect(jsonEncode(burned['pieces']), before);
      expect(burned['turn'], 1);
      expect(burned['phase'], 'awaiting_roll');
    });

    test('capture sends the opponent to the yard and grants an extra roll', () {
      var state = state2();
      state['pieces'] = [
        [4, -1, -1, -1],
        [31, -1, -1, -1],
      ];
      final rolled = applyLudoRoll(state, 1);
      final moved = applyLudoMove(rolled, 0);
      expect((moved['pieces'] as List)[0][0], 5);
      expect((moved['pieces'] as List)[1][0], -1);
      expect(moved['turn'], 0);
      expect((moved['dice'] as Map)['captured'], [
        {'player': 1, 'piece': 0}
      ]);
    });

    test('safe squares prevent capture', () {
      var state = state2();
      state['pieces'] = [
        [7, -1, -1, -1],
        [34, -1, -1, -1],
      ];
      final moved = applyLudoMove(applyLudoRoll(state, 1), 0);
      expect((moved['pieces'] as List)[1][0], 34);
      expect((moved['pieces'] as List)[1][0], 34);
      expect(moved['turn'], 1);
      expect(moved['phase'], 'awaiting_roll');
    });

    test('a blockade cannot be crossed or landed on', () {
      var state = state2();
      state['pieces'] = [
        [3, -1, -1, -1],
        [31, 31, -1, -1],
      ];
      final rolled = applyLudoRoll(state, 2);
      expect(rolled['turn'], 1);
      expect((rolled['dice'] as Map)['reason'], 'no_legal_move');
    });

    test('exact roll is required to enter the center', () {
      var state = state2();
      state['pieces'] = [
        [56, 57, 57, 57],
        [-1, -1, -1, -1],
      ];
      final tooFar = applyLudoRoll(state, 2);
      expect(tooFar['turn'], 1);
      expect((tooFar['pieces'] as List)[0][0], 56);

      final exactState = state2()
        ..['pieces'] = [
          [56, 57, 57, 57],
          [-1, -1, -1, -1],
        ];
      expect(isValidLudoState(exactState), isTrue);
      final exact = applyLudoRoll(exactState, 1);
      expect(exact['phase'], 'awaiting_move');
      expect((exact['dice'] as Map)['legalMoves'], [0]);
      expect(getLegalMoves(exact, 1), [0]);
      final won = applyLudoMove(exact, 0);
      expect((won['pieces'] as List)[0][0], 57);
      expect(won['winners'], [0]);
    });

    test('home-lane pieces do not capture pieces on the shared route', () {
      var state = state2();
      state['pieces'] = [
        [52, -1, -1, -1],
        [0, -1, -1, -1],
      ];
      final moved = applyLudoMove(applyLudoRoll(state, 1), 0);
      expect((moved['pieces'] as List)[1][0], 0);
      expect((moved['pieces'] as List)[0][0], 53);
    });

    test('no legal move automatically passes and records a reason', () {
      final passed = applyLudoRoll(state2(), 3);
      expect(passed['turn'], 1);
      expect(passed['phase'], 'awaiting_roll');
      expect((passed['dice'] as Map)['legalMoves'], isEmpty);
      expect((passed['dice'] as Map)['reason'], 'no_legal_move');
    });

    test('a six with no legal move keeps the turn for another roll', () {
      var state = state2();
      state['pieces'] = [
        [-1, -1, -1, -1],
        [26, 26, -1, -1],
      ];
      final result = applyLudoRoll(state, 6);
      expect(result['turn'], 0);
      expect(result['phase'], 'awaiting_roll');
      expect(result['sixStreak'], 1);
      expect((result['dice'] as Map)['extraRoll'], isTrue);
      expect((result['dice'] as Map)['reason'], 'no_legal_move');
    });
  });

  group('Ludo engine: turn order and ranking', () {
    test('capture and six never grant two extra rolls', () {
      var state = state2();
      state['pieces'] = [
        [4, -1, -1, -1],
        [36, -1, -1, -1],
      ];
      final rolled = applyLudoRoll(state, 6);
      final moved = applyLudoMove(rolled, 0);
      expect(moved['turn'], 0);
      expect(moved['phase'], 'awaiting_roll');
      expect((moved['dice'] as Map)['captured'], [
        {'player': 1, 'piece': 0}
      ]);
    });

    test('a player who completes all four pieces is removed from turn rotation', () {
      var state = state4();
      state['pieces'] = [
        [57, 57, 57, 56],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ];
      final moved = applyLudoMove(applyLudoRoll(state, 1), 3);
      expect(moved['winners'], [0]);
      expect(moved['turn'], 1);
      expect(moved['phase'], 'awaiting_roll');
      expect(moved['sixStreak'], 0);
    });

    test('game continues until all but the final player are ranked', () {
      var state = state4();
      state['pieces'] = [
        [57, 57, 57, 57],
        [57, 57, 57, 56],
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ];
      state['winners'] = [0];
      state['turn'] = 1;
      final second = applyLudoMove(applyLudoRoll(state, 1), 3);
      expect(second['winners'], [0, 1]);
      expect(second['phase'], 'awaiting_roll');
      expect(second['turn'], 2);
    });

    test('the game ends when all but one player have a rank', () {
      var state = state4();
      state['pieces'] = [
        [57, 57, 57, 57],
        [57, 57, 57, 57],
        [57, 57, 57, 56],
        [-1, -1, -1, -1],
      ];
      state['winners'] = [0, 1];
      state['turn'] = 2;
      final third = applyLudoMove(applyLudoRoll(state, 1), 3);
      expect(third['winners'], [0, 1, 2]);
      expect(third['phase'], 'finished');
    });
  });

  test('10,000 deterministic bot-vs-bot games do not deadlock', () {
    final random = Random(20261115);
    for (var game = 0; game < 10000; game++) {
      var state = state4();
      var actions = 0;
      while (state['phase'] != 'finished' && actions < 5000) {
        actions++;
        if (state['phase'] == 'awaiting_roll') {
          state = applyLudoRoll(state, random.nextInt(6) + 1);
        } else {
          final legal = currentLegalMoves(state);
          expect(legal, isNotEmpty, reason: 'game $game action $actions');
          state = applyLudoMove(state, legal[random.nextInt(legal.length)]);
        }
        expect(isValidLudoState(state), isTrue,
            reason: 'invalid state in game $game action $actions');
      }
      expect(state['phase'], 'finished',
          reason: 'game $game exceeded $actions actions');
      expect((state['winners'] as List).length, 3);
    }
  });
}
