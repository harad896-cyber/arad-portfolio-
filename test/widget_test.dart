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
      // SliverGrid builds cards lazily; scroll the memory tile into view
      // before asserting that its title is present in the widget tree.
      final memoryGame = find.text('بازی حافظه');
      await tester.scrollUntilVisible(memoryGame, 300,
          scrollable: find.byType(Scrollable).first);
      expect(memoryGame, findsOneWidget);
      expect(find.text('مسابقه و معما'), findsOneWidget);
      expect(find.text('چهار در یک خط'), findsNothing);
      expect(find.text('بازی دونفره'), findsNothing);
      expect(find.text('مار'), findsNothing);
      expect(find.text('ساخت استیکر'), findsNothing);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('Ludo opens from Fun Zone and shows its mode picker', (tester) async {
      await openGame(tester, 'لودو');
      expect(find.text('لودوی گپ‌رسان'), findsOneWidget);
      expect(find.text('شروع بازی'), findsOneWidget);
      expect(find.text('بازی با ربات'), findsOneWidget);
      expect(tester.takeException(), isNull);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('Ludo mode picker is laid out on a phone-sized screen', (tester) async {
      tester.view.physicalSize = const Size(384, 832);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: FunZonePage()));
      final tile = find.text('لودو');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      final heading = find.text('لودوی گپ‌رسان');
      final start = find.text('شروع بازی');
      expect(heading, findsOneWidget);
      expect(start, findsOneWidget);
      expect(find.byIcon(Icons.casino_rounded), findsOneWidget);
      expect(tester.getSize(heading).height, greaterThan(0));
      expect(tester.getSize(start).height, greaterThan(0));
      expect(tester.getTopLeft(heading).dy, greaterThanOrEqualTo(0));
      expect(tester.getBottomRight(heading).dy, lessThan(832));
      // Verify the controls are actually painted and tappable, not merely
      // present in the widget tree (the reported Android failure was blank).
      expect(find.text('شروع بازی').hitTestable(), findsOneWidget);
      await tester.tap(find.text('شروع بازی'));
      await tester.pumpAndSettle();
      expect(find.text('تاس بریز'), findsOneWidget);
      expect(find.text('قانون'), findsOneWidget);
      expect(find.text('تاس بریز').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('Ludo player cards render for two, three and four players on a phone', (tester) async {
      tester.view.physicalSize = const Size(384, 832);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: FunZonePage()));
      await tester.tap(find.text('لودو'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('شروع بازی'));
      await tester.pumpAndSettle();
      expect(find.text('تاس بریز'), findsOneWidget);
      expect(find.byKey(const ValueKey('ludo-die-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('ludo-die-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('ludo-die-0')).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('بازی تازه'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('۴ نفر'));
      await tester.tap(find.text('شروع بازی'));
      await tester.pumpAndSettle();
      expect(find.text('تاس بریز'), findsOneWidget);
      expect(find.text('سرخ'), findsOneWidget);
      expect(find.text('آبی'), findsOneWidget);
      expect(find.text('زرد'), findsOneWidget);
      expect(find.text('سبز'), findsOneWidget);
      for (var player = 0; player < 4; player++) {
        expect(find.byKey(ValueKey('ludo-die-$player')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('ludo-die-0')).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

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
