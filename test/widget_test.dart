import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/main.dart';
import 'package:arad_messenger/fun_zone.dart';
import 'package:flutter/material.dart';

void main() {
  group('input normalization', () {
    test('OTP digits normalize Persian, Arabic and ASCII numerals', () {
      expect(normalizeOtpDigits('۱۲۳۴۵۶'), '123456');
      expect(normalizeOtpDigits('١٢٣٤٥٦'), '123456');
      expect(normalizeOtpDigits('123456'), '123456');
    });
  });

  group('language labels', () {
    test('Pashto login labels are translated', () {
      expect(t('login', 'ps'), 'ننوتل');
      expect(t('password', 'ps'), 'پټنوم');
    });

    test('English login labels are translated', () {
      expect(t('login', 'en'), 'Login');
      expect(t('settings', 'en'), 'Settings');
    });

    test('unknown translation key falls back safely', () {
      expect(t('unknown_label', 'en'), 'unknown_label');
    });
  });
  group('GapResan entertainment games', () {
    testWidgets('Connect Four opens with turn and rules', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FunZonePage()));
      final game = find.text('چهار در یک خط');
      await tester.scrollUntilVisible(game, 260, scrollable: find.byType(Scrollable).first);
      await tester.tap(game);
      await tester.pumpAndSettle();
      expect(find.text('نوبت بازیکن سرخ'), findsOneWidget);
      expect(find.textContaining('چهار مهرهٔ هم‌رنگ'), findsOneWidget);
    });

    testWidgets('Connect Four recognizes a horizontal win', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FunZonePage()));
      final game = find.text('چهار در یک خط');
      await tester.scrollUntilVisible(game, 260, scrollable: find.byType(Scrollable).first);
      await tester.tap(game);
      await tester.pumpAndSettle();
      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      for (final column in [0, 0, 1, 1, 2, 2, 3]) {
        await tester.tap(cells.at(35 + column));
        await tester.pump();
      }
      expect(find.text('مهره سرخ برنده شد!'), findsOneWidget);
    });

    testWidgets('Memory game opens with cards and move counter', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FunZonePage()));
      final game = find.text('بازی حافظه');
      await tester.scrollUntilVisible(game, 260, scrollable: find.byType(Scrollable).first);
      await tester.tap(game);
      await tester.pumpAndSettle();
      expect(find.textContaining('حرکت‌ها:'), findsOneWidget);
      expect(find.text('بازی تازه'), findsOneWidget);
    });

    testWidgets('Quiz starts with a ten-question round', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FunZonePage()));
      await tester.tap(find.text('مسابقه و معما'));
      await tester.pumpAndSettle();
      expect(find.textContaining('از ۱۰'), findsOneWidget);
    });
  });

}
