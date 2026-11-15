import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/dice_3d_math.dart';
import 'package:arad_messenger/ludo_dice_demo.dart';

Future<void> _mountDemo(WidgetTester tester) async {
  // Exercise a realistic phone-sized viewport instead of Flutter's short
  // default 800x600 test surface, which places the roll button below the fold.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await _mountDemo(tester);
}

void main() {
  group('3D dice orientation math', () {
    for (var face = 1; face <= 6; face++) {
      test('face $face rotates to the upward axis', () {
        final rotation = Dice3DOrientation.forTopFace(face);
        final actual = rotation.rotate(
          Dice3DOrientation.normalForFace(face),
        );
        expect(actual.x, closeTo(0, 1e-8));
        expect(actual.y, closeTo(0, 1e-8));
        expect(actual.z, closeTo(1, 1e-8));
      });
    }

    test('uses standard opposite-face pairs', () {
      expect(
        Dice3DOrientation.normalForFace(1)
            .dot(Dice3DOrientation.normalForFace(6)),
        closeTo(-1, 1e-8),
      );
      expect(
        Dice3DOrientation.normalForFace(2)
            .dot(Dice3DOrientation.normalForFace(5)),
        closeTo(-1, 1e-8),
      );
      expect(
        Dice3DOrientation.normalForFace(3)
            .dot(Dice3DOrientation.normalForFace(4)),
        closeTo(-1, 1e-8),
      );
    });

    test('rejects face values outside the physical die', () {
      expect(() => Dice3DOrientation.forTopFace(0), throwsRangeError);
      expect(() => Dice3DOrientation.forTopFace(7), throwsRangeError);
    });
  });

  group('standalone dice widget', () {
    testWidgets('lands on the face selected by the user', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DiceRollDemo()));

      final input = find.byType(TextField);
      await tester.enterText(input, '4');
      await tester.tap(find.text('پرتاب تاس'));
      await tester.pump();

      expect(find.text('تاس در حال چرخش است'), findsOneWidget);
      expect(tester.widget<TextField>(input).enabled, isFalse);

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();

      expect(find.text('نتیجه: 4'), findsOneWidget);
      expect(tester.widget<TextField>(input).enabled, isTrue);
    });

    testWidgets('rejects a value outside 1 to 6 without rolling',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DiceRollDemo()));

      await tester.enterText(find.byType(TextField), '9');
      await tester.tap(find.text('پرتاب تاس'));
      await tester.pump();

      expect(find.text('عدد باید بین ۱ تا ۶ باشد.'), findsOneWidget);
      expect(find.text('نتیجه: 6'), findsOneWidget);
    });

    testWidgets('ignores repeated taps while the die is moving',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DiceRollDemo()));

      await tester.tap(find.text('پرتاب تاس'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();
      expect(find.text('نتیجه: 6'), findsOneWidget);
    });

    testWidgets('renders every possible selected face without exceptions',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DiceRollDemo()));
      final input = find.byType(TextField);

      for (var face = 1; face <= 6; face++) {
        await tester.enterText(input, '$face');
        await tester.tap(find.text('پرتاب تاس'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pumpAndSettle();
        expect(find.text('نتیجه: $face'), findsOneWidget);
      }
    });
  });
}
