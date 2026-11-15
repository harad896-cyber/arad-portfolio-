import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_dice_demo.dart';

void main() {
  testWidgets('lands on the face selected by the user', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DiceRollDemo()));

    final input = find.byType(TextField);
    await tester.enterText(input, '4');
    await tester.tap(find.text('بنداز 🎲'));
    await tester.pump();

    expect(find.text('در حال چرخش...'), findsOneWidget);
    expect(tester.widget<TextField>(input).enabled, isFalse);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text('نتیجه: 4'), findsOneWidget);
    expect(tester.widget<TextField>(input).enabled, isTrue);
  });

  testWidgets('rejects a value outside 1 to 6 without rolling',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DiceRollDemo()));

    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.text('بنداز 🎲'));
    await tester.pump();

    expect(find.text('عدد باید بین ۱ تا ۶ باشد.'), findsOneWidget);
    expect(find.text('نتیجه: 6'), findsOneWidget);
  });

  testWidgets('ignores rapid repeated taps during one roll', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DiceRollDemo()));

    await tester.tap(find.text('بنداز 🎲'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('نتیجه: 6'), findsOneWidget);
  });
}
