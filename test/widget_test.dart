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
      await tester.ensureVisible(game);
      await tester.pumpAndSettle();
      await tester.tap(game);
      await tester.pumpAndSettle();
      if (title == 'چهار در یک خط' || title == 'بازی دونفره') {
        await tester.tap(find.text('آفلاین دونفره'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('Connect Four opens with turn and rules', (tester) async {
      await openGame(tester, 'چهار در یک خط');
      expect(find.text('نوبت بازیکن X'), findsOneWidget);
      expect(find.textContaining('چهار مهره را افقی'), findsOneWidget);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('Connect Four recognizes a horizontal win', (tester) async {
      await openGame(tester, 'چهار در یک خط');
      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      expect(cells, findsNWidgets(42));
      for (final column in [0, 0, 1, 1, 2, 2, 3]) {
        await tester.tap(cells.at(column));
        await tester.pump();
      }
      expect(find.text('بازیکن X برنده شد!'), findsOneWidget);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('Connect Four recognizes a vertical win', (tester) async {
      await openGame(tester, 'چهار در یک خط');
      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      for (final column in [0, 1, 0, 1, 0, 1, 0]) {
        await tester.tap(cells.at(column));
        await tester.pump();
      }
      expect(find.text('بازیکن X برنده شد!'), findsOneWidget);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('Connect Four rejects a move in a full column', (tester) async {
      await openGame(tester, 'چهار در یک خط');
      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(GestureDetector),
      );
      for (var move = 0; move < 6; move++) {
        await tester.tap(cells.at(0));
        await tester.pump();
      }
      await tester.tap(cells.at(0));
      await tester.pump();
      expect(find.text('این ستون پُر است.'), findsOneWidget);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('Tic Tac Toe detects a three-in-a-row win', (tester) async {
      await openGame(tester, 'بازی دونفره');
      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      expect(cells, findsNWidgets(9));
      for (final index in [0, 3, 1, 4, 2]) {
        await tester.tap(cells.at(index));
        await tester.pump();
      }
      expect(find.text('بازیکن X برنده شد!'), findsOneWidget);
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
