import 'dart:math' as math;

class PlotAxisValueFormatter {
  PlotAxisValueFormatter._({
    required double referenceMagnitude,
    required double? interval,
    required this.fixedDecimalPlaces,
    required this.useScientificNotation,
    required this.scientificFractionDigits,
  })  : _referenceMagnitude = referenceMagnitude,
        _interval = interval;

  factory PlotAxisValueFormatter.forAxis({
    double? minimum,
    double? maximum,
    double? interval,
    int maxFixedDecimals = 6,
    int scientificFractionDigits = 2,
  }) {
    final normalizedInterval =
        interval != null && interval.isFinite && interval > 0
            ? interval.abs()
            : null;
    final referenceMagnitude = math.max(
      minimum?.abs() ?? 0,
      maximum?.abs() ?? 0,
    );
    final fixedDecimalPlaces = _fixedDecimalPlacesForInterval(
      normalizedInterval,
      maxFixedDecimals,
    );
    return PlotAxisValueFormatter._(
      referenceMagnitude: referenceMagnitude,
      interval: normalizedInterval,
      fixedDecimalPlaces: fixedDecimalPlaces,
      useScientificNotation: _shouldUseScientificNotation(
        referenceMagnitude,
        normalizedInterval,
        fixedDecimalPlaces,
      ),
      scientificFractionDigits: scientificFractionDigits,
    );
  }

  final double _referenceMagnitude;
  final double? _interval;
  final int fixedDecimalPlaces;
  final bool useScientificNotation;
  final int scientificFractionDigits;

  String format(num rawValue) {
    final value = rawValue.toDouble();
    if (!value.isFinite) {
      return '';
    }
    final normalized = _normalizeNearZero(value);
    if (normalized == 0) {
      return '0';
    }
    return useScientificNotation
        ? _formatScientific(normalized)
        : _formatFixed(normalized);
  }

  double _normalizeNearZero(double value) {
    final scale = math.max(
      math.max(_referenceMagnitude, _interval ?? 0),
      value.abs(),
    );
    final threshold = math.max(scale * 1e-9, 1e-12);
    if (value.abs() < threshold) {
      return 0;
    }
    return value;
  }

  String _formatFixed(double value) {
    final text = value.toStringAsFixed(fixedDecimalPlaces);
    return _trimTrailingZeros(text);
  }

  String _formatScientific(double value) {
    final text = value.toStringAsExponential(scientificFractionDigits);
    final parts = text.split('e');
    final mantissa = _trimTrailingZeros(parts.first);
    final exponent = parts.last
        .replaceFirst('+', '')
        .replaceFirst(RegExp(r'^(-?)0+(\d)'), r'$1$2');
    return '${mantissa}E$exponent';
  }

  String _trimTrailingZeros(String value) {
    if (!value.contains('.')) {
      return value == '-0' ? '0' : value;
    }
    var trimmed = value;
    while (trimmed.endsWith('0')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed == '-0' ? '0' : trimmed;
  }

  static int _fixedDecimalPlacesForInterval(
    double? interval,
    int maxFixedDecimals,
  ) {
    if (interval == null || !interval.isFinite || interval <= 0) {
      return 2;
    }
    if (interval >= 1) {
      return 0;
    }
    final decimals = (-math.log(interval) / math.ln10).ceil();
    return math.max(0, math.min(maxFixedDecimals, decimals));
  }

  static bool _shouldUseScientificNotation(
    double referenceMagnitude,
    double? interval,
    int fixedDecimalPlaces,
  ) {
    if (referenceMagnitude == 0) {
      return false;
    }
    if (referenceMagnitude >= 1e4) {
      return true;
    }
    if (referenceMagnitude < 1e-3) {
      return true;
    }
    if (fixedDecimalPlaces > 4) {
      return true;
    }
    return interval != null && interval >= 1e4;
  }
}
