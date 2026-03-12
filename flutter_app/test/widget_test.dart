import 'package:dataviewer/features/plot_view/presentation/plot_screen.dart';
import 'package:dataviewer/shared/models/plot_view_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plot screen renders summary for a request', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlotScreen(
          request: PlotViewRequest(
            channels: const <String>['V1:TEST_CHANNEL'],
            startLocal: DateTime(2026, 3, 12, 17, 0),
            sourceLabel: '1 h',
          ),
        ),
      ),
    );

    expect(find.text('Plots'), findsOneWidget);
    expect(find.text('Plot workspace'), findsOneWidget);
    expect(find.textContaining('1 channel(s)'), findsOneWidget);
  });
}
