/// Small, deterministic helpers for local Ludo bot-turn decisions.
/// Kept free of Flutter and randomness so the behavior is unit-testable.
bool isLudoAutomatedTurn({
  required bool enabled,
  required int activePlayer,
  int humanPlayer = 0,
}) =>
    enabled && activePlayer != humanPlayer;

/// Returns true when all legal pieces have the same progress value.
/// In that case choosing any one of them produces an equivalent move.
bool haveEquivalentLudoMoves({
  required List<int> legalPieces,
  required List<int> pieceProgress,
}) {
  if (legalPieces.length < 2) return false;
  for (final piece in legalPieces) {
    if (piece < 0 || piece >= pieceProgress.length) return false;
  }
  final firstProgress = pieceProgress[legalPieces.first];
  return legalPieces.skip(1).every(
    (piece) => pieceProgress[piece] == firstProgress,
  );
}
