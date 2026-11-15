/// Server-authoritative Ludo move analysis and deterministic turn decision.
library ludo_move_decision;

import 'ludo_engine.dart';

class LudoMoveRules {
  const LudoMoveRules({
    this.allowOwnStack = true,
    this.blockadesBlockMovement = true,
    this.safeSquares = ludoSafeSquares,
  });

  final bool allowOwnStack;
  final bool blockadesBlockMovement;
  final Set<int> safeSquares;
}

class LudoLegalMove {
  const LudoLegalMove({
    required this.pieceId,
    required this.from,
    required this.to,
    required this.path,
    this.captures = const [],
    this.entersHome = false,
    this.exits = false,
    this.landsOnSafeSquare = false,
  });

  final String pieceId;
  final int from;
  final int to;
  /// Progress values traversed. For a yard exit this contains [0].
  final List<int> path;
  final List<Map<String, Object>> captures;
  final bool entersHome;
  final bool exits;
  final bool landsOnSafeSquare;

  Map<String, Object?> toJson() => {
    'pieceId': pieceId, 'from': from, 'to': to, 'path': path,
    'captures': captures, 'entersHome': entersHome, 'exits': exits,
    'landsOnSafeSquare': landsOnSafeSquare,
  };

  String get equivalenceKey => '${from}>${to}:${path.join(",")}';
}

class LudoMoveRejection {
  const LudoMoveRejection(this.pieceId, this.reasonCode, this.message);
  final String pieceId;
  final String reasonCode;
  final String message;

  Map<String, String> toJson() => {
    'pieceId': pieceId, 'reasonCode': reasonCode, 'message': message,
  };
}

class LudoMoveAnalysis {
  const LudoMoveAnalysis(this.legalMoves, this.rejections);
  final List<LudoLegalMove> legalMoves;
  final List<LudoMoveRejection> rejections;
}

enum LudoAutoMoveKind { noMove, automatic, manual }

class LudoAutoMoveDecision {
  const LudoAutoMoveDecision({
    required this.kind,
    required this.delay,
    this.move,
    this.reason,
    this.retainTurn = false,
  });

  final LudoAutoMoveKind kind;
  final Duration delay;
  final LudoLegalMove? move;
  final String? reason;
  final bool retainTurn;
}

int? _globalSquare(int player, int progress, int playerCount) =>
    ludoTrackIndex(player, progress, playerCount: playerCount);

int _countAt(List<List<int>> pieces, int player, int square) {
  return pieces[player].where((p) => _globalSquare(player, p, pieces.length) == square).length;
}

bool _hasBlock(List<List<int>> pieces, int square) {
  for (var p = 0; p < pieces.length; p++) {
    if (_countAt(pieces, p, square) >= 2) return true;
  }
  return false;
}

/// Computes authoritative legal moves and a rejection explanation for every
/// piece that cannot move. This is pure: it never changes [state].
LudoMoveAnalysis getLegalMoveAnalysis(
  LudoState state,
  int dice, {
  LudoMoveRules rules = const LudoMoveRules(),
}) {
  if (dice < 1 || dice > 6 || state['phase'] != 'awaiting_move') {
    return const LudoMoveAnalysis([], []);
  }
  final pieces = _copyMovePieces(state['pieces']);
  final players = state['players'] as List;
  final player = state['turn'] as int;
  if (player < 0 || player >= players.length || pieces.length != players.length) {
    return const LudoMoveAnalysis([], []);
  }
  final legal = <LudoLegalMove>[];
  final rejected = <LudoMoveRejection>[];

  for (var index = 0; index < pieces[player].length; index++) {
    final current = pieces[player][index];
    final pieceId = '${players[player]['id']}:$index';
    String? code;
    String? message;
    if (current == ludoPieceHome) {
      code = 'already_home'; message = 'این مهره به مرکز رسیده است';
    } else if (current == -1 && dice != 6) {
      code = 'needs_six'; message = 'برای خارج‌کردن مهره عدد ۶ لازم است';
    } else if (current >= 0 && current + dice > ludoPieceHome) {
      code = 'overshoot_home'; message = 'برای ورود به مرکز باید عدد دقیق بیاید';
    }

    final destination = current == -1 ? 0 : current + dice;
    if (code == null && rules.blockadesBlockMovement) {
      final firstStep = current == -1 ? 0 : current + 1;
      for (var step = firstStep; step <= destination && step <= 50; step++) {
        final square = _globalSquare(player, step, pieces.length);
        if (square != null && _hasBlock(pieces, square)) {
          code = 'blocked'; message = 'مسیر با دو مهره مسدود شده است'; break;
        }
      }
    }

    final landing = destination <= 50
        ? _globalSquare(player, destination, pieces.length)
        : null;
    if (code == null && landing != null && !rules.allowOwnStack &&
        _countAt(pieces, player, landing) > (current >= 0 &&
          _globalSquare(player, current, pieces.length) == landing ? 1 : 0)) {
      code = 'own_stack_forbidden'; message = 'طبق قانون این بازی روی مهره خودی نمی‌توان نشست';
    }

    if (code != null) {
      rejected.add(LudoMoveRejection(pieceId, code, message!));
      continue;
    }

    final path = current == -1
        ? <int>[0]
        : List<int>.generate(dice, (i) => current + i + 1);
    final safe = landing != null && rules.safeSquares.contains(landing);
    final captures = <Map<String, Object>>[];
    if (landing != null && !safe) {
      for (var opponent = 0; opponent < pieces.length; opponent++) {
        if (opponent == player) continue;
        for (var token = 0; token < pieces[opponent].length; token++) {
          if (_globalSquare(opponent, pieces[opponent][token], pieces.length) == landing) {
            captures.add({'player': opponent, 'piece': token});
          }
        }
      }
    }
    legal.add(LudoLegalMove(
      pieceId: pieceId,
      from: current,
      to: destination,
      path: path,
      captures: captures,
      entersHome: destination == ludoPieceHome,
      exits: current == -1,
      landsOnSafeSquare: safe,
    ));
  }
  return LudoMoveAnalysis(List.unmodifiable(legal), List.unmodifiable(rejected));
}

List<List<int>> _copyMovePieces(dynamic raw) => (raw as List)
    .map((row) => (row as List).map((v) => (v as num).toInt()).toList())
    .toList();

/// Groups equivalent moves (same source/destination/path). If a group has
/// multiple identical choices, the server may pick its first stable member.
LudoAutoMoveDecision decideLudoMove(
  LudoState state,
  int dice,
  LudoMoveAnalysis analysis, {
  bool autoMoveSingle = true,
  bool fastGame = false,
}) {
  if (analysis.legalMoves.isEmpty) {
    return LudoAutoMoveDecision(
      kind: LudoAutoMoveKind.noMove,
      delay: const Duration(seconds: 1),
      reason: 'no_legal_moves',
      retainTurn: dice == 6,
    );
  }

  final moves = analysis.legalMoves;
  final groups = <String, List<LudoLegalMove>>{};
  for (final move in moves) {
    groups.putIfAbsent(move.equivalenceKey, () => []).add(move);
  }
  final pieces = _copyMovePieces(state['pieces']);
  final player = state['turn'] as int;
  final remaining = pieces[player].where((p) => p != ludoPieceHome).length;
  final forceAutomatic = fastGame || remaining == 1;

  if (groups.length == 1 && moves.length > 1) {
    return LudoAutoMoveDecision(
      kind: LudoAutoMoveKind.automatic,
      delay: const Duration(milliseconds: 400),
      move: groups.values.first.first,
      reason: 'equivalent_moves',
    );
  }
  if (forceAutomatic || (autoMoveSingle && moves.length == 1)) {
    return LudoAutoMoveDecision(
      kind: LudoAutoMoveKind.automatic,
      delay: const Duration(milliseconds: 400),
      move: moves.first,
      reason: forceAutomatic ? 'automatic_mode' : 'single_legal_move',
    );
  }
  return const LudoAutoMoveDecision(
    kind: LudoAutoMoveKind.manual,
    delay: Duration.zero,
    reason: 'multiple_legal_moves',
  );
}
