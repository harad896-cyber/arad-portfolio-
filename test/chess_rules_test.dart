import 'package:flutter_test/flutter_test.dart';
import '../lib/chess_engine/chess.dart' as chess;

void main() {
  group('GapResan cross-platform chess rules', () {
    test('standard starting position has exactly 20 legal moves', () {
      final game = chess.Chess();
      expect(game.generate_moves().length, 20);
    });

    test('rejects an illegal pawn move and accepts e2-e4', () {
      final game = chess.Chess();
      expect(game.move({'from': 'e2', 'to': 'e5'}), isFalse);
      expect(game.move({'from': 'e2', 'to': 'e4'}), isTrue);
      expect(game.turn, chess.Color.BLACK);
      expect(game.get('e4')?.type, chess.PieceType.PAWN);
    });

    test('castling is legal only when the path is safe and clear', () {
      final game = chess.Chess.fromFEN('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final destinations = game.generate_moves({'square': 'e1'}).map((m) => m.toAlgebraic).toSet();
      expect(destinations, contains('g1'));
      expect(destinations, contains('c1'));
      final blocked = chess.Chess.fromFEN('r3k2r/8/8/8/8/8/8/R2BK2R w KQkq - 0 1');
      expect(blocked.generate_moves({'square': 'e1'}).any((m) => m.toAlgebraic == 'g1'), isFalse);
    });

    test('recognizes checkmate from a legal scholar mate sequence', () {
      final game = chess.Chess();
      for (final san in ['e4', 'e5', 'Qh5', 'Nc6', 'Bc4', 'Nf6', 'Qxf7#']) {
        expect(game.move(san), isTrue, reason: 'Move $san must be legal');
      }
      expect(game.in_checkmate, isTrue);
      expect(game.turn, chess.Color.BLACK);
    });

    test('supports en passant and promotion through legal move generation', () {
      final enPassant = chess.Chess.fromFEN('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1');
      expect(enPassant.move({'from': 'e5', 'to': 'd6'}), isTrue);
      expect(enPassant.get('d5'), isNull);
      expect(enPassant.get('d6')?.type, chess.PieceType.PAWN);
      final promotion = chess.Chess.fromFEN('4k3/P7/8/8/8/8/8/4K3 w - - 0 1');
      expect(promotion.move({'from': 'a7', 'to': 'a8', 'promotion': 'q'}), isTrue);
      expect(promotion.get('a8')?.type, chess.PieceType.QUEEN);
    });

    test('undo restores the previous board and side to move', () {
      final game = chess.Chess();
      game.move('e4');
      game.move('e5');
      expect(game.turn, chess.Color.WHITE);
      game.undo();
      expect(game.turn, chess.Color.BLACK);
      expect(game.get('e5'), isNull);
    });

    test('detects stalemate and insufficient material', () {
      final stalemate = chess.Chess.fromFEN('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(stalemate.in_stalemate, isTrue);
      final insufficient = chess.Chess.fromFEN('8/8/8/8/8/8/4k3/6K1 w - - 0 1');
      expect(insufficient.insufficient_material, isTrue);
    });
  });
}
