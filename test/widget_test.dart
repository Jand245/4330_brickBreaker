import 'package:brick_breaker/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('game starts on ready screen', (tester) async {
    await tester.pumpWidget(const BrickBreakerApp());
    expect(find.byType(BrickBreakerPage), findsOneWidget);
  });
}
