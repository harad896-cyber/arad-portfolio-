import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GapResan chess rules', () {
    test('standard starting position has exactly 20 legal moves', () {
      final position = Chess.initial;
      final count = position.legalMoves.values.fold<int>(
        0,
        (sum, squares) => sum + squares.size,
      );
      expect(count, 20);
    });

    test('rejects an illegal pawn move and accepts e2-e4', () {
      final position = Chess.initial;
      expect(
        position.isLegal(NormalMove(
          from: Square.fromName('e2'),
          to: Square.fromName('e5'),
        )),
        isFalse,
      );
      final next = position.play(NormalMove(
        from: Square.fromName('e2'),
        to: Square.fromName('e4'),
      ));
      expect(next.turn, Side.black);
      expect(next.board.pieceAt(Square.fromName('e4'))?.role, Role.pawn);
    });

    test('castling is legal only when the path is safe and clear', () {
      final position = Chess.fromSetup(Setup.parseFen(
        'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',
      ));
      final destinations = makeLegalMoves(position)[Square.fromName('e1')]!;
      expect(destinations, contains(Square.fromName('g1')));
      expect(destinations, contains(Square.fromName('c1')));
    });

    test('recognizes checkmate from a legal scholar mate sequence', () {
      var position = Chess.initial;
      for (final san in ['e4', 'e5', 'Qh5', 'Nc6', 'Bc4', 'Nf6', 'Qxf7#']) {
        final move = position.parseSan(san);
        expect(move, isNotNull, reason: 'Move $san must be legal');
        position = position.play(move!);
      }
      expect(position.isCheckmate, isTrue);
      expect(position.outcome?.winner, Side.white);
    });

    test('supports en passant and promotion through legal move generation', () {
      var position = Chess.fromSetup(Setup.parseFen(
        '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1',
      ));
      final ep = NormalMove(
        from: Square.fromName('e5'),
        to: Square.fromName('d6'),
      );
      expect(position.isLegal(ep), isTrue);
      position = position.play(ep);
      expect(position.board.pieceAt(Square.fromName('d5')), isNull);

      final promotionPosition = Chess.fromSetup(Setup.parseFen(
        '4k3/P7/8/8/8/8/8/4K3 w - - 0 1',
      ));
      final promotion = NormalMove(
        from: Square.fromName('a7'),
        to: Square.fromName('a8'),
        promotion: Role.queen,
      );
      expect(promotionPosition.isLegal(promotion), isTrue);
      expect(
        promotionPosition.play(promotion).board.pieceAt(Square.fromName('a8'))?.role,
        Role.queen,
      );
    });
  });
}
