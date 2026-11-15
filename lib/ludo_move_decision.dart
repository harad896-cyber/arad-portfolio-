import 'ludo_engine.dart';

/// Rule switches are server-owned game configuration, never client authority.
class LudoMoveRules {
  const LudoMoveRules({
    this.allowOwnStack = false,
    this.allowPassBlockades = false,
  });
  final bool allowOwnStack;
  final bool allowPassBlockades;
}

enum LudoMoveRejectCode {
  needsSix, alreadyHome, overshootsCenter, blockedPath,
  ownPieceAtDestination, friendlyBlockadeAtDestination,
  enemyBlockadeAtDestination, invalidState,
}

class LudoPieceRef {
  const LudoPieceRef({required this.playerIndex, required this.pieceIndex});
  final int playerIndex;
  final int pieceIndex;
  String get id => '${playerIndex}:$pieceIndex';
  Map<String, int> toJson() => {'playerIndex': playerIndex, 'pieceIndex': pieceIndex};
}

class LudoRejectedMove {
  const LudoRejectedMove({
    required this.pieceId, required this.pieceIndex,
    required this.code, required this.message,
  });
  final String pieceId;
  final int pieceIndex;
  final LudoMoveRejectCode code;
  final String message;
}

class LudoLegalMove {
  const LudoLegalMove({
    required this.pieceId, required this.pieceIndex,
    required this.from, required this.to, required this.path,
    required this.captures, required this.entersHome,
    required this.exits, required this.landsOnSafeSquare,
  });
  final String pieceId;
  final int pieceIndex;
  /// Progress: -1 yard; 0..51 shared route; 52..57 home lane.
  final int from;
  final int to;
  /// Progress coordinates traversed, including the destination.
  final List<int> path;
  final List<LudoPieceRef> captures;
  final bool entersHome;
  final bool exits;
  final bool landsOnSafeSquare;
  bool get reachesCenter => to == ludoPieceHome;

  Map<String, dynamic> toJson() => {
    'pieceId': pieceId, 'pieceIndex': pieceIndex, 'from': from,
    'to': to, 'path': path,
    'captures': captures.map((capture) => capture.toJson()).toList(),
    'entersHome': entersHome, 'exits': exits,
    'landsOnSafeSquare': landsOnSafeSquare,
  };
}

class LudoMoveAnalysis {
  const LudoMoveAnalysis({
    required this.legalMoves, required this.rejectedMoves, this.error,
  });
  final List<LudoLegalMove> legalMoves;
  final List<LudoRejectedMove> rejectedMoves;
  final String? error;
  bool get isValid => error == null;
}

/// Detailed deterministic analysis for the trusted game service.
/// Existing getLegalMoves() remains unchanged for compatibility.
LudoMoveAnalysis getLegalMoveAnalysis(
  LudoState state, int dice, {
  LudoMoveRules rules = const LudoMoveRules(),
}) {
  if (!isValidLudoState(state) || state['phase'] != 'awaiting_move' ||
      dice < 1 || dice > 6 || (state['dice'] as Map?)?['value'] != dice) {
    return const LudoMoveAnalysis(
      legalMoves: [], rejectedMoves: [],
      error: 'وضعیت بازی یا عدد تاس معتبر نیست.',
    );
  }

  final playerIndex = state['turn'] as int;
  final players = state['players'] as List;
  final playerId = (players[playerIndex] as Map)['id'] as String;
  final pieces = (state['pieces'] as List)
      .map((row) => List<int>.from(row as List)).toList(growable: false);
  final legal = <LudoLegalMove>[];
  final rejected = <LudoRejectedMove>[];

  int? squareAt(int owner, int progress) =>
      ludoTrackIndex(owner, progress, playerCount: pieces.length);

  int countAt(int owner, int square, {int? exceptPiece}) {
    var count = 0;
    for (var index = 0; index < 4; index++) {
      if (index == exceptPiece) continue;
      if (squareAt(owner, pieces[owner][index]) == square) count++;
    }
    return count;
  }

  for (var pieceIndex = 0; pieceIndex < 4; pieceIndex++) {
    final from = pieces[playerIndex][pieceIndex];
    final pieceId = '$playerId:$pieceIndex';
    void reject(LudoMoveRejectCode code, String message) {
      rejected.add(LudoRejectedMove(
        pieceId: pieceId, pieceIndex: pieceIndex, code: code, message: message,
      ));
    }

    if (from == ludoPieceHome) {
      reject(LudoMoveRejectCode.alreadyHome, 'این مهره به مرکز رسیده است.');
      continue;
    }
    if (from == -1 && dice != 6) {
      reject(LudoMoveRejectCode.needsSix, 'برای بیرون‌آوردن مهره عدد ۶ لازم است.');
      continue;
    }
    final to = from == -1 ? 0 : from + dice;
    if (to > ludoPieceHome) {
      reject(LudoMoveRejectCode.overshootsCenter, 'برای رسیدن به مرکز باید عدد دقیق بیاید.');
      continue;
    }

    final path = <int>[];
    for (var progress = (from == -1 ? 0 : from + 1); progress <= to; progress++) {
      path.add(progress);
    }

    var blocked = false;
    var blockedAtDestination = false;
    for (final progress in path) {
      final square = squareAt(playerIndex, progress);
      if (square == null) continue;
      for (var owner = 0; owner < pieces.length; owner++) {
        if (countAt(owner, square, exceptPiece: owner == playerIndex ? pieceIndex : null) < 2) {
          continue;
        }
        if (progress == to) {
          blockedAtDestination = true;
        } else if (!rules.allowPassBlockades) {
          blocked = true;
        }
      }
    }
    if (blocked) {
      reject(LudoMoveRejectCode.blockedPath, 'مسیر با دو مهرهٔ هم‌رنگ بسته شده است.');
      continue;
    }
    if (blockedAtDestination) {
      final square = squareAt(playerIndex, to)!;
      final friendly = countAt(playerIndex, square, exceptPiece: pieceIndex) >= 2;
      reject(
        friendly ? LudoMoveRejectCode.friendlyBlockadeAtDestination
            : LudoMoveRejectCode.enemyBlockadeAtDestination,
        'روی خانهٔ مقصد یک سد دو‌مهره‌ای وجود دارد.',
      );
      continue;
    }

    final destinationSquare = squareAt(playerIndex, to);
    final friendlyCount = destinationSquare == null ? 0
        : countAt(playerIndex, destinationSquare, exceptPiece: pieceIndex);
    if (friendlyCount > 0 && !rules.allowOwnStack) {
      reject(LudoMoveRejectCode.ownPieceAtDestination,
          'یک مهرهٔ هم‌رنگ در خانهٔ مقصد است.');
      continue;
    }

    final captures = <LudoPieceRef>[];
    final safe = destinationSquare != null && isLudoSafeSquare(destinationSquare);
    if (destinationSquare != null && !safe) {
      for (var owner = 0; owner < pieces.length; owner++) {
        if (owner == playerIndex) continue;
        for (var token = 0; token < 4; token++) {
          if (squareAt(owner, pieces[owner][token]) == destinationSquare) {
            captures.add(LudoPieceRef(playerIndex: owner, pieceIndex: token));
          }
        }
      }
    }
    legal.add(LudoLegalMove(
      pieceId: pieceId, pieceIndex: pieceIndex, from: from, to: to,
      path: List.unmodifiable(path), captures: List.unmodifiable(captures),
      entersHome: from < 52 && to >= 52, exits: from == -1,
      landsOnSafeSquare: safe,
    ));
  }
  return LudoMoveAnalysis(
    legalMoves: List.unmodifiable(legal),
    rejectedMoves: List.unmodifiable(rejected),
  );
}

enum LudoAutoAction { passTurn, repeatRoll, moveAutomatically, askPlayer }

class LudoAutoDecision {
  const LudoAutoDecision({required this.action, this.move, required this.reason});
  final LudoAutoAction action;
  final LudoLegalMove? move;
  final String reason;
}

/// Policy only. The chosen move must still be submitted to and validated by
/// the authoritative server before any state transition is committed.
LudoAutoDecision decideLudoMove(
  LudoState state, LudoMoveAnalysis analysis, {
  bool autoMoveSinglePiece = true,
}) {
  if (!analysis.isValid) {
    return const LudoAutoDecision(
      action: LudoAutoAction.askPlayer, reason: 'وضعیت حرکت معتبر نیست.',
    );
  }
  final dice = (state['dice'] as Map)['value'] as int;
  final moves = analysis.legalMoves;
  if (moves.isEmpty) {
    return LudoAutoDecision(
      action: dice == 6 ? LudoAutoAction.repeatRoll : LudoAutoAction.passTurn,
      reason: dice == 6
          ? 'حرکتی ممکن نیست؛ به‌دلیل تاس ۶ نوبت پرتاب دوباره است.'
          : 'حرکتی ممکن نیست؛ نوبت به بازیکن بعدی می‌رسد.',
    );
  }

  final pieces = (state['pieces'] as List)[state['turn'] as int] as List;
  final unfinished = pieces.where((position) => position != ludoPieceHome).length;
  if (moves.length == 1) {
    if (autoMoveSinglePiece || unfinished == 1) {
      return LudoAutoDecision(
        action: LudoAutoAction.moveAutomatically, move: moves.single,
        reason: unfinished == 1 ? 'فقط یک مهره باقی مانده است.' : 'فقط یک حرکت مجاز وجود دارد.',
      );
    }
    return const LudoAutoDecision(
      action: LudoAutoAction.askPlayer, reason: 'انتخاب دستی در تنظیمات فعال است.',
    );
  }

  final signatures = moves
      .map((move) => '${move.from}:${move.to}:${move.path.join(",")}')
      .toSet();
  if (signatures.length == 1) {
    final chosen = moves.reduce((a, b) => a.pieceIndex <= b.pieceIndex ? a : b);
    return LudoAutoDecision(
      action: LudoAutoAction.moveAutomatically, move: chosen,
      reason: 'حرکت چند مهره کاملاً هم‌ارز است؛ یکی به‌صورت خودکار انتخاب شد.',
    );
  }
  return const LudoAutoDecision(
    action: LudoAutoAction.askPlayer, reason: 'چند حرکت متفاوت وجود دارد؛ بازیکن باید انتخاب کند.',
  );
}
