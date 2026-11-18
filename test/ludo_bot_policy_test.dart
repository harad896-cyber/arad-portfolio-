import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_bot_policy.dart';

void main() {
  group('Ludo bot turn policy', () {
    test('one human controls red while blue, yellow and green are bots', () {
      expect(isLudoAutomatedTurn(enabled: true, activePlayer: 0), isFalse);
      expect(isLudoAutomatedTurn(enabled: true, activePlayer: 1), isTrue);
      expect(isLudoAutomatedTurn(enabled: true, activePlayer: 2), isTrue);
      expect(isLudoAutomatedTurn(enabled: true, activePlayer: 3), isTrue);
    });

    test('does not automate turns when bot mode is disabled', () {
      for (var player = 0; player < 4; player++) {
        expect(
          isLudoAutomatedTurn(enabled: false, activePlayer: player),
          isFalse,
        );
      }
    });

    test('supports a human seat other than red when explicitly configured', () {
      expect(
        isLudoAutomatedTurn(
          enabled: true,
          activePlayer: 2,
          humanPlayer: 2,
        ),
        isFalse,
      );
      expect(
        isLudoAutomatedTurn(
          enabled: true,
          activePlayer: 0,
          humanPlayer: 2,
        ),
        isTrue,
      );
    });
  });

  group('Equivalent legal move detection', () {
    test('four pieces in the yard are equivalent when all can leave on six', () {
      expect(
        haveEquivalentLudoMoves(
          legalPieces: [0, 1, 2, 3],
          pieceProgress: [-1, -1, -1, -1],
        ),
        isTrue,
      );
    });

    test('pieces at the same progress are equivalent', () {
      expect(
        haveEquivalentLudoMoves(
          legalPieces: [0, 2],
          pieceProgress: [12, 57, 12, -1],
        ),
        isTrue,
      );
    });

    test('different progress values require a manual choice', () {
      expect(
        haveEquivalentLudoMoves(
          legalPieces: [0, 1],
          pieceProgress: [4, 9, -1, -1],
        ),
        isFalse,
      );
    });

    test('zero or one legal piece is not classified as an equivalent choice', () {
      expect(
        haveEquivalentLudoMoves(
          legalPieces: [],
          pieceProgress: [-1, -1, -1, -1],
        ),
        isFalse,
      );
      expect(
        haveEquivalentLudoMoves(
          legalPieces: [2],
          pieceProgress: [-1, -1, 0, -1],
        ),
        isFalse,
      );
    });

    test('invalid piece indexes fail safely', () {
      expect(
        haveEquivalentLudoMoves(
          legalPieces: [0, 4],
          pieceProgress: [-1, -1, -1, -1],
        ),
        isFalse,
      );
      expect(
        haveEquivalentLudoMoves(
          legalPieces: [-1, 0],
          pieceProgress: [-1, -1, -1, -1],
        ),
        isFalse,
      );
    });
  });
}
