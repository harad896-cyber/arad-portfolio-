import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileGate(),
      ),
    );
    await tester.pump();
    expect(find.byType(ProfileGate), findsOneWidget);
  });
}
