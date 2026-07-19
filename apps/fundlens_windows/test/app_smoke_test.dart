import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/main.dart';

void main() {
  testWidgets('boots the Windows shell', (tester) async {
    await tester.pumpWidget(const FundLensBootstrapApp());
    expect(find.text('FundLens'), findsOneWidget);
  });
}
