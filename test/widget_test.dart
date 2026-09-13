import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(const ProfileGate());
    await tester.pumpAndSettle();
    expect(find.byType(ProfileGate), findsOneWidget);
  });
}
