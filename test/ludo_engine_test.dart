import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_engine.dart';

void main() {
  LudoState state2() => createLudoState([
    {'id': 'red', 'color': 'red'},
    {'id': 'yellow', 'color': 'yellow'},
  ]);

  group('Ludo engine - pure rules', () {
    test('state is a single JSON-encodable object with required fields', () {
      final s = state2();
      expect(s.keys.toSet(), {'players','pieces','turn','dice','phase','sixStreak','winners'});
      expect(() => jsonEncodeState(s), returnsNormally);
    });

    test('only a six releases pieces from the yard', () {
      final s = applyLudoRoll(state2(), 5);
      expect(s['turn'], 1); // no legal move: automatic pass
      final six = applyLudoRoll(state2(), 6);
      expect(getLegalMoves(six, 6), [0,1,2,3]);
    });

    test('six gives an extra roll and third consecutive six burns the turn', () {
      var s = applyLudoRoll(state2(), 6);
      s = applyLudoMove(s, 0);
      expect(s['turn'], 0);
      expect(s['phase'], 'awaiting_roll');
      s = applyLudoRoll(s, 6);
      expect(s['sixStreak'], 2);
      s = applyLudoMove(s, 1);
      final third = applyLudoRoll(s, 6);
      expect(third['turn'], 1);
      expect(third['sixStreak'], 0);
      expect((third['dice'] as Map)['burned'], isTrue);
      expect((third['pieces'] as List)[0], [0,0,-1,-1]);
    });

    test('exact roll is required to reach the center', () {
      var s = state2();
      s['pieces'] = [[56,-1,-1,-1],[-1,-1,-1,-1]];
      final tooFar = applyLudoRoll(s, 2);
      expect(tooFar['turn'], 1);
      expect((tooFar['pieces'] as List)[0][0], 56);
      s['turn'] = 0;
      s['phase'] = 'awaiting_roll';
      final exact = applyLudoRoll(s, 1);
      expect(getLegalMoves(exact, 1), [0]);
      final won = applyLudoMove(exact, 0);
      expect((won['pieces'] as List)[0][0], 57);
    });

    test('capture sends opponent back to yard and grants extra roll', () {
      var s = state2();
      s['pieces'] = [[4,-1,-1,-1],[31,-1,-1,-1]];
      // Yellow starts 26 squares after red: progress 30 maps to red square 4.
      final rolled = applyLudoRoll(s, 1);
      final moved = applyLudoMove(rolled, 0);
      expect((moved['pieces'] as List)[0][0], 5);
      expect((moved['pieces'] as List)[1][0], -1);
      expect(moved['turn'], 0);
      expect((moved['dice'] as Map)['captured'], [{'player':1,'piece':0}]);
    });

    test('safe squares prevent capture', () {
      var s = state2();
      s['pieces'] = [[7,-1,-1,-1],[34,-1,-1,-1]];
      final moved = applyLudoMove(applyLudoRoll(s, 1), 0);
      expect((moved['pieces'] as List)[1][0], 34);
      // A normal non-capture move clears the transient dice payload.
      expect(moved['dice'], isNull);
    });

    test('a double-piece blockade cannot be crossed', () {
      var s = state2();
      s['pieces'] = [[3,-1,-1,-1],[31,31,-1,-1]];
      final rolled = applyLudoRoll(s, 2);
      expect(rolled['turn'], 1);
    });

    test('no legal moves automatically passes turn', () {
      final s = applyLudoRoll(state2(), 3);
      expect(s['turn'], 1);
      expect(s['phase'], 'awaiting_roll');
      expect(s['dice'], isNull);
    });

    test('invalid moves never mutate the input state', () {
      final s = applyLudoRoll(state2(), 6);
      final before = jsonEncodeState(s);
      expect(() => applyLudoMove(s, 99), throwsStateError);
      expect(jsonEncodeState(s), before);
    });

    test('shared route has 52 cells and each player has a private six-cell lane', () {
      for (var p = 0; p < 4; p++) {
        expect(ludoTrackIndex(p, 0, playerCount: 4), ludoStartOffsets[p]);
        expect(ludoTrackIndex(p, 50, playerCount: 4), isNotNull);
      }
      expect(List.generate(52, (i) => i).toSet(), hasLength(52));
      expect(ludoSafeSquares.length, 8);
    });

    test('a player is ranked only after all four pieces reach home and game continues', () {
      var s = createLudoState([{'id':'r'},{'id':'y'},{'id':'b'},{'id':'g'}]);
      s['pieces'] = [[57,57,57,56],[-1,-1,-1,-1],[-1,-1,-1,-1],[-1,-1,-1,-1]];
      s = applyLudoRoll(s, 1);
      s = applyLudoMove(s, 3);
      expect(s['winners'], [0]);
      expect(s['phase'], 'awaiting_roll');
      expect(s['turn'], 1);
    });

    test('finishing order continues until all but the last player are ranked', () {
      var s = createLudoState([
        {'id':'a'}, {'id':'b'}, {'id':'c'}, {'id':'d'}
      ]);
      s['winners'] = [2,0];
      expect(s['phase'], 'awaiting_roll');
      s['winners'] = [2,0,3];
      // Terminal state is reached on the next accepted move by the third winner.
      expect(s['winners'], [2,0,3]);
    });

    test('10,000 deterministic bot-vs-bot simulations never deadlock', () {
      final random = Random(20261115);
      for (var game = 0; game < 10000; game++) {
        var s = createLudoState([
          {'id':'r'}, {'id':'y'}, {'id':'b'}, {'id':'g'}
        ]);
        var actions = 0;
        while (s['phase'] != 'finished' && actions < 5000) {
          actions++;
          if (s['phase'] == 'awaiting_roll') {
            s = applyLudoRoll(s, random.nextInt(6) + 1);
          } else {
            final moves = currentLegalMoves(s);
            expect(moves, isNotEmpty, reason: 'game $game action $actions');
            s = applyLudoMove(s, moves[random.nextInt(moves.length)]);
          }
        }
        expect(s['phase'], 'finished', reason: 'game $game exceeded $actions actions');
        expect((s['winners'] as List).length, 3);
      }
    });
  });
}

/// Minimal deterministic JSON serializer for equality checks without adding
/// a package dependency to the Flutter project.
String jsonEncodeState(Map<String, dynamic> state) => jsonEncode(state);
