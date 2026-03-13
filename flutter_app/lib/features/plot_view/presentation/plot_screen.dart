import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:dataviewer/features/plot_view/presentation/plot_axis_value_formatter.dart';
import 'package:dataviewer/features/plot_view/presentation/plot_view_providers.dart';
import 'package:dataviewer/shared/models/plot_models.dart';
import 'package:dataviewer/shared/models/plot_view_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class PlotScreen extends ConsumerStatefulWidget {
  const PlotScreen({super.key, this.request});

  final PlotViewRequest? request;

  @override
  ConsumerState<PlotScreen> createState() => _PlotScreenState();
}

class _PlotScreenState extends ConsumerState<PlotScreen> {
  static const double _workspaceCompressOffset = 24;
  static const List<Color> _palette = <Color>[
    Color(0xFF0B6E75),
    Color(0xFFD95D39),
    Color(0xFF5B8E7D),
    Color(0xFF6C5CE7),
    Color(0xFFC97A40),
    Color(0xFF0081A7),
  ];
  static final NumberFormat _trackballNumberFormat = NumberFormat('0.00E0');

  final Map<String, SplayTreeMap<int, double?>> _liveValuesByChannel =
      <String, SplayTreeMap<int, double?>>{};
  final Map<String, SplayTreeMap<int, double?>> _deferredLiveValuesByChannel =
      <String, SplayTreeMap<int, double?>>{};
  final ScrollController _chartsScrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DateFormat _localTimeMinutesFormat = DateFormat('HH:mm');
  final DateFormat _localTimeSecondsFormat = DateFormat('HH:mm:ss');
  final DateFormat _trackballTimeFormat = DateFormat('HH:mm:ss');

  PlotQueryResponse? _response;
  Timer? _liveTimer;
  bool _isLoading = false;
  bool _isPollingLive = false;
  bool _isChartInteractionActive = false;
  bool _isWorkspaceHeaderCompact = false;
  bool _showSecondsOnXAxis = false;
  bool _overlayCharts = false;
  bool _logScale = false;
  String? _error;
  String? _liveError;
  String? _deferredLiveError;
  int? _deferredServerNowUtcMs;
  int? _deferredLastLiveAfterUtcMs;
  int _lastLiveAfterUtcMs = 0;
  int _lastServerNowUtcMs = 0;

  @override
  void initState() {
    super.initState();
    _chartsScrollController.addListener(_handleChartsScroll);
    _overlayCharts = false;
    final request = widget.request;
    if (request != null) {
      _loadPlot();
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _chartsScrollController
      ..removeListener(_handleChartsScroll)
      ..dispose();
    super.dispose();
  }

  void _handleChartsScroll() {
    final shouldCompress = _chartsScrollController.hasClients &&
        _chartsScrollController.offset > _workspaceCompressOffset;
    if (shouldCompress == _isWorkspaceHeaderCompact || !mounted) {
      return;
    }
    setState(() {
      _isWorkspaceHeaderCompact = shouldCompress;
    });
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
      _isWorkspaceHeaderCompact = false;
      _response = null;
      _lastLiveAfterUtcMs = 0;
      _lastServerNowUtcMs = 0;
      _deferredServerNowUtcMs = null;
      _deferredLastLiveAfterUtcMs = null;
      _deferredLiveError = null;
      _isChartInteractionActive = false;
      _showSecondsOnXAxis = false;
      _liveValuesByChannel.clear();
      _deferredLiveValuesByChannel.clear();
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

    _isPollingLive = true;
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
      if (_isChartInteractionActive) {
        _stageDeferredLiveUpdate(liveResponse);
        return;
      }
      _applyLiveUpdate(liveResponse);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isChartInteractionActive) {
        _deferredLiveError = error.toString();
        return;
      }
      setState(() {
        _liveError = error.toString();
      });
    } finally {
      _isPollingLive = false;
    }
  }

  void _openOptionsPanel() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _beginChartInteraction() {
    _isChartInteractionActive = true;
  }

  void _endChartInteraction() {
    if (!_isChartInteractionActive) {
      return;
    }
    _isChartInteractionActive = false;
    _flushDeferredLiveUpdate();
  }

  void _handleActualRangeChanged(ActualRangeChangedArgs args) {
    if (args.orientation != AxisOrientation.horizontal) {
      return;
    }

    final visibleMin = _asDateTime(args.visibleMin);
    final visibleMax = _asDateTime(args.visibleMax);
    if (visibleMin == null || visibleMax == null) {
      return;
    }

    final shouldShowSeconds =
        visibleMax.difference(visibleMin).abs() <= const Duration(minutes: 10);
    if (shouldShowSeconds == _showSecondsOnXAxis || !mounted) {
      return;
    }

    setState(() {
      _showSecondsOnXAxis = shouldShowSeconds;
    });
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }
    return null;
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
    final isWideLayout = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Plots'),
        actions: <Widget>[
          if (!isWideLayout)
            IconButton(
              onPressed: _openOptionsPanel,
              icon: const Icon(Icons.tune),
              tooltip: 'View options',
            ),
          IconButton(
            onPressed: _isLoading ? null : _loadPlot,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      endDrawer: isWideLayout
          ? null
          : Drawer(
              width: 360,
              child: SafeArea(
                child: _buildOptionsPanel(
                  theme,
                  request,
                  charts,
                  showDrawerHeading: true,
                ),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isWideLayout
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _buildMainPanel(
                        theme,
                        request,
                        charts,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 340,
                      child: _buildOptionsPanel(theme, request, charts),
                    ),
                  ],
                )
              : _buildMainPanel(
                  theme,
                  request,
                  charts,
                ),
        ),
      ),
    );
  }

  Widget _buildMainPanel(
    ThemeData theme,
    PlotViewRequest request,
    List<_ChartBundle> charts,
  ) {
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
    final mixedUnits =
        _overlayCharts && _unitsForChannels(request.channels).length > 1;
    final isCompact = _isWorkspaceHeaderCompact && charts.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Plot workspace',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 4 : 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _InfoChip(
                        icon: Icons.sensors,
                        label: '${request.channels.length} channel(s)',
                        compact: true,
                      ),
                      _InfoChip(
                        icon: Icons.history_toggle_off,
                        label: _historyFromLabel(request),
                        compact: true,
                      ),
                      _InfoChip(
                        icon: Icons.schedule,
                        label: 'UTC${request.timeZoneOffsetLabel}',
                        compact: true,
                      ),
                      if (!isCompact)
                        _InfoChip(
                          icon: Icons.history,
                          label: historyEnd == null
                              ? 'History pending'
                              : 'History to ${_formatDateTime(historyEnd)}',
                          compact: true,
                        ),
                      if (!isCompact)
                        _InfoChip(
                          icon: Icons.wifi_tethering,
                          label: liveNow == null
                              ? 'Live waiting'
                              : 'Live to ${_formatDateTime(liveNow)}',
                          compact: true,
                        ),
                      if (mixedUnits)
                        const _InfoChip(
                          icon: Icons.straighten,
                          label: 'Overlay mixes units',
                          compact: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (_liveError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: Text(
              'Live polling degraded: $_liveError',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 12),
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
                      controller: _chartsScrollController,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: charts.length,
                      separatorBuilder: (BuildContext context, int index) {
                        return const SizedBox(height: 14);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return _buildChartCard(
                          charts[index],
                          chartCount: charts.length,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildOptionsPanel(
    ThemeData theme,
    PlotViewRequest request,
    List<_ChartBundle> charts, {
    bool showDrawerHeading = false,
  }) {
    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'View options',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(
          'Chart arrangement',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),
        Text(
          'Y scale',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 16),
        Text(
          'Local time range',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Start: ${_formatDateTime(request.startLocal)} (UTC${request.timeZoneOffsetLabel})',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          request.sourceLabel == 'Custom'
              ? 'Custom local start'
              : 'Preset: ${request.sourceLabel}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Channels',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: request.channels
              .map(
                (String channel) => _InfoChip(
                  icon: Icons.sensors,
                  label: channel,
                  compact: true,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );

    if (showDrawerHeading) {
      return RepaintBoundary(child: content);
    }

    return RepaintBoundary(child: Card(child: content));
  }

  List<_ChartBundle> _buildCharts(PlotViewRequest request) {
    final response = _response;
    if (response == null) {
      return const <_ChartBundle>[];
    }

    final seriesByChannel = <String, PlotSeries>{
      for (final PlotSeries series in response.series) series.channel: series,
    };

    if (_overlayCharts) {
      return <_ChartBundle>[
        _ChartBundle(
          title: 'All selected channels',
          legendVisible: true,
          yAxisConfig: _buildYAxisConfig(request.channels, seriesByChannel),
          series: _buildSeriesForChannels(request.channels, splitMode: false),
        ),
      ];
    }

    return List<_ChartBundle>.generate(request.channels.length, (int index) {
      final channel = request.channels[index];
      final series = seriesByChannel[channel];
      return _ChartBundle(
        title: _displayNameForChannel(channel, series),
        legendVisible: false,
        yAxisConfig: _buildYAxisConfig(<String>[channel], seriesByChannel),
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
      final displayName = _displayNameForChannel(channel, historySeries);
      final liveSeries = _expandLivePoints(channel);

      if (historySeries is RawPlotSeries) {
        final points = _mergeRawHistoryAndLive(
          historySeries.expandSamples(),
          liveSeries,
        );
        chartSeries.add(
          LineSeries<RawPoint, DateTime>(
            dataSource: points,
            xValueMapper: (RawPoint point, _) => point.localTimestamp,
            yValueMapper: (RawPoint point, _) => point.value,
            name: displayName,
            color: color,
            width: 1.6,
          ),
        );
        continue;
      }

      if (historySeries is BucketedPlotSeries) {
        final bucketPoints =
            _sanitizeBucketPoints(historySeries.expandBuckets());
        chartSeries.add(
          LineSeries<_LinePoint, DateTime>(
            dataSource: _bucketMidpoints(bucketPoints),
            xValueMapper: (_LinePoint point, _) => point.time,
            yValueMapper: (_LinePoint point, _) => point.value,
            name: displayName,
            color: color,
            width: splitMode ? 1.4 : 1.6,
          ),
        );
      }

      if (liveSeries.isNotEmpty) {
        chartSeries.add(
          LineSeries<RawPoint, DateTime>(
            dataSource: liveSeries,
            xValueMapper: (RawPoint point, _) => point.localTimestamp,
            yValueMapper: (RawPoint point, _) => point.value,
            name: splitMode ? 'Live' : '$displayName live',
            color: color.withValues(alpha: 0.9),
            width: 1.2,
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

  List<RawPoint> _mergeRawHistoryAndLive(
    List<RawPoint> historyPoints,
    List<RawPoint> livePoints,
  ) {
    if (livePoints.isEmpty) {
      return _sanitizeLinePoints(historyPoints);
    }
    final merged = SplayTreeMap<int, double?>();
    for (final RawPoint point in historyPoints) {
      merged[point.utcMs] = point.value;
    }
    for (final RawPoint point in livePoints) {
      merged[point.utcMs] = point.value;
    }
    return _sanitizeLinePoints(
      merged.entries.map((MapEntry<int, double?> entry) {
        return RawPoint(utcMs: entry.key, value: entry.value);
      }).toList(growable: false),
    );
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

  Widget _buildChartCard(
    _ChartBundle chart, {
    required int chartCount,
  }) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    final axisCaption = chart.yAxisConfig.title.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: SizedBox(
          height: _chartHeightFor(chartCount),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _compactChartTitle(chart.title),
                      style: titleStyle,
                    ),
                  ),
                  if (axisCaption.isNotEmpty)
                    Text(
                      axisCaption,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SfCartesianChart(
                  legend: Legend(
                    isVisible: chart.legendVisible,
                    position: LegendPosition.bottom,
                  ),
                  plotAreaBorderWidth: 0,
                  zoomPanBehavior: ZoomPanBehavior(
                    enablePinching: true,
                    enablePanning: true,
                    enableMouseWheelZooming: true,
                    zoomMode: ZoomMode.x,
                  ),
                  trackballBehavior: TrackballBehavior(
                    enable: true,
                    activationMode: ActivationMode.longPress,
                    tooltipSettings: const InteractiveTooltip(
                      enable: true,
                      canShowMarker: false,
                    ),
                  ),
                  onChartTouchInteractionDown: (_) => _beginChartInteraction(),
                  onChartTouchInteractionMove: (_) => _beginChartInteraction(),
                  onChartTouchInteractionUp: (_) => _endChartInteraction(),
                  onActualRangeChanged: _handleActualRangeChanged,
                  onTrackballPositionChanging: _handleTrackballPositionChanging,
                  primaryXAxis: DateTimeAxis(
                    title: const AxisTitle(text: 'Local time'),
                    dateFormat: _showSecondsOnXAxis
                        ? _localTimeSecondsFormat
                        : _localTimeMinutesFormat,
                    edgeLabelPlacement: EdgeLabelPlacement.shift,
                    labelIntersectAction: AxisLabelIntersectAction.rotate45,
                    maximumLabels: 6,
                  ),
                  primaryYAxis: _buildYAxis(chart.yAxisConfig),
                  series: chart.series,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ChartAxis _buildYAxis(_YAxisConfig config) {
    if (_logScale) {
      return LogarithmicAxis(
        logBase: 10,
        minimum: config.minimum,
        maximum: config.maximum,
        axisLabelFormatter: (AxisLabelRenderDetails details) =>
            _formatYAxisLabel(config, details),
        labelStyle: const TextStyle(fontSize: 10),
      );
    }
    return NumericAxis(
      minimum: config.minimum,
      maximum: config.maximum,
      interval: config.interval,
      axisLabelFormatter: (AxisLabelRenderDetails details) =>
          _formatYAxisLabel(config, details),
      rangePadding: ChartRangePadding.none,
      labelStyle: const TextStyle(fontSize: 10),
    );
  }

  ChartAxisLabel _formatYAxisLabel(
    _YAxisConfig config,
    AxisLabelRenderDetails details,
  ) {
    return ChartAxisLabel(
      config.labelFormatter.format(details.value),
      details.textStyle,
    );
  }

  void _handleTrackballPositionChanging(TrackballArgs args) {
    final pointInfo = args.chartPointInfo;
    final point = pointInfo.chartPoint;
    pointInfo.header = '';
    pointInfo.label =
        '${_formatTrackballTime(point?.x)}\n${_formatTrackballValue(point?.y)}';
  }

  String _formatTrackballTime(dynamic value) {
    if (value is DateTime) {
      return _trackballTimeFormat.format(value.toLocal());
    }
    return value?.toString() ?? '--:--:--';
  }

  String _formatTrackballValue(dynamic value) {
    if (value is num && value.isFinite) {
      return _trackballNumberFormat.format(value.toDouble());
    }
    return '--';
  }

  double _chartHeightFor(int chartCount) {
    final size = MediaQuery.sizeOf(context);
    final isWideLayout = size.width >= 960;
    final baseHeight = chartCount == 1
        ? size.height * (isWideLayout ? 0.72 : 0.68)
        : size.height * (isWideLayout ? 0.58 : 0.54);
    final minimum = chartCount == 1 ? 500.0 : 420.0;
    final maximum = chartCount == 1 ? 760.0 : 620.0;
    return math.max(minimum, math.min(maximum, baseHeight));
  }

  void _applyLiveUpdate(LivePlotResponse liveResponse) {
    final didChange = _didLivePayloadChange(liveResponse);
    if (!didChange) {
      _liveError = null;
      _lastServerNowUtcMs = liveResponse.serverNowUtcMs;
      if (liveResponse.serverNowUtcMs > _lastLiveAfterUtcMs) {
        _lastLiveAfterUtcMs = liveResponse.serverNowUtcMs;
      }
      return;
    }

    setState(() {
      _mergeLiveSeries(_liveValuesByChannel, liveResponse.series);
      _lastServerNowUtcMs = liveResponse.serverNowUtcMs;
      if (liveResponse.serverNowUtcMs > _lastLiveAfterUtcMs) {
        _lastLiveAfterUtcMs = liveResponse.serverNowUtcMs;
      }
      _liveError = null;
    });
  }

  void _stageDeferredLiveUpdate(LivePlotResponse liveResponse) {
    _mergeLiveSeries(_deferredLiveValuesByChannel, liveResponse.series);
    _deferredLiveError = null;
    _deferredServerNowUtcMs = liveResponse.serverNowUtcMs;
    if (_deferredLastLiveAfterUtcMs == null ||
        liveResponse.serverNowUtcMs > _deferredLastLiveAfterUtcMs!) {
      _deferredLastLiveAfterUtcMs = liveResponse.serverNowUtcMs;
    }
  }

  void _flushDeferredLiveUpdate() {
    final hasDeferredValues = _deferredLiveValuesByChannel.values.any(
      (SplayTreeMap<int, double?> values) => values.isNotEmpty,
    );
    final hasDeferredState = hasDeferredValues ||
        _deferredLiveError != null ||
        _deferredServerNowUtcMs != null ||
        _deferredLastLiveAfterUtcMs != null;
    if (!hasDeferredState || !mounted) {
      _clearDeferredLiveUpdate();
      return;
    }

    setState(() {
      if (hasDeferredValues) {
        _mergeDeferredIntoLive();
      }
      if (_deferredServerNowUtcMs != null) {
        _lastServerNowUtcMs = _deferredServerNowUtcMs!;
      }
      if (_deferredLastLiveAfterUtcMs != null &&
          _deferredLastLiveAfterUtcMs! > _lastLiveAfterUtcMs) {
        _lastLiveAfterUtcMs = _deferredLastLiveAfterUtcMs!;
      }
      if (_deferredLiveError != null) {
        _liveError = _deferredLiveError;
      } else if (hasDeferredValues || _deferredServerNowUtcMs != null) {
        _liveError = null;
      }
      _clearDeferredLiveUpdate();
    });
  }

  void _mergeDeferredIntoLive() {
    for (final MapEntry<String, SplayTreeMap<int, double?>> entry
        in _deferredLiveValuesByChannel.entries) {
      final buffer = _liveValuesByChannel.putIfAbsent(
        entry.key,
        () => SplayTreeMap<int, double?>(),
      );
      buffer.addAll(entry.value);
    }
  }

  void _clearDeferredLiveUpdate() {
    _deferredLiveValuesByChannel.clear();
    _deferredLiveError = null;
    _deferredServerNowUtcMs = null;
    _deferredLastLiveAfterUtcMs = null;
  }

  bool _didLivePayloadChange(LivePlotResponse liveResponse) {
    if (_liveError != null) {
      return true;
    }
    if (liveResponse.serverNowUtcMs != _lastServerNowUtcMs) {
      return true;
    }
    for (final LivePlotSeries series in liveResponse.series) {
      if (series.values.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void _mergeLiveSeries(
    Map<String, SplayTreeMap<int, double?>> target,
    List<LivePlotSeries> seriesList,
  ) {
    for (final LivePlotSeries series in seriesList) {
      final buffer = target.putIfAbsent(
        series.channel,
        () => SplayTreeMap<int, double?>(),
      );
      for (final RawPoint point in series.expandSamples()) {
        buffer[point.utcMs] = point.value;
      }
    }
  }

  String _displayNameForChannel(String channel, PlotSeries? series) {
    final displayName = series?.displayName.trim() ?? '';
    return displayName.isEmpty ? channel : displayName;
  }

  List<String> _unitsForChannels(List<String> channels) {
    final response = _response;
    if (response == null) {
      return const <String>[];
    }
    final seriesByChannel = <String, PlotSeries>{
      for (final PlotSeries series in response.series) series.channel: series,
    };
    final units = SplayTreeSet<String>();
    for (final String channel in channels) {
      final unit = seriesByChannel[channel]?.unit.trim() ?? '';
      if (unit.isNotEmpty) {
        units.add(unit);
      }
    }
    return units.toList(growable: false);
  }

  String _yAxisTitleForChannels(
    List<String> channels,
    Map<String, PlotSeries> seriesByChannel,
  ) {
    final units = SplayTreeSet<String>();
    for (final String channel in channels) {
      final unit = seriesByChannel[channel]?.unit.trim() ?? '';
      if (unit.isNotEmpty) {
        units.add(unit);
      }
    }
    if (units.isEmpty) {
      return '';
    }
    if (units.length == 1) {
      return units.first;
    }
    return 'mixed units';
  }

  _YAxisConfig _buildYAxisConfig(
    List<String> channels,
    Map<String, PlotSeries> seriesByChannel,
  ) {
    final title = _yAxisTitleForChannels(channels, seriesByChannel);
    final range = _DataRange.empty();

    for (final String channel in channels) {
      final PlotSeries? historySeries = seriesByChannel[channel];
      if (historySeries is RawPlotSeries) {
        for (final RawPoint point
            in _sanitizeLinePoints(historySeries.expandSamples())) {
          range.include(point.value);
        }
      } else if (historySeries is BucketedPlotSeries) {
        for (final BucketPoint point
            in _sanitizeBucketPoints(historySeries.expandBuckets())) {
          range.include(point.minValue);
          range.include(point.maxValue);
        }
      }

      for (final RawPoint point in _expandLivePoints(channel)) {
        range.include(point.value);
      }
    }

    if (!range.hasValues) {
      return _YAxisConfig(
        title: title,
        labelFormatter: PlotAxisValueFormatter.forAxis(),
      );
    }

    if (_logScale) {
      final minValue = range.minimum!;
      final maxValue = range.maximum!;
      if (minValue == maxValue) {
        return _YAxisConfig(
          title: title,
          minimum: minValue / 1.2,
          maximum: maxValue * 1.2,
          labelFormatter: PlotAxisValueFormatter.forAxis(
            minimum: minValue / 1.2,
            maximum: maxValue * 1.2,
          ),
        );
      }
      final paddingFactor = 0.04;
      return _YAxisConfig(
        title: title,
        minimum: math.max(minValue * (1 - paddingFactor), double.minPositive),
        maximum: maxValue * (1 + paddingFactor),
        labelFormatter: PlotAxisValueFormatter.forAxis(
          minimum: math.max(minValue * (1 - paddingFactor), double.minPositive),
          maximum: maxValue * (1 + paddingFactor),
        ),
      );
    }

    final minValue = range.minimum!;
    final maxValue = range.maximum!;
    final valueSpan = maxValue - minValue;
    final referenceMagnitude = math.max(
      math.max(minValue.abs(), maxValue.abs()),
      1e-12,
    );
    final relativeSpan = valueSpan / referenceMagnitude;
    final halfRange = valueSpan == 0
        ? _niceStep(referenceMagnitude * 0.02)
        : relativeSpan < 1e-4
            ? math.max(
                valueSpan * 0.6,
                _niceStep(referenceMagnitude * 0.02),
              )
            : math.max(valueSpan * 0.08, _niceStep(valueSpan * 0.02));
    final paddedMinimum = minValue - halfRange;
    final paddedMaximum = maxValue + halfRange;
    final interval = _niceStep((paddedMaximum - paddedMinimum) / 5);
    final axisMinimum = (paddedMinimum / interval).floorToDouble() * interval;
    final axisMaximum = (paddedMaximum / interval).ceilToDouble() * interval;

    return _YAxisConfig(
      title: title,
      minimum: axisMinimum,
      maximum: axisMaximum,
      interval: interval,
      labelFormatter: PlotAxisValueFormatter.forAxis(
        minimum: axisMinimum,
        maximum: axisMaximum,
        interval: interval,
      ),
    );
  }

  double _niceStep(double value) {
    if (!value.isFinite || value <= 0) {
      return 1;
    }
    final exponent = math.pow(10, (math.log(value) / math.ln10).floor());
    final fraction = value / exponent;
    final niceFraction = fraction <= 1
        ? 1.0
        : fraction <= 2
            ? 2.0
            : fraction <= 5
                ? 5.0
                : 10.0;
    return niceFraction * exponent;
  }

  String _compactChartTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final isPhoneWidth = MediaQuery.sizeOf(context).width < 600;
    final maxChars = isPhoneWidth ? 34 : 52;
    if (trimmed.length <= maxChars) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxChars - 1)}...';
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

  static String _historyFromLabel(PlotViewRequest request) {
    if (request.sourceLabel == 'Custom') {
      return 'History from ${_formatDateTime(request.startLocal)}';
    }
    return 'History from ${request.sourceLabel}';
  }
}

class _ChartBundle {
  const _ChartBundle({
    required this.title,
    required this.legendVisible,
    required this.yAxisConfig,
    required this.series,
  });

  final String title;
  final bool legendVisible;
  final _YAxisConfig yAxisConfig;
  final List<CartesianSeries<dynamic, DateTime>> series;
}

class _YAxisConfig {
  const _YAxisConfig({
    required this.title,
    this.minimum,
    this.maximum,
    this.interval,
    required this.labelFormatter,
  });

  final String title;
  final double? minimum;
  final double? maximum;
  final double? interval;
  final PlotAxisValueFormatter labelFormatter;
}

class _DataRange {
  _DataRange.empty();

  double? minimum;
  double? maximum;

  bool get hasValues => minimum != null && maximum != null;

  void include(double? value) {
    if (value == null || !value.isFinite) {
      return;
    }
    if (!hasValues) {
      minimum = value;
      maximum = value;
      return;
    }
    minimum = math.min(minimum!, value);
    maximum = math.max(maximum!, value);
  }
}

class _LinePoint {
  const _LinePoint({required this.time, required this.value});

  final DateTime time;
  final double? value;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 0)
          : null,
      avatar: Icon(icon, size: compact ? 14 : 18),
      label: Text(
        label,
        style: compact ? Theme.of(context).textTheme.bodySmall : null,
      ),
    );
  }
}
