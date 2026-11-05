import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';

void main() {
  testWidgets('app boots to the placeholder home', (tester) async {
    await tester.pumpWidget(const PawPassApp());
    await tester.pumpAndSettle();
    expect(find.text('PawPass'), findsOneWidget);
  });
}
