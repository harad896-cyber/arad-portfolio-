import 'dart:collection';

import 'game_sdk.dart';

enum TicTacToeVariant {
  classic3x3(size: 3, connect: 3),
  bonus5x5(size: 5, connect: 4);

  const TicTacToeVariant({required this.size, required this.connect});
  final int size;
  final int connect;

  String get wireName => switch (this) {
    TicTacToeVariant.classic3x3 => 'classic_3x3',
    TicTacToeVariant.bonus5x5 => 'bonus_5x5',
  };

  static TicTacToeVariant parse(Object? value) {
    return switch (value) {
      'classic_3x3' => TicTacToeVariant.classic3x3,
      'bonus_5x5' => TicTacToeVariant.bonus5x5,
      _ => throw const FormatException('Unknown tic-tac-toe variant.'),
    };
  }
}

class TicTacToeState {
  final TicTacToeVariant variant;
  final List<GamePlayer> players;
  final List<int?> board;
  final int currentPlayer;
  final int moveCount;
  final String? winnerId;

  TicTacToeState({
    required this.variant,
    required List<GamePlayer> players,
    required List<int?> board,
    required this.currentPlayer,
    required this.moveCount,
    this.winnerId,
  }) : players = List.unmodifiable(players),
       board = List.unmodifiable(board);

  bool get isDraw => winnerId == null && moveCount == board.length;
  bool get isFinished => winnerId != null || isDraw;
  String get currentPlayerId => players[currentPlayer].id;
}

class TicTacToeGame implements GameModule<TicTacToeState, int> {
  const TicTacToeGame();

  static const gameId = 'tic_tac_toe';
  static const currentSchemaVersion = 1;

  @override
  String get id => gameId;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  TicTacToeState init(List<GamePlayer> players, {
    TicTacToeVariant variant = TicTacToeVariant.classic3x3,
  }) {
    _validatePlayers(players);
    return TicTacToeState(
      variant: variant,
      players: players,
      board: List<int?>.filled(variant.size * variant.size, null),
      currentPlayer: 0,
      moveCount: 0,
    );
  }

  @override
  List<int> getLegalMoves(TicTacToeState state, String playerId) {
    _validateState(state);
    if (state.isFinished || state.currentPlayerId != playerId) {
      return const [];
    }
    return List<int>.unmodifiable([
      for (var i = 0; i < state.board.length; i++)
        if (state.board[i] == null) i,
    ]);
  }

  @override
  TicTacToeState applyMove(
    TicTacToeState state,
    String playerId,
    int move,
  ) {
    _validateState(state);
    if (state.isFinished) throw StateError('Game is already finished.');
    if (state.currentPlayerId != playerId) {
      throw StateError('It is not this player\'s turn.');
    }
    if (move < 0 || move >= state.board.length || state.board[move] != null) {
      throw StateError('Illegal tic-tac-toe move.');
    }

    final nextBoard = List<int?>.from(state.board);
    nextBoard[move] = state.currentPlayer;
    final nextMoveCount = state.moveCount + 1;
    final won = _hasWinningLine(nextBoard, state.variant, state.currentPlayer);
    final nextPlayer = won || nextMoveCount == nextBoard.length
        ? state.currentPlayer
        : 1 - state.currentPlayer;

    return TicTacToeState(
      variant: state.variant,
      players: state.players,
      board: nextBoard,
      currentPlayer: nextPlayer,
      moveCount: nextMoveCount,
      winnerId: won ? playerId : null,
    );
  }

  @override
  GameResult getResult(TicTacToeState state) {
    _validateState(state);
    if (state.winnerId != null) return GameResult.won(state.winnerId!);
    if (state.isDraw) return const GameResult.draw();
    return const GameResult.active();
  }

  @override
  Map<String, dynamic> toJson(TicTacToeState state) {
    _validateState(state);
    return {
      'game': id,
      'schemaVersion': schemaVersion,
      'variant': state.variant.wireName,
      'players': state.players.map((p) => p.toJson()).toList(),
      'board': state.board,
      'currentPlayer': state.currentPlayer,
      'moveCount': state.moveCount,
      'winnerId': state.winnerId,
    };
  }

  @override
  TicTacToeState fromJson(Map<String, dynamic> json) {
    if (json['game'] != id || json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported game or state schema version.');
    }
    final variant = TicTacToeVariant.parse(json['variant']);
    final rawPlayers = json['players'];
    final rawBoard = json['board'];
    if (rawPlayers is! List || rawBoard is! List) {
      throw const FormatException('Missing players or board.');
    }
    final players = rawPlayers.map((item) {
      if (item is! Map) throw const FormatException('Invalid player entry.');
      return GamePlayer.fromJson(Map<String, dynamic>.from(item));
    }).toList();
    final board = rawBoard.map<int?>((value) {
      if (value == null) return null;
      if (value is int && (value == 0 || value == 1)) return value;
      throw const FormatException('Invalid board cell.');
    }).toList();
    final currentPlayer = json['currentPlayer'];
    final moveCount = json['moveCount'];
    final winnerId = json['winnerId'];
    if (currentPlayer is! int || moveCount is! int ||
        (winnerId != null && winnerId is! String)) {
      throw const FormatException('Invalid game counters.');
    }
    final state = TicTacToeState(
      variant: variant,
      players: players,
      board: board,
      currentPlayer: currentPlayer,
      moveCount: moveCount,
      winnerId: winnerId as String?,
    );
    _validateState(state);
    return state;
  }

  static bool _hasWinningLine(
    List<int?> board,
    TicTacToeVariant variant,
    int player,
  ) {
    final size = variant.size;
    final target = variant.connect;
    const directions = [(0, 1), (1, 0), (1, 1), (1, -1)];

    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        if (board[row * size + col] != player) continue;
        for (final (dr, dc) in directions) {
          final endRow = row + (target - 1) * dr;
          final endCol = col + (target - 1) * dc;
          if (endRow < 0 || endRow >= size || endCol < 0 || endCol >= size) {
            continue;
          }
          var matches = true;
          for (var step = 1; step < target; step++) {
            final r = row + step * dr;
            final c = col + step * dc;
            if (board[r * size + c] != player) {
              matches = false;
              break;
            }
          }
          if (matches) return true;
        }
      }
    }
    return false;
  }

  static void _validatePlayers(List<GamePlayer> players) {
    if (players.length != 2) {
      throw ArgumentError('Tic-tac-toe requires exactly two players.');
    }
    final ids = players.map((p) => p.id).toList();
    if (ids.any((id) => id.trim().isEmpty) || ids.toSet().length != 2) {
      throw ArgumentError('Players must have unique non-empty ids.');
    }
  }

  static void _validateState(TicTacToeState state) {
    _validatePlayers(state.players);
    final expectedLength = state.variant.size * state.variant.size;
    if (state.board.length != expectedLength ||
        state.currentPlayer < 0 || state.currentPlayer > 1 ||
        state.moveCount < 0 || state.moveCount > expectedLength) {
      throw const FormatException('Invalid tic-tac-toe state dimensions.');
    }
    final occupied = state.board.where((cell) => cell != null).length;
    if (occupied != state.moveCount ||
        state.board.any((cell) => cell != null && cell != 0 && cell != 1)) {
      throw const FormatException('Board and move count do not match.');
    }
    final p0 = state.board.where((cell) => cell == 0).length;
    final p1 = state.board.where((cell) => cell == 1).length;
    if (!(p0 == p1 || p0 == p1 + 1)) {
      throw const FormatException('Invalid turn distribution.');
    }
    if (state.currentPlayer != (p0 == p1 ? 0 : 1) && !state.isFinished) {
      throw const FormatException('Current player does not match board.');
    }
    if (state.winnerId != null) {
      final winnerIndex = state.players.indexWhere((player) => player.id == state.winnerId);
      if (winnerIndex < 0) {
        throw const FormatException('Winner is not a game participant.');
      }
      final winnerHasLine = _hasWinningLine(state.board, state.variant, winnerIndex);
      final turnCountsMatch = winnerIndex == 0 ? p0 == p1 + 1 : p0 == p1;
      if (!winnerHasLine || !turnCountsMatch) {
        throw const FormatException('Winner does not match the board.');
      }
      final otherIndex = 1 - winnerIndex;
      if (_hasWinningLine(state.board, state.variant, otherIndex)) {
        throw const FormatException('Both players cannot win.');
      }
    }
    if (state.winnerId == null && _hasWinningLineForEither(state)) {
      throw const FormatException('Winning board is missing its winner.');
    }
  }

  static bool _hasWinningLineForEither(TicTacToeState state) =>
      _hasWinningLine(state.board, state.variant, 0) ||
      _hasWinningLine(state.board, state.variant, 1);
}

/// Convenience registration used by the app composition root.
void registerTicTacToe(GameRegistry registry) {
  if (!registry.contains(TicTacToeGame.gameId)) {
    registry.register<TicTacToeState, int>(const TicTacToeGame());
  }
}
