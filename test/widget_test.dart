import 'package:flutter_test/flutter_test.dart';

import 'package:evelyn_vpn/main.dart';

void main() {
  testWidgets('Evelyn VPN smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EvelynVpnApp());
    await tester.pump();
    expect(find.text('Evelyn VPN'), findsWidgets);
    expect(find.text('اتصال'), findsOneWidget);
    expect(find.text('دانلود'), findsOneWidget);
    expect(find.text('آپلود'), findsOneWidget);
    expect(find.text('سرورها'), findsOneWidget);
  });
}
