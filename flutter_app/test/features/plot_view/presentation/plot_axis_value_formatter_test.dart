import 'package:dataviewer/features/plot_view/presentation/plot_axis_value_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses fixed decimals for medium ranges', () {
    final formatter = PlotAxisValueFormatter.forAxis(
      minimum: 20.074,
      maximum: 20.082,
      interval: 0.002,
    );

    expect(formatter.useScientificNotation, isFalse);
    expect(formatter.format(20.078), '20.078');
  });

  test('keeps small fixed-point ticks distinct', () {
    final formatter = PlotAxisValueFormatter.forAxis(
      minimum: 0.1234,
      maximum: 0.1246,
      interval: 0.0002,
    );

    expect(formatter.useScientificNotation, isFalse);
    expect(formatter.format(0.1242), '0.1242');
  });

  test('switches to scientific notation for tiny values', () {
    final formatter = PlotAxisValueFormatter.forAxis(
      minimum: 0.00001,
      maximum: 0.00003,
      interval: 0.000005,
    );

    expect(formatter.useScientificNotation, isTrue);
    expect(formatter.format(0.000015), '1.5E-5');
  });

  test('switches to scientific notation for large magnitudes', () {
    final formatter = PlotAxisValueFormatter.forAxis(
      minimum: 120000,
      maximum: 180000,
      interval: 20000,
    );

    expect(formatter.useScientificNotation, isTrue);
    expect(formatter.format(140000), '1.4E5');
  });

  test('normalizes near-zero values to zero', () {
    final formatter = PlotAxisValueFormatter.forAxis(
      minimum: -1,
      maximum: 1,
      interval: 0.2,
    );

    expect(formatter.format(1e-13), '0');
  });
}
