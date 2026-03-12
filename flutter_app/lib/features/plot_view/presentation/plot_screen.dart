import 'dart:async';
import 'dart:collection';

import 'package:dataviewer/features/plot_view/presentation/plot_view_providers.dart';
import 'package:dataviewer/shared/models/plot_models.dart';
import 'package:dataviewer/shared/models/plot_view_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class PlotScreen extends ConsumerStatefulWidget {
  const PlotScreen({super.key, this.request});

  final PlotViewRequest? request;

  @override
  ConsumerState<PlotScreen> createState() => _PlotScreenState();
}

class _PlotScreenState extends ConsumerState<PlotScreen> {
  static const List<Color> _palette = <Color>[
    Color(0xFF0B6E75),
    Color(0xFFD95D39),
    Color(0xFF5B8E7D),
    Color(0xFF6C5CE7),
    Color(0xFFC97A40),
    Color(0xFF0081A7),
  ];

  final Map<String, SplayTreeMap<int, double?>> _liveValuesByChannel =
      <String, SplayTreeMap<int, double?>>{};

  PlotQueryResponse? _response;
  Timer? _liveTimer;
  bool _isLoading = false;
  bool _isPollingLive = false;
  bool _overlayCharts = false;
  bool _logScale = false;
  String? _error;
  String? _liveError;
  int _lastLiveAfterUtcMs = 0;
  int _lastServerNowUtcMs = 0;

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    _overlayCharts = request != null && request.channels.length <= 3;
    if (request != null) {
      _loadPlot();
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlot() async {
    final request = widget.request;
    if (request == null) {
      return;
    }

    _liveTimer?.cancel();
    setState(() {
      _isLoading = true;
      _error = null;
      _liveError = null;
      _response = null;
      _lastLiveAfterUtcMs = 0;
      _lastServerNowUtcMs = 0;
      _liveValuesByChannel.clear();
    });

    try {
      final repository = ref.read(plotRepositoryProvider);
      final response = await repository.queryPlot(
        PlotQueryRequest(
          channels: request.channels,
          timeRange: TimeRangeRequest(
            startLocalIso: request.startLocalIso,
            timeZone: request.timeZoneOffsetLabel,
          ),
          sampling: SamplingRequest(
            targetBuckets: _targetBucketsFor(request),
            preserveExtrema: true,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _response = response;
        _lastLiveAfterUtcMs = response.live.resumeAfterUtcMs;
        _lastServerNowUtcMs = response.query.endUtcMs;
      });
      await _pollLive();
      _startLivePolling();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startLivePolling() {
    final liveDirective = _response?.live;
    if (liveDirective == null || liveDirective.mode != 'poll') {
      return;
    }

    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(
      Duration(milliseconds: liveDirective.recommendedPollMs),
      (_) {
        _pollLive();
      },
    );
  }

  Future<void> _pollLive() async {
    final request = widget.request;
    final response = _response;
    if (request == null || response == null || _isPollingLive) {
      return;
    }

    setState(() {
      _isPollingLive = true;
    });
    try {
      final repository = ref.read(plotRepositoryProvider);
      final liveResponse = await repository.pollLive(
        LivePlotRequest(
          channels: request.channels,
          afterUtcMs: _lastLiveAfterUtcMs,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        for (final LivePlotSeries series in liveResponse.series) {
          final buffer = _liveValuesByChannel.putIfAbsent(
            series.channel,
            () => SplayTreeMap<int, double?>(),
          );
          for (final RawPoint point in series.expandSamples()) {
            buffer[point.utcMs] = point.value;
          }
        }
        _lastServerNowUtcMs = liveResponse.serverNowUtcMs;
        if (liveResponse.serverNowUtcMs > _lastLiveAfterUtcMs) {
          _lastLiveAfterUtcMs = liveResponse.serverNowUtcMs;
        }
        _liveError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveError = error.toString();
      });
    } finally {
      if (!mounted) {
        _isPollingLive = false;
      } else {
        setState(() {
          _isPollingLive = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final theme = Theme.of(context);

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plots')),
        body: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'No plot request was provided.',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back to selection'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final charts = _buildCharts(request);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plots'),
        actions: <Widget>[
          IconButton(
            onPressed: _isLoading ? null : _loadPlot,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildSummaryCard(request, theme),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildControlRow(theme),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (_liveError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Live polling degraded: $_liveError',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : charts.isEmpty
                      ? Center(
                          child: Text(
                            'Waiting for the first history or live samples.',
                            style: theme.textTheme.titleMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: charts.length,
                          separatorBuilder: (BuildContext context, int index) {
                            return const SizedBox(height: 12);
                          },
                          itemBuilder: (BuildContext context, int index) {
                            final chart = charts[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: SizedBox(
                                  height: 320,
                                  child: SfCartesianChart(
                                    title: ChartTitle(text: chart.title),
                                    legend: Legend(
                                      isVisible: chart.legendVisible,
                                      position: LegendPosition.bottom,
                                    ),
                                    zoomPanBehavior: ZoomPanBehavior(
                                      enablePinching: true,
                                      enablePanning: true,
                                      enableMouseWheelZooming: true,
                                      zoomMode: ZoomMode.x,
                                    ),
                                    trackballBehavior: TrackballBehavior(
                                      enable: true,
                                      activationMode: ActivationMode.singleTap,
                                    ),
                                    primaryXAxis: DateTimeAxis(
                                      edgeLabelPlacement:
                                          EdgeLabelPlacement.shift,
                                    ),
                                    primaryYAxis: _logScale
                                        ? LogarithmicAxis(logBase: 10)
                                        : NumericAxis(),
                                    series: chart.series,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(PlotViewRequest request, ThemeData theme) {
    final response = _response;
    final historyEnd = response == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            response.query.endUtcMs,
            isUtc: true,
          ).toLocal();
    final liveNow = _lastServerNowUtcMs <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            _lastServerNowUtcMs,
            isUtc: true,
          ).toLocal();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Plot workspace',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${request.channels.length} channel(s) from ${_formatDateTime(request.startLocal)} '
              'using ${request.sourceLabel == 'Custom' ? 'a custom local start' : request.sourceLabel} '
              '(UTC${request.timeZoneOffsetLabel}).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(
                  icon: Icons.history,
                  label: historyEnd == null
                      ? 'History pending'
                      : 'History to ${_formatDateTime(historyEnd)}',
                ),
                _InfoChip(
                  icon: Icons.wifi_tethering,
                  label: liveNow == null
                      ? 'Live waiting'
                      : 'Live to ${_formatDateTime(liveNow)}',
                ),
                _InfoChip(
                  icon: Icons.bubble_chart,
                  label: _response == null
                      ? 'No series yet'
                      : '${_response!.series.length} history series',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow(ThemeData theme) {
    return Row(
      children: <Widget>[
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: false, label: Text('Split')),
            ButtonSegment<bool>(value: true, label: Text('Overlay')),
          ],
          selected: <bool>{_overlayCharts},
          onSelectionChanged: (Set<bool> value) {
            setState(() {
              _overlayCharts = value.first;
            });
          },
        ),
        const SizedBox(width: 12),
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: false, label: Text('Linear')),
            ButtonSegment<bool>(value: true, label: Text('Log')),
          ],
          selected: <bool>{_logScale},
          onSelectionChanged: (Set<bool> value) {
            setState(() {
              _logScale = value.first;
            });
          },
        ),
        const Spacer(),
        Text(
          _isPollingLive ? 'Polling...' : 'Live ready',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  List<_ChartBundle> _buildCharts(PlotViewRequest request) {
    final response = _response;
    if (response == null) {
      return const <_ChartBundle>[];
    }

    if (_overlayCharts) {
      return <_ChartBundle>[
        _ChartBundle(
          title: 'All selected channels',
          legendVisible: true,
          series: _buildSeriesForChannels(request.channels, splitMode: false),
        ),
      ];
    }

    return List<_ChartBundle>.generate(request.channels.length, (int index) {
      final channel = request.channels[index];
      return _ChartBundle(
        title: channel,
        legendVisible: false,
        series: _buildSeriesForChannels(<String>[channel], splitMode: true),
      );
    }, growable: false);
  }

  List<CartesianSeries<dynamic, DateTime>> _buildSeriesForChannels(
    List<String> channels, {
    required bool splitMode,
  }) {
    final response = _response;
    if (response == null) {
      return const <CartesianSeries<dynamic, DateTime>>[];
    }

    final seriesByChannel = <String, PlotSeries>{
      for (final PlotSeries series in response.series) series.channel: series,
    };
    final chartSeries = <CartesianSeries<dynamic, DateTime>>[];

    for (int index = 0; index < channels.length; index++) {
      final channel = channels[index];
      final color = _palette[index % _palette.length];
      final historySeries = seriesByChannel[channel];
      final liveSeries = _expandLivePoints(channel);

      if (historySeries is RawPlotSeries) {
        final points = _sanitizeLinePoints(historySeries.expandSamples());
        chartSeries.add(
          LineSeries<RawPoint, DateTime>(
            dataSource: points,
            xValueMapper: (RawPoint point, _) => point.localTimestamp,
            yValueMapper: (RawPoint point, _) => point.value,
            name: historySeries.displayName,
            color: color,
            width: 2,
          ),
        );
      }

      if (historySeries is BucketedPlotSeries) {
        final bucketPoints =
            _sanitizeBucketPoints(historySeries.expandBuckets());
        if (splitMode) {
          chartSeries.add(
            RangeAreaSeries<BucketPoint, DateTime>(
              dataSource: bucketPoints,
              xValueMapper: (BucketPoint point, _) =>
                  DateTime.fromMillisecondsSinceEpoch(point.utcMs, isUtc: true)
                      .toLocal(),
              lowValueMapper: (BucketPoint point, _) => point.minValue,
              highValueMapper: (BucketPoint point, _) => point.maxValue,
              name: '${historySeries.displayName} band',
              color: color.withValues(alpha: 0.16),
              borderColor: color.withValues(alpha: 0.45),
            ),
          );
        }
        chartSeries.add(
          LineSeries<_LinePoint, DateTime>(
            dataSource: _bucketMidpoints(bucketPoints),
            xValueMapper: (_LinePoint point, _) => point.time,
            yValueMapper: (_LinePoint point, _) => point.value,
            name: splitMode
                ? historySeries.displayName
                : '${historySeries.displayName} avg',
            color: color,
            width: splitMode ? 2 : 2.5,
          ),
        );
      }

      if (liveSeries.isNotEmpty) {
        chartSeries.add(
          LineSeries<RawPoint, DateTime>(
            dataSource: liveSeries,
            xValueMapper: (RawPoint point, _) => point.localTimestamp,
            yValueMapper: (RawPoint point, _) => point.value,
            name: splitMode ? 'Live' : '$channel live',
            color: color.withValues(alpha: 0.9),
            width: 2,
            dashArray: const <double>[6, 4],
          ),
        );
      }
    }

    return chartSeries;
  }

  List<RawPoint> _expandLivePoints(String channel) {
    final values = _liveValuesByChannel[channel];
    if (values == null || values.isEmpty) {
      return const <RawPoint>[];
    }
    final points = values.entries.map((MapEntry<int, double?> entry) {
      return RawPoint(utcMs: entry.key, value: entry.value);
    }).toList(growable: false);
    return _sanitizeLinePoints(points);
  }

  List<RawPoint> _sanitizeLinePoints(List<RawPoint> points) {
    if (!_logScale) {
      return points;
    }
    return points
        .map((RawPoint point) => RawPoint(
              utcMs: point.utcMs,
              value:
                  point.value != null && point.value! > 0 ? point.value : null,
            ))
        .toList(growable: false);
  }

  List<BucketPoint> _sanitizeBucketPoints(List<BucketPoint> points) {
    if (!_logScale) {
      return points;
    }
    return points.map((BucketPoint point) {
      final minValue =
          point.minValue != null && point.minValue! > 0 ? point.minValue : null;
      final maxValue =
          point.maxValue != null && point.maxValue! > 0 ? point.maxValue : null;
      if (minValue == null || maxValue == null) {
        return BucketPoint(utcMs: point.utcMs, minValue: null, maxValue: null);
      }
      return BucketPoint(
        utcMs: point.utcMs,
        minValue: minValue,
        maxValue: maxValue,
      );
    }).toList(growable: false);
  }

  List<_LinePoint> _bucketMidpoints(List<BucketPoint> points) {
    return points.map((BucketPoint point) {
      final value = point.minValue == null || point.maxValue == null
          ? null
          : (point.minValue! + point.maxValue!) / 2;
      return _LinePoint(
        time: DateTime.fromMillisecondsSinceEpoch(point.utcMs, isUtc: true)
            .toLocal(),
        value: value,
      );
    }).toList(growable: false);
  }

  int _targetBucketsFor(PlotViewRequest request) {
    final span = DateTime.now().difference(request.startLocal);
    if (span <= const Duration(hours: 2) && request.channels.length <= 3) {
      return 10000;
    }
    if (span <= const Duration(hours: 12) && request.channels.length <= 2) {
      return 4000;
    }
    if (span <= const Duration(days: 1) && request.channels.length == 1) {
      return 3000;
    }
    return 720;
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ChartBundle {
  const _ChartBundle({
    required this.title,
    required this.legendVisible,
    required this.series,
  });

  final String title;
  final bool legendVisible;
  final List<CartesianSeries<dynamic, DateTime>> series;
}

class _LinePoint {
  const _LinePoint({required this.time, required this.value});

  final DateTime time;
  final double? value;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
