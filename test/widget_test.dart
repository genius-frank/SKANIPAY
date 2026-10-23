import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skanipay/main.dart';
import 'package:skanipay/confirm_screen.dart';

void main() {
  testWidgets('SkaniPay App renders title and service options', (WidgetTester tester) async {
    await tester.pumpWidget(const SkaniPayApp());

    expect(find.text('SkaniPay'), findsOneWidget);
    expect(find.text('Quick Payments'), findsOneWidget);
    expect(find.text('Send Money'), findsOneWidget);
    expect(find.text('Buy Goods'), findsOneWidget);
    expect(find.text('Pay Bill'), findsOneWidget);
    expect(find.text('Airtime'), findsOneWidget);
    expect(find.text('Withdraw'), findsOneWidget);
    expect(find.text('Pochi'), findsOneWidget);
  });

  testWidgets('ConfirmScreen renders correctly for Send Money', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ConfirmScreen(
          serviceType: 'Send Money',
          scannedNumber: '0712345678',
        ),
      ),
    );

    expect(find.text('Send Money'), findsOneWidget);
    expect(find.text('Confirm Details'), findsOneWidget);
    expect(find.text('0712345678'), findsOneWidget);
    expect(find.text('PROCEED SECURELY'), findsOneWidget);
    expect(find.text('COPY NUMBER'), findsOneWidget);
  });

  testWidgets('ConfirmScreen renders Pay Bill account field', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ConfirmScreen(
          serviceType: 'Pay Bill',
          scannedNumber: '522522',
          scannedAccount: '12345678',
        ),
      ),
    );

    expect(find.text('Pay Bill'), findsOneWidget);
    expect(find.text('522522'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
  });
}
