import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/quick_games/game_sdk.dart';
import 'package:arad_messenger/quick_games/tic_tac_toe.dart';

void main() {
  const game = TicTacToeGame();
  const players = [
    GamePlayer(id: 'alice', displayName: 'علی'),
    GamePlayer(id: 'bob', displayName: 'سارا'),
  ];

  TicTacToeState play(
    TicTacToeVariant variant,
    List<int> moves,
  ) {
    var state = game.init(players, variant: variant);
    var player = 'alice';
    for (final move in moves) {
      state = game.applyMove(state, player, move);
      if (!state.isFinished) player = player == 'alice' ? 'bob' : 'alice';
    }
    return state;
  }

  group('Game SDK', () {
    test('registry registers and resolves a game module', () {
      final registry = GameRegistry.instance;
      registerTicTacToe(registry);
      expect(registry.contains(TicTacToeGame.gameId), isTrue);
      expect(
        registry.get<TicTacToeState, int>(TicTacToeGame.gameId).id,
        TicTacToeGame.gameId,
      );
      registry.unregisterForTesting(TicTacToeGame.gameId);
    });

    test('registry rejects duplicate registrations', () {
      final registry = GameRegistry.instance;
      registerTicTacToe(registry);
      expect(
        () => registry.register<TicTacToeState, int>(game),
        throwsStateError,
      );
      registry.unregisterForTesting(TicTacToeGame.gameId);
    });
  });

  group('TicTacToe classic 3x3', () {
    test('initializes a 3x3 board and exposes only legal cells', () {
      final state = game.init(players);
      expect(state.board, List<int?>.filled(9, null));
      expect(game.getLegalMoves(state, 'alice'), List.generate(9, (i) => i));
      expect(game.getLegalMoves(state, 'bob'), isEmpty);
    });

    test('detects horizontal, vertical and both diagonal wins', () {
      final cases = <List<int>>[
        [0, 3, 1, 4, 2],
        [0, 1, 3, 2, 6],
        [0, 1, 4, 2, 8],
        [2, 0, 4, 1, 6],
      ];
      for (final moves in cases) {
        final state = play(TicTacToeVariant.classic3x3, moves);
        expect(game.getResult(state).status, GameStatus.won);
        expect(game.getResult(state).winnerId, 'alice');
      }
    });

    test('detects a full-board draw', () {
      final state = play(
        TicTacToeVariant.classic3x3,
        [0, 1, 2, 4, 3, 5, 7, 6, 8],
      );
      expect(game.getResult(state).status, GameStatus.draw);
    });

    test('rejects occupied cells, out-of-range cells and wrong turns', () {
      final state = game.init(players);
      expect(() => game.applyMove(state, 'bob', 0), throwsStateError);
      final afterFirst = game.applyMove(state, 'alice', 0);
      expect(() => game.applyMove(afterFirst, 'bob', 0), throwsStateError);
      expect(() => game.applyMove(afterFirst, 'bob', -1), throwsStateError);
      expect(() => game.applyMove(afterFirst, 'bob', 9), throwsStateError);
      expect(afterFirst.board[0], 0);
      expect(afterFirst.moveCount, 1);
    });

    test('finished game rejects all further moves', () {
      final state = play(TicTacToeVariant.classic3x3, [0, 3, 1, 4, 2]);
      expect(() => game.applyMove(state, 'bob', 5), throwsStateError);
      expect(game.getLegalMoves(state, 'bob'), isEmpty);
    });
  });

  group('TicTacToe bonus 5x5 connect four', () {
    test('detects horizontal, vertical and diagonal four-in-a-row', () {
      final horizontal = play(
        TicTacToeVariant.bonus5x5,
        [0, 5, 1, 6, 2, 7, 3],
      );
      final vertical = play(
        TicTacToeVariant.bonus5x5,
        [0, 1, 5, 2, 10, 3, 15],
      );
      final diagonal = play(
        TicTacToeVariant.bonus5x5,
        [0, 1, 6, 2, 12, 3, 18],
      );
      expect(game.getResult(horizontal).winnerId, 'alice');
      expect(game.getResult(vertical).winnerId, 'alice');
      expect(game.getResult(diagonal).winnerId, 'alice');
    });

    test('rejects a three-in-a-row as a win in 5x5 mode', () {
      final state = play(TicTacToeVariant.bonus5x5, [0, 5, 1, 6, 2]);
      expect(game.getResult(state).status, GameStatus.active);
    });
  });

  group('Serialization contract', () {
    test('round trips state and remains below 2 KB', () {
      final state = play(TicTacToeVariant.bonus5x5, [0, 5, 1, 6, 2]);
      final encoded = game.serialize(state);
      final restored = game.deserialize(encoded);
      expect(restored.board, state.board);
      expect(restored.currentPlayer, state.currentPlayer);
      expect(restored.moveCount, state.moveCount);
      expect(restored.variant, state.variant);
      expect(encoded.length, lessThan(2048));
    });

    test('rejects unknown schema versions and malformed states', () {
      final json = game.toJson(game.init(players));
      json['schemaVersion'] = 99;
      expect(() => game.fromJson(json), throwsFormatException);
      final invalid = game.toJson(game.init(players));
      invalid['board'] = [0, 0];
      expect(() => game.fromJson(invalid), throwsFormatException);
    });

    test('state objects do not expose mutable board collections', () {
      final state = game.init(players);
      expect(() => state.board[0] = 1, throwsUnsupportedError);
    });
  });
}
