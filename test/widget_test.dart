import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/main.dart';
import 'package:arad_messenger/fun_zone.dart';

void main() {
  setUp(() {});
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
    Future<void> openGame(WidgetTester tester, String title) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: FunZonePage()));
      final game = find.text(title);
      await tester.scrollUntilVisible(game, 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(game);
      await tester.pumpAndSettle();
      await tester.tap(game);
      await tester.pumpAndSettle();
    }

    testWidgets('Fun Zone only shows the games that are currently supported', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: FunZonePage()));
      expect(find.text('لودو'), findsOneWidget);
      expect(find.text('شطرنج'), findsOneWidget);
      expect(find.text('بازی حافظه'), findsOneWidget);
      expect(find.text('مسابقه و معما'), findsOneWidget);
      expect(find.text('چهار در یک خط'), findsNothing);
      expect(find.text('بازی دونفره'), findsNothing);
      expect(find.text('مار'), findsNothing);
      expect(find.text('ساخت استیکر'), findsNothing);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('Memory game opens with cards and move counter', (tester) async {
      await openGame(tester, 'بازی حافظه');
      expect(find.textContaining('حرکت‌ها:'), findsOneWidget);
      expect(find.text('بازی تازه'), findsOneWidget);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('Quiz starts with a twelve-question round', (tester) async {
      await openGame(tester, 'مسابقه و معما');
      expect(find.textContaining('پرسش 1 از 12'), findsOneWidget);
      expect(find.textContaining('امتیاز:'), findsOneWidget);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  });
}
