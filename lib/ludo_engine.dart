/// Pure, deterministic Ludo rules. No Flutter, IO, clock, or random source.
///
/// The caller (eventually the trusted server) supplies the dice value. This
/// library validates every transition and returns a new JSON-serializable state.
library ludo_engine;

const int ludoTrackLength = 52;
const int ludoHomeLength = 6;
const int ludoPieceHome = 57;
const List<int> ludoStartOffsets = [0, 39, 26, 13];
const Set<int> ludoSafeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

typedef LudoState = Map<String, dynamic>;

List<List<int>> _copyPieces(dynamic raw) => (raw as List)
    .map((row) => (row as List).map((v) => (v as num).toInt()).toList())
    .toList();

LudoState _copyState(LudoState state) => {
  'players': (state['players'] as List).map((p) => Map<String, dynamic>.from(p as Map)).toList(),
  'pieces': _copyPieces(state['pieces']),
  'turn': (state['turn'] as num).toInt(),
  'dice': state['dice'] == null ? null : Map<String, dynamic>.from(state['dice'] as Map),
  'phase': state['phase'] as String,
  'sixStreak': (state['sixStreak'] as num).toInt(),
  'winners': List<int>.from(state['winners'] as List),
};

bool _validState(LudoState s) {
  try {
    final players = s['players'] as List;
    final pieces = _copyPieces(s['pieces']);
    final turn = (s['turn'] as num).toInt();
    final streak = (s['sixStreak'] as num).toInt();
    return players.length >= 2 &&
        players.length <= 4 &&
        pieces.length == players.length &&
        pieces.every((row) => row.length == 4 && row.every((v) => v >= -1 && v <= 57)) &&
        turn >= 0 && turn < players.length &&
        streak >= 0 && streak <= 2 &&
        s['phase'] is String &&
        s['winners'] is List;
  } catch (_) {
    return false;
  }
}

/// Creates the single JSON state object used by the engine and transport layer.
LudoState createLudoState(List<Map<String, dynamic>> players) {
  if (players.length < 2 || players.length > 4) {
    throw ArgumentError('Ludo requires 2 to 4 players.');
  }
  final ids = players.map((p) => p['id']).toList();
  if (ids.any((id) => id == null) || ids.toSet().length != ids.length) {
    throw ArgumentError('Each player must have a unique non-null id.');
  }
  return {
    'players': players.map((p) => Map<String, dynamic>.from(p)).toList(),
    'pieces': List.generate(players.length, (_) => List<int>.filled(4, -1)),
    'turn': 0,
    'dice': null,
    'phase': 'awaiting_roll',
    'sixStreak': 0,
    'winners': <int>[],
  };
}

int? ludoTrackIndex(int player, int progress, {required int playerCount}) {
  if (playerCount < 2 || playerCount > 4 || player < 0 ||
      player >= playerCount || progress < 0 || progress > 50) return null;
  final offset = playerCount == 2 && player == 1 ? 26 : ludoStartOffsets[player];
  return (offset + progress) % ludoTrackLength;
}

bool isLudoSafeSquare(int globalSquare) => ludoSafeSquares.contains(globalSquare);

int _nextActivePlayer(LudoState state, int from) {
  final count = (state['players'] as List).length;
  final winners = List<int>.from(state['winners'] as List);
  for (var step = 1; step <= count; step++) {
    final candidate = (from + step) % count;
    if (!winners.contains(candidate)) return candidate;
  }
  return from;
}

bool _isFinished(LudoState state) {
  final count = (state['players'] as List).length;
  final winners = state['winners'] as List;
  return winners.length >= count - 1;
}

int _occupiedByPlayerOnSquare(List<List<int>> pieces, int player, int square) {
  var count = 0;
  for (final progress in pieces[player]) {
    if (ludoTrackIndex(player, progress, playerCount: pieces.length) == square) {
      count++;
    }
  }
  return count;
}

bool _pathBlocked(List<List<int>> pieces, int player, int piece, int dice) {
  final current = pieces[player][piece];
  if (current == -1) {
    final start = ludoTrackIndex(player, 0, playerCount: pieces.length)!;
    for (var p = 0; p < pieces.length; p++) {
      if (_occupiedByPlayerOnSquare(pieces, p, start) >= 2) return true;
    }
    return false;
  }
  for (var step = 1; step <= dice && current + step <= 50; step++) {
    final square = ludoTrackIndex(player, current + step, playerCount: pieces.length)!;
    for (var p = 0; p < pieces.length; p++) {
      if (_occupiedByPlayerOnSquare(pieces, p, square) >= 2) return true;
    }
  }
  return false;
}

/// Returns the legal piece indexes for the active player. Pure and deterministic.
List<int> getLegalMoves(LudoState state, int dice) {
  if (!_validState(state) || dice < 1 || dice > 6 ||
      state['phase'] != 'awaiting_move') return const [];
  final player = state['turn'] as int;
  final pieces = _copyPieces(state['pieces']);
  final legal = <int>[];
  for (var i = 0; i < 4; i++) {
    final current = pieces[player][i];
    if (current == 57) continue;
    if (current == -1 && dice != 6) continue;
    if (current >= 0 && current + dice > 57) continue;
    if (_pathBlocked(pieces, player, i, dice)) continue;
    legal.add(i);
  }
  return legal;
}

/// Applies a server-generated die result. Third consecutive six burns the turn
/// and intentionally does not create a legal move or move opportunity.
LudoState applyLudoRoll(LudoState state, int dice) {
  if (!_validState(state) || state['phase'] != 'awaiting_roll' ||
      dice < 1 || dice > 6 || _isFinished(state)) {
    throw StateError('Invalid roll transition.');
  }
  final next = _copyState(state);
  if (dice == 6) {
    final streak = (next['sixStreak'] as int) + 1;
    if (streak >= 3) {
      next['sixStreak'] = 0;
      next['dice'] = {'value': 6, 'legalMoves': <int>[], 'burned': true};
      next['turn'] = _nextActivePlayer(next, next['turn'] as int);
      next['phase'] = 'awaiting_roll';
      return next;
    }
    next['sixStreak'] = streak;
  } else {
    next['sixStreak'] = 0;
  }
  final legal = _legalMovesFor(next, dice);
  next['dice'] = {'value': dice, 'legalMoves': legal, 'burned': false};
  if (legal.isEmpty) {
    next['dice'] = null;
    next['sixStreak'] = 0;
    next['turn'] = _nextActivePlayer(next, next['turn'] as int);
    next['phase'] = 'awaiting_roll';
  } else {
    next['phase'] = 'awaiting_move';
  }
  return next;
}

List<int> _legalMovesFor(LudoState state, int dice) {
  final player = state['turn'] as int;
  final pieces = _copyPieces(state['pieces']);
  final legal = <int>[];
  for (var i = 0; i < 4; i++) {
    final current = pieces[player][i];
    if (current == 57 || (current == -1 && dice != 6) ||
        (current >= 0 && current + dice > 57)) continue;
    if (!_pathBlocked(pieces, player, i, dice)) legal.add(i);
  }
  return legal;
}

/// Moves exactly one server-authorized piece and returns a new state.
/// Invalid piece indexes and stale/illegal actions throw without mutating input.
LudoState applyLudoMove(LudoState state, int pieceIndex) {
  if (!_validState(state) || state['phase'] != 'awaiting_move' ||
      pieceIndex < 0 || pieceIndex > 3) {
    throw StateError('Invalid move request.');
  }
  final dice = (state['dice'] as Map)['value'] as int;
  final legal = getLegalMoves(state, dice);
  if (!legal.contains(pieceIndex)) throw StateError('Illegal Ludo move.');
  final next = _copyState(state);
  final player = next['turn'] as int;
  final pieces = _copyPieces(next['pieces']);
  final current = pieces[player][pieceIndex];
  final progress = current == -1 ? 0 : current + dice;
  pieces[player][pieceIndex] = progress;
  var captured = <Map<String, int>>[];
  final landing = ludoTrackIndex(player, progress, playerCount: pieces.length);
  if (landing != null && !isLudoSafeSquare(landing)) {
    for (var opponent = 0; opponent < pieces.length; opponent++) {
      if (opponent == player) continue;
      for (var token = 0; token < 4; token++) {
        if (ludoTrackIndex(opponent, pieces[opponent][token],
                playerCount: pieces.length) == landing) {
          pieces[opponent][token] = -1;
          captured.add({'player': opponent, 'piece': token});
        }
      }
    }
  }
  next['pieces'] = pieces;
  next['dice'] = {
    'value': dice,
    'legalMoves': legal,
    'captured': captured,
    'movedPiece': pieceIndex,
    'burned': false,
  };
  final winners = List<int>.from(next['winners'] as List);
  final finished = pieces[player].every((v) => v == 57);
  if (finished && !winners.contains(player)) winners.add(player);
  next['winners'] = winners;

  if (_isFinished(next)) {
    next['phase'] = 'finished';
    next['dice'] = null;
    return next;
  }

  // Six and capture each grant one extra roll. A capture on a six still grants
  // one extra turn, not two.
  if (dice == 6 || captured.isNotEmpty) {
    next['phase'] = 'awaiting_roll';
    return next;
  }
  next['sixStreak'] = 0;
  next['turn'] = _nextActivePlayer(next, player);
  next['dice'] = null;
  next['phase'] = 'awaiting_roll';
  return next;
}

/// Current server-visible legal moves; clients may render these but never decide them.
List<int> currentLegalMoves(LudoState state) {
  if (state['phase'] != 'awaiting_move' || state['dice'] is! Map) return const [];
  return getLegalMoves(state, (state['dice'] as Map)['value'] as int);
}
