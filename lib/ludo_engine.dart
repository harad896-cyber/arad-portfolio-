/// Pure, deterministic Ludo rules.
///
/// This file has no Flutter, IO, clock, or random dependencies. A trusted
/// transport/server supplies dice values and persists the returned state.
/// All transitions return a fresh JSON-compatible state and never mutate input.
library ludo_engine;

const int ludoTrackLength = 52; // board circumference
const int ludoSharedTrackLength = 51; // per-player route before turning into the home lane
const int ludoHomeLength = 6;
const int ludoPieceHome = ludoTrackLength + ludoHomeLength - 1; // 57
const List<int> ludoStartOffsets = [0, 39, 26, 13];

/// Standard star/safe squares on the shared board route.
const Set<int> ludoSafeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

typedef LudoState = Map<String, dynamic>;

const Set<String> _phases = {'awaiting_roll', 'awaiting_move', 'finished'};

Object? _cloneJson(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) return value.map(_cloneJson).toList();
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), _cloneJson(value)));
  }
  throw ArgumentError('Ludo state contains a non-JSON value.');
}

List<List<int>> _copyPieces(dynamic raw) => (raw as List)
    .map((row) => (row as List).map((v) => v as int).toList())
    .toList();

LudoState _copyState(LudoState state) =>
    Map<String, dynamic>.from(_cloneJson(state) as Map);

bool _isInt(Object? value) => value is int;

bool _validPlayerList(dynamic raw) {
  if (raw is! List || raw.length < 2 || raw.length > 4) return false;
  final ids = <Object?>[];
  for (final player in raw) {
    if (player is! Map || player['id'] == null) return false;
    final id = player['id'];
    if (id is! String || id.trim().isEmpty || ids.contains(id)) return false;
    ids.add(id);
  }
  return true;
}

/// Validates the complete transport state, not just the fields used by a move.
bool isValidLudoState(LudoState state) {
  try {
    if (state.keys.toSet().difference({
      'players', 'pieces', 'turn', 'dice', 'phase', 'sixStreak', 'winners'
    }).isNotEmpty) return false;
    if (!_validPlayerList(state['players'])) return false;

    final players = state['players'] as List;
    final piecesRaw = state['pieces'];
    if (piecesRaw is! List || piecesRaw.length != players.length) return false;
    for (final row in piecesRaw) {
      if (row is! List || row.length != 4) return false;
      if (row.any((value) => !_isInt(value) || value < -1 || value > ludoPieceHome)) {
        return false;
      }
    }

    final turn = state['turn'];
    final streak = state['sixStreak'];
    if (!_isInt(turn) || turn < 0 || turn >= players.length) return false;
    if (!_isInt(streak) || streak < 0 || streak > 2) return false;

    final phase = state['phase'];
    if (phase is! String || !_phases.contains(phase)) return false;

    final winners = state['winners'];
    if (winners is! List ||
        winners.any((winner) => !_isInt(winner) || winner < 0 || winner >= players.length) ||
        winners.toSet().length != winners.length) {
      return false;
    }

    final dice = state['dice'];
    if (dice != null) {
      if (dice is! Map || !_isInt(dice['value']) || dice['value'] < 1 || dice['value'] > 6) {
        return false;
      }
    }
    if (phase == 'awaiting_move') {
      if (dice is! Map || dice['burned'] == true) return false;
    }
    if (phase == 'finished' && winners.length < players.length - 1) return false;
    if (phase != 'finished' && winners.length >= players.length - 1) return false;

    // Ensure every value can safely cross the JSON transport boundary.
    _cloneJson(state);
    return true;
  } catch (_) {
    return false;
  }
}

/// Creates the canonical single JSON state object used by the engine/transport.
LudoState createLudoState(List<Map<String, dynamic>> players) {
  if (players.length < 2 || players.length > 4) {
    throw ArgumentError('Ludo requires 2 to 4 players.');
  }
  final ids = players.map((player) => player['id']).toList();
  if (ids.any((id) => id is! String || id.trim().isEmpty) ||
      ids.toSet().length != ids.length) {
    throw ArgumentError('Each player must have a unique non-empty string id.');
  }
  final state = <String, dynamic>{
    'players': _cloneJson(players),
    'pieces': List.generate(players.length, (_) => List<int>.filled(4, -1)),
    'turn': 0,
    'dice': null,
    'phase': 'awaiting_roll',
    'sixStreak': 0,
    'winners': <int>[],
  };
  return state;
}

/// Maps a player's progress to a shared-route square.
/// Progress 0..50 is on the shared track; 51..56 is the private home lane and 57 is home.
int? ludoTrackIndex(int player, int progress, {required int playerCount}) {
  if (playerCount < 2 ||
      playerCount > 4 ||
      player < 0 ||
      player >= playerCount ||
      progress < 0 ||
      progress >= ludoSharedTrackLength) {
    return null;
  }
  final offset = playerCount == 2 && player == 1
      ? 26
      : ludoStartOffsets[player];
  return (offset + progress) % ludoTrackLength;
}

bool isLudoSafeSquare(int globalSquare) =>
    ludoSafeSquares.contains(globalSquare);

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
  return (state['winners'] as List).length >= count - 1;
}

int _countOwnerOnSquare(
  List<List<int>> pieces,
  int owner,
  int square, {
  int? exceptPiece,
}) {
  var count = 0;
  for (var index = 0; index < pieces[owner].length; index++) {
    if (index == exceptPiece) continue;
    if (ludoTrackIndex(owner, pieces[owner][index],
            playerCount: pieces.length) ==
        square) {
      count++;
    }
  }
  return count;
}

/// A pair of same-colour pieces forms a blockade. A blockade cannot be landed
/// on; crossing it is controlled by the server-owned rule configuration.
bool _pathBlocked(
  List<List<int>> pieces,
  int player,
  int piece,
  int dice, {
  required bool allowPassBlockades,
}) {
  final current = pieces[player][piece];
  final firstStep = current == -1 ? 0 : current + 1;
  final lastStep = current == -1 ? 0 : current + dice;

  for (var progress = firstStep; progress <= lastStep; progress++) {
    if (progress > ludoPieceHome) break;
    final square = ludoTrackIndex(player, progress, playerCount: pieces.length);
    if (square == null) continue;
    for (var owner = 0; owner < pieces.length; owner++) {
      final count = _countOwnerOnSquare(
        pieces, owner, square,
        exceptPiece: owner == player ? piece : null,
      );
      if (count >= 2 && (progress == lastStep || !allowPassBlockades)) {
        return true;
      }
    }
  }
  return false;
}

List<int> _calculateLegalMoves(
  LudoState state,
  int dice, {
  required bool allowOwnStack,
  required bool allowPassBlockades,
}) {
  final player = state['turn'] as int;
  final pieces = _copyPieces(state['pieces']);
  final legal = <int>[];

  for (var index = 0; index < 4; index++) {
    final current = pieces[player][index];
    if (current == ludoPieceHome) continue;
    if (current == -1 && dice != 6) continue;
    if (current >= 0 && current + dice > ludoPieceHome) continue;
    if (_pathBlocked(
      pieces, player, index, dice,
      allowPassBlockades: allowPassBlockades,
    )) {
      continue;
    }
    final destination = current == -1 ? 0 : current + dice;
    final square = ludoTrackIndex(player, destination,
        playerCount: pieces.length);
    if (square != null &&
        !allowOwnStack &&
        _countOwnerOnSquare(
              pieces, player, square, exceptPiece: index,
            ) >
            0) {
      continue;
    }
    legal.add(index);
  }
  return legal;
}

/// Returns legal piece indexes for the active player; never trusts UI selection.
/// Rule flags must come from trusted server-side game configuration.
List<int> getLegalMoves(
  LudoState state,
  int dice, {
  bool allowOwnStack = false,
  bool allowPassBlockades = false,
}) {
  if (!isValidLudoState(state) ||
      state['phase'] != 'awaiting_move' ||
      dice < 1 ||
      dice > 6 ||
      (state['dice'] as Map?)?['value'] != dice) {
    return const [];
  }
  return _calculateLegalMoves(
    state, dice,
    allowOwnStack: allowOwnStack,
    allowPassBlockades: allowPassBlockades,
  );
}

/// Applies a die value supplied by the trusted server.
///
/// A third consecutive six burns the roll and passes the turn without moving.
LudoState applyLudoRoll(
  LudoState state,
  int dice, {
  bool allowOwnStack = false,
  bool allowPassBlockades = false,
}) {
  if (!isValidLudoState(state) ||
      state['phase'] != 'awaiting_roll' ||
      dice < 1 ||
      dice > 6 ||
      _isFinished(state)) {
    throw StateError('Invalid roll transition.');
  }

  final next = _copyState(state);
  final player = next['turn'] as int;
  final streak = dice == 6 ? (next['sixStreak'] as int) + 1 : 0;

  if (dice == 6 && streak >= 3) {
    next['sixStreak'] = 0;
    next['dice'] = {
      'value': 6,
      'legalMoves': <int>[],
      'burned': true,
      'reason': 'three_sixes',
    };
    next['turn'] = _nextActivePlayer(next, player);
    next['phase'] = 'awaiting_roll';
    return next;
  }

  next['sixStreak'] = streak;
  final legal = _calculateLegalMoves(
    next, dice,
    allowOwnStack: allowOwnStack,
    allowPassBlockades: allowPassBlockades,
  );
  if (legal.isEmpty) {
    // Keep the roll pending so the server can return per-piece rejection
    // reasons, show the one-second no-move message, then resolve the pass.
    next['dice'] = {
      'value': dice,
      'legalMoves': <int>[],
      'burned': false,
      'reason': 'no_legal_move',
    };
    next['phase'] = 'awaiting_move';
    return next;
  }

  next['dice'] = {
    'value': dice,
    'legalMoves': legal,
    'burned': false,
  };
  next['phase'] = 'awaiting_move';
  return next;
}

/// Resolves a pending roll that has no legal moves.
///
/// The server calls this after its no-move feedback delay. A six keeps the
/// same player and consecutive-six streak; any other value passes the turn.
LudoState applyLudoNoMoveDecision(
  LudoState state, {
  bool allowOwnStack = false,
  bool allowPassBlockades = false,
}) {
  if (!isValidLudoState(state) ||
      state['phase'] != 'awaiting_move' ||
      state['dice'] is! Map ||
      (state['dice'] as Map)['burned'] == true) {
    throw StateError('Invalid no-move resolution.');
  }
  final dice = (state['dice'] as Map)['value'] as int;
  final legal = getLegalMoves(
    state,
    dice,
    allowOwnStack: allowOwnStack,
    allowPassBlockades: allowPassBlockades,
  );
  if (legal.isNotEmpty) {
    throw StateError('Cannot pass a turn while a legal move exists.');
  }

  final next = _copyState(state);
  final player = next['turn'] as int;
  final diceState = Map<String, dynamic>.from(next['dice'] as Map)
    ..['resolvedNoMove'] = true
    ..['extraRoll'] = dice == 6;
  next['dice'] = diceState;
  if (dice != 6) {
    next['sixStreak'] = 0;
    next['turn'] = _nextActivePlayer(next, player);
  }
  next['phase'] = 'awaiting_roll';
  return next;
}

/// Moves one legal piece. Illegal/stale client requests throw without mutation.
LudoState applyLudoMove(
  LudoState state,
  int pieceIndex, {
  bool allowOwnStack = false,
  bool allowPassBlockades = false,
}) {
  if (!isValidLudoState(state) ||
      state['phase'] != 'awaiting_move' ||
      pieceIndex < 0 ||
      pieceIndex > 3) {
    throw StateError('Invalid move request.');
  }

  final dice = (state['dice'] as Map)['value'] as int;
  final legal = getLegalMoves(
    state, dice,
    allowOwnStack: allowOwnStack,
    allowPassBlockades: allowPassBlockades,
  );
  if (!legal.contains(pieceIndex)) throw StateError('Illegal Ludo move.');

  final next = _copyState(state);
  final player = next['turn'] as int;
  final pieces = _copyPieces(next['pieces']);
  final current = pieces[player][pieceIndex];
  final progress = current == -1 ? 0 : current + dice;
  pieces[player][pieceIndex] = progress;

  final captured = <Map<String, int>>[];
  final landing = ludoTrackIndex(player, progress, playerCount: pieces.length);
  if (landing != null && !isLudoSafeSquare(landing)) {
    for (var opponent = 0; opponent < pieces.length; opponent++) {
      if (opponent == player) continue;
      for (var token = 0; token < 4; token++) {
        if (ludoTrackIndex(opponent, pieces[opponent][token],
                playerCount: pieces.length) ==
            landing) {
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
  final playerFinished = pieces[player].every((position) => position == ludoPieceHome);
  if (playerFinished && !winners.contains(player)) winners.add(player);
  next['winners'] = winners;

  if (_isFinished(next)) {
    next['phase'] = 'finished';
    next['dice'] = null;
    next['sixStreak'] = 0;
    return next;
  }

  // A player who has finished must never receive another turn, even after a 6
  // or a capture on their finishing move.
  if (playerFinished) {
    next['turn'] = _nextActivePlayer(next, player);
    next['sixStreak'] = 0;
    next['dice'] = null;
    next['phase'] = 'awaiting_roll';
    return next;
  }

  // Six and capture each grant one extra roll, never two extra rolls together.
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

/// Server-visible legal moves for the current pending roll.
List<int> currentLegalMoves(
  LudoState state, {
  bool allowOwnStack = false,
  bool allowPassBlockades = false,
}) {
  if (!isValidLudoState(state) ||
      state['phase'] != 'awaiting_move' ||
      state['dice'] is! Map) {
    return const [];
  }
  return getLegalMoves(
    state,
    (state['dice'] as Map)['value'] as int,
    allowOwnStack: allowOwnStack,
    allowPassBlockades: allowPassBlockades,
  );
}
