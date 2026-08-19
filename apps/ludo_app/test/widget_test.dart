import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_app/core/theme/app_theme.dart';

void main() {
  testWidgets('Persian themed shell renders RTL content', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: Text('منچ ایرانی'))),
    ));
    expect(find.text('منچ ایرانی'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('منچ ایرانی'))), TextDirection.rtl);
  });
}
