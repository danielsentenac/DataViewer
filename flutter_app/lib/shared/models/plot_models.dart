enum SamplingMode {
  raw('raw'),
  minmaxBucket('minmax_bucket');

  const SamplingMode(this.wireValue);

  final String wireValue;

  static SamplingMode fromWireValue(String? value) {
    return SamplingMode.values.firstWhere(
      (mode) => mode.wireValue == value,
      orElse: () => SamplingMode.raw,
    );
  }
}

class TimeRangeRequest {
  const TimeRangeRequest({required this.startLocalIso, required this.timeZone});

  final String startLocalIso;
  final String timeZone;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'startLocalIso': startLocalIso,
      'timeZone': timeZone,
    };
  }
}

class SamplingRequest {
  const SamplingRequest({
    this.targetBuckets = 720,
    this.preserveExtrema = true,
  });

  final int targetBuckets;
  final bool preserveExtrema;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'targetBuckets': targetBuckets,
      'preserveExtrema': preserveExtrema,
    };
  }
}

class PlotQueryRequest {
  const PlotQueryRequest({
    required this.channels,
    required this.timeRange,
    this.sampling = const SamplingRequest(),
    this.historyChunkSeconds,
    this.historyCursorUtcMs,
    this.historyTargetEndUtcMs,
  });

  final List<String> channels;
  final TimeRangeRequest timeRange;
  final SamplingRequest sampling;
  final int? historyChunkSeconds;
  final int? historyCursorUtcMs;
  final int? historyTargetEndUtcMs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channels': channels,
      'timeRange': timeRange.toJson(),
      'sampling': sampling.toJson(),
      if (historyChunkSeconds != null)
        'historyChunkSeconds': historyChunkSeconds,
      if (historyCursorUtcMs != null) 'historyCursorUtcMs': historyCursorUtcMs,
      if (historyTargetEndUtcMs != null)
        'historyTargetEndUtcMs': historyTargetEndUtcMs,
    };
  }
}

class PlotQueryMeta {
  const PlotQueryMeta({
    required this.channelCount,
    required this.resolvedStartUtcMs,
    required this.resolvedStartGps,
    required this.endUtcMs,
    required this.loadedEndUtcMs,
    required this.historyComplete,
    this.nextChunkStartUtcMs,
  });

  final int channelCount;
  final int resolvedStartUtcMs;
  final int resolvedStartGps;
  final int endUtcMs;
  final int loadedEndUtcMs;
  final bool historyComplete;
  final int? nextChunkStartUtcMs;

  factory PlotQueryMeta.fromJson(Map<String, dynamic> json) {
    final endUtcMs = (json['endUtcMs'] as num? ?? 0).toInt();
    final nextChunkStartUtcMs = (json['nextChunkStartUtcMs'] as num?)?.toInt();
    return PlotQueryMeta(
      channelCount: (json['channelCount'] as num? ?? 0).toInt(),
      resolvedStartUtcMs: (json['resolvedStartUtcMs'] as num? ?? 0).toInt(),
      resolvedStartGps: (json['resolvedStartGps'] as num? ?? 0).toInt(),
      endUtcMs: endUtcMs,
      loadedEndUtcMs: (json['loadedEndUtcMs'] as num? ?? endUtcMs).toInt(),
      nextChunkStartUtcMs: nextChunkStartUtcMs,
      historyComplete:
          json['historyComplete'] as bool? ?? nextChunkStartUtcMs == null,
    );
  }
}

class LiveDirective {
  const LiveDirective({
    required this.mode,
    required this.recommendedPollMs,
    required this.resumeAfterUtcMs,
  });

  final String mode;
  final int recommendedPollMs;
  final int resumeAfterUtcMs;

  factory LiveDirective.fromJson(Map<String, dynamic> json) {
    return LiveDirective(
      mode: json['mode'] as String? ?? 'poll',
      recommendedPollMs: (json['recommendedPollMs'] as num? ?? 1000).toInt(),
      resumeAfterUtcMs: (json['resumeAfterUtcMs'] as num? ?? 0).toInt(),
    );
  }
}

abstract class PlotSeries {
  const PlotSeries({
    required this.channel,
    required this.displayName,
    required this.unit,
    required this.samplingMode,
  });

  final String channel;
  final String displayName;
  final String unit;
  final SamplingMode samplingMode;

  factory PlotSeries.fromJson(Map<String, dynamic> json) {
    final mode = SamplingMode.fromWireValue(json['samplingMode'] as String?);
    switch (mode) {
      case SamplingMode.raw:
        return RawPlotSeries.fromJson(json);
      case SamplingMode.minmaxBucket:
        return BucketedPlotSeries.fromJson(json);
    }
  }
}

class RawPoint {
  const RawPoint({required this.utcMs, required this.value});

  final int utcMs;
  final double? value;

  DateTime get utcTimestamp =>
      DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);

  DateTime get localTimestamp => utcTimestamp.toLocal();
}

class RawPlotSeries extends PlotSeries {
  RawPlotSeries({
    required super.channel,
    required super.displayName,
    required super.unit,
    required this.startUtcMs,
    required this.stepMs,
    required this.values,
  }) : super(samplingMode: SamplingMode.raw);

  final int startUtcMs;
  final int stepMs;
  final List<double?> values;

  factory RawPlotSeries.fromJson(Map<String, dynamic> json) {
    return RawPlotSeries(
      channel: json['channel'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      startUtcMs: (json['startUtcMs'] as num? ?? 0).toInt(),
      stepMs: (json['stepMs'] as num? ?? 1000).toInt(),
      values: _readNullableDoubleList(json['values']),
    );
  }

  List<RawPoint> expandSamples() {
    return List<RawPoint>.generate(values.length, (int index) {
      return RawPoint(
        utcMs: startUtcMs + (index * stepMs),
        value: values[index],
      );
    }, growable: false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channel': channel,
      'displayName': displayName,
      'unit': unit,
      'samplingMode': samplingMode.wireValue,
      'startUtcMs': startUtcMs,
      'stepMs': stepMs,
      'values': values,
    };
  }
}

class BucketPoint {
  const BucketPoint({
    required this.utcMs,
    required this.minValue,
    required this.maxValue,
  });

  final int utcMs;
  final double? minValue;
  final double? maxValue;
}

class BucketedPlotSeries extends PlotSeries {
  BucketedPlotSeries({
    required super.channel,
    required super.displayName,
    required super.unit,
    required this.startUtcMs,
    required this.bucketSeconds,
    required this.minValues,
    required this.maxValues,
  }) : super(samplingMode: SamplingMode.minmaxBucket);

  final int startUtcMs;
  final int bucketSeconds;
  final List<double?> minValues;
  final List<double?> maxValues;

  factory BucketedPlotSeries.fromJson(Map<String, dynamic> json) {
    return BucketedPlotSeries(
      channel: json['channel'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      startUtcMs: (json['startUtcMs'] as num? ?? 0).toInt(),
      bucketSeconds: (json['bucketSeconds'] as num? ?? 60).toInt(),
      minValues: _readNullableDoubleList(json['minValues']),
      maxValues: _readNullableDoubleList(json['maxValues']),
    );
  }

  List<BucketPoint> expandBuckets() {
    final length = minValues.length > maxValues.length
        ? minValues.length
        : maxValues.length;
    return List<BucketPoint>.generate(length, (int index) {
      return BucketPoint(
        utcMs: startUtcMs + (index * bucketSeconds * 1000),
        minValue: index < minValues.length ? minValues[index] : null,
        maxValue: index < maxValues.length ? maxValues[index] : null,
      );
    }, growable: false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channel': channel,
      'displayName': displayName,
      'unit': unit,
      'samplingMode': samplingMode.wireValue,
      'startUtcMs': startUtcMs,
      'bucketSeconds': bucketSeconds,
      'minValues': minValues,
      'maxValues': maxValues,
    };
  }
}

class PlotQueryResponse {
  const PlotQueryResponse({
    required this.query,
    required this.series,
    required this.live,
  });

  final PlotQueryMeta query;
  final List<PlotSeries> series;
  final LiveDirective live;

  factory PlotQueryResponse.fromJson(Map<String, dynamic> json) {
    final series = (json['series'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (dynamic item) =>
              PlotSeries.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    final queryJson = _readJsonMap(json['query']);
    final liveJson = _readJsonMap(json['live']);

    return PlotQueryResponse(
      query: PlotQueryMeta.fromJson(queryJson),
      series: series,
      live: LiveDirective.fromJson(liveJson),
    );
  }
}

class LivePlotRequest {
  const LivePlotRequest({required this.channels, required this.afterUtcMs});

  final List<String> channels;
  final int afterUtcMs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'channels': channels, 'afterUtcMs': afterUtcMs};
  }
}

class LivePlotSeries {
  const LivePlotSeries({
    required this.channel,
    required this.startUtcMs,
    required this.stepMs,
    required this.values,
  });

  final String channel;
  final int startUtcMs;
  final int stepMs;
  final List<double?> values;

  factory LivePlotSeries.fromJson(Map<String, dynamic> json) {
    return LivePlotSeries(
      channel: json['channel'] as String? ?? '',
      startUtcMs: (json['startUtcMs'] as num? ?? 0).toInt(),
      stepMs: (json['stepMs'] as num? ?? 1000).toInt(),
      values: _readNullableDoubleList(json['values']),
    );
  }

  List<RawPoint> expandSamples() {
    return List<RawPoint>.generate(values.length, (int index) {
      return RawPoint(
        utcMs: startUtcMs + (index * stepMs),
        value: values[index],
      );
    }, growable: false);
  }
}

class LivePlotResponse {
  const LivePlotResponse({required this.serverNowUtcMs, required this.series});

  final int serverNowUtcMs;
  final List<LivePlotSeries> series;

  factory LivePlotResponse.fromJson(Map<String, dynamic> json) {
    final series = (json['series'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (dynamic item) =>
              LivePlotSeries.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);

    return LivePlotResponse(
      serverNowUtcMs: (json['serverNowUtcMs'] as num? ?? 0).toInt(),
      series: series,
    );
  }
}

List<double?> _readNullableDoubleList(Object? source) {
  final values = source as List<dynamic>? ?? const <dynamic>[];
  return values
      .map((dynamic item) => item == null ? null : (item as num).toDouble())
      .toList(growable: false);
}

Map<String, dynamic> _readJsonMap(Object? source) {
  if (source is Map<String, dynamic>) {
    return source;
  }

  if (source is Map) {
    return Map<String, dynamic>.from(source);
  }

  return const <String, dynamic>{};
}
