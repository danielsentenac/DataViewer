import 'package:dataviewer/features/plot_view/presentation/plot_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('plot scaffold renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlotScreen(),
      ),
    );

    expect(find.text('Plot workspace scaffold'), findsOneWidget);
    expect(find.text('Plots'), findsOneWidget);
  });
}
