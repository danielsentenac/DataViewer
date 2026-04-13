import 'dart:async';
import 'dart:collection';

import 'package:dataviewer/features/plot_view/data/plot_repository.dart';
import 'package:dataviewer/features/plot_view/presentation/plot_screen.dart';
import 'package:dataviewer/features/plot_view/presentation/plot_view_providers.dart';
import 'package:dataviewer/shared/models/plot_models.dart';
import 'package:dataviewer/shared/models/plot_view_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() {
  testWidgets('plot screen renders summary for a request', (
    WidgetTester tester,
  ) async {
    final repository = _FakePlotRepository(
      Queue<Future<PlotQueryResponse>>.of(<Future<PlotQueryResponse>>[
        Future<PlotQueryResponse>.value(_summaryHistoryResponse()),
      ]),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plotRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: PlotScreen(
            request: PlotViewRequest(
              channels: const <String>['V1:TEST_CHANNEL'],
              startLocal: DateTime(2026, 3, 12, 17, 0),
              sourceLabel: '1 h',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Plots'), findsOneWidget);
    expect(find.text('Plot workspace'), findsOneWidget);
    expect(find.textContaining('1 channel(s)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('plot screen updates after the first history chunk arrives', (
    WidgetTester tester,
  ) async {
    final firstChunk = Completer<PlotQueryResponse>();
    final secondChunk = Completer<PlotQueryResponse>();
    final repository = _FakePlotRepository(
      Queue<Future<PlotQueryResponse>>.of(<Future<PlotQueryResponse>>[
        firstChunk.future,
        secondChunk.future,
      ]),
      liveResponse: const LivePlotResponse(
        serverNowUtcMs: 5000,
        series: <LivePlotSeries>[],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plotRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: PlotScreen(
            request: PlotViewRequest(
              channels: const <String>['V1:TEST_CHANNEL'],
              startLocal: DateTime.now().subtract(const Duration(days: 2)),
              sourceLabel: '2 d',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    firstChunk.complete(_firstHistoryChunkResponse());
    await tester.pump();

    expect(find.byType(SfCartesianChart), findsOneWidget);
    expect(find.text('Loading history 50%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(repository.queryRequests, hasLength(2));
    expect(repository.queryRequests[1].historyCursorUtcMs, 3000);
    expect(repository.queryRequests[1].historyTargetEndUtcMs, 5000);

    secondChunk.complete(_finalHistoryResponse());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Loading history'), findsNothing);
    expect(repository.liveRequests, hasLength(1));
    expect(repository.liveRequests.single.afterUtcMs, 5000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'plot screen keeps earlier bucketed history chunks when later chunks use a different bucket size',
    (WidgetTester tester) async {
      final repository = _FakePlotRepository(
        Queue<Future<PlotQueryResponse>>.of(<Future<PlotQueryResponse>>[
          Future<PlotQueryResponse>.value(_firstBucketedHistoryChunkResponse()),
          Future<PlotQueryResponse>.value(_finalBucketedHistoryResponse()),
        ]),
        liveResponse: const LivePlotResponse(
          serverNowUtcMs: 5000,
          series: <LivePlotSeries>[],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plotRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: PlotScreen(
              request: PlotViewRequest(
                channels: const <String>['V1:TEST_CHANNEL'],
                startLocal: DateTime.now().subtract(const Duration(days: 2)),
                sourceLabel: '2 d',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final chart = tester.widget<SfCartesianChart>(
        find.byType(SfCartesianChart),
      );
      expect(chart.series.length, 2);
      expect(
        chart.series.whereType<HiloSeries<BucketPoint, DateTime>>().length,
        2,
      );
      expect(find.textContaining('Loading history'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('plot screen enables XY rectangle zoom on charts', (
    WidgetTester tester,
  ) async {
    final repository = _FakePlotRepository(
      Queue<Future<PlotQueryResponse>>.of(<Future<PlotQueryResponse>>[
        Future<PlotQueryResponse>.value(_summaryHistoryResponse()),
      ]),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plotRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: PlotScreen(
            request: PlotViewRequest(
              channels: const <String>['V1:TEST_CHANNEL'],
              startLocal: DateTime(2026, 3, 12, 17, 0),
              sourceLabel: '1 h',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final chart = tester.widget<SfCartesianChart>(
      find.byType(SfCartesianChart),
    );
    final zoomPanBehavior = chart.zoomPanBehavior;

    expect(zoomPanBehavior, isNotNull);
    expect(zoomPanBehavior!.enableSelectionZooming, isTrue);
    expect(zoomPanBehavior.zoomMode, ZoomMode.xy);
    expect(zoomPanBehavior.maximumZoomLevel, lessThan(0.01));
    expect(
      find.ancestor(
        of: find.byType(SfCartesianChart),
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is GestureDetector && widget.onDoubleTap != null,
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('plot screen shows live-tail affordances on long history plots', (
    WidgetTester tester,
  ) async {
    final repository = _FakePlotRepository(
      Queue<Future<PlotQueryResponse>>.of(<Future<PlotQueryResponse>>[
        Future<PlotQueryResponse>.value(_longRangeHistoryResponse()),
      ]),
      liveResponse: const LivePlotResponse(
        serverNowUtcMs: 2592300000,
        series: <LivePlotSeries>[
          LivePlotSeries(
            channel: 'V1:TEST_CHANNEL',
            startUtcMs: 2592001000,
            stepMs: 1000,
            values: <double?>[3.0, 4.0, 5.0],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plotRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: PlotScreen(
            request: PlotViewRequest(
              channels: const <String>['V1:TEST_CHANNEL'],
              startLocal: DateTime(2026, 3, 12, 17, 0),
              sourceLabel: '1 h',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Jump to live tail'), findsOneWidget);
    expect(find.textContaining('Archive/live handoff:'), findsOneWidget);

    await tester.tap(find.text('Jump to live tail'));
    await tester.pump();
    await tester.pump();

    final chart = tester.widget<SfCartesianChart>(
      find.byType(SfCartesianChart),
    );
    final primaryXAxis = chart.primaryXAxis as DateTimeAxis;
    expect(primaryXAxis.plotBands, isNotEmpty);
    expect(primaryXAxis.dateFormat, isNotNull);
    expect(
      primaryXAxis.dateFormat!.format(DateTime(2026, 1, 1, 12, 34, 56)),
      contains(':56'),
    );

    await tester.tap(find.byType(SfCartesianChart));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(SfCartesianChart));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final resetChart = tester.widget<SfCartesianChart>(
      find.byType(SfCartesianChart),
    );
    final resetXAxis = resetChart.primaryXAxis as DateTimeAxis;
    expect(
      resetXAxis.dateFormat!.format(DateTime(2026, 1, 1, 12, 34, 56)),
      isNot(contains(':56')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _FakePlotRepository implements PlotRepository {
  _FakePlotRepository(
    Queue<Future<PlotQueryResponse>> queryResponses, {
    LivePlotResponse? liveResponse,
  })  : _queryResponses = queryResponses,
        _liveResponse = liveResponse ??
            const LivePlotResponse(
              serverNowUtcMs: 0,
              series: <LivePlotSeries>[],
            );

  final Queue<Future<PlotQueryResponse>> _queryResponses;
  final LivePlotResponse _liveResponse;
  final List<PlotQueryRequest> queryRequests = <PlotQueryRequest>[];
  final List<LivePlotRequest> liveRequests = <LivePlotRequest>[];

  @override
  Future<LivePlotResponse> pollLive(LivePlotRequest request) async {
    liveRequests.add(request);
    return _liveResponse;
  }

  @override
  Future<PlotQueryResponse> queryPlot(PlotQueryRequest request) {
    queryRequests.add(request);
    return _queryResponses.removeFirst();
  }
}

PlotQueryResponse _firstHistoryChunkResponse() {
  return PlotQueryResponse(
    query: const PlotQueryMeta(
      channelCount: 1,
      resolvedStartUtcMs: 1000,
      resolvedStartGps: 1,
      endUtcMs: 5000,
      loadedEndUtcMs: 3000,
      historyComplete: false,
      nextChunkStartUtcMs: 3000,
    ),
    series: <PlotSeries>[
      RawPlotSeries(
        channel: 'V1:TEST_CHANNEL',
        displayName: 'Test Channel',
        unit: 'mbar',
        startUtcMs: 1000,
        stepMs: 1000,
        values: const <double?>[1.0, 2.0],
      ),
    ],
    live: const LiveDirective(
      mode: 'deferred',
      recommendedPollMs: 1000,
      resumeAfterUtcMs: 5000,
    ),
  );
}

PlotQueryResponse _finalHistoryResponse() {
  return PlotQueryResponse(
    query: const PlotQueryMeta(
      channelCount: 1,
      resolvedStartUtcMs: 1000,
      resolvedStartGps: 1,
      endUtcMs: 5000,
      loadedEndUtcMs: 5000,
      historyComplete: true,
    ),
    series: <PlotSeries>[
      RawPlotSeries(
        channel: 'V1:TEST_CHANNEL',
        displayName: 'Test Channel',
        unit: 'mbar',
        startUtcMs: 3000,
        stepMs: 1000,
        values: const <double?>[3.0, 4.0],
      ),
    ],
    live: const LiveDirective(
      mode: 'poll',
      recommendedPollMs: 1000,
      resumeAfterUtcMs: 5000,
    ),
  );
}

PlotQueryResponse _summaryHistoryResponse() {
  return PlotQueryResponse(
    query: const PlotQueryMeta(
      channelCount: 1,
      resolvedStartUtcMs: 1000,
      resolvedStartGps: 1,
      endUtcMs: 5000,
      loadedEndUtcMs: 5000,
      historyComplete: true,
    ),
    series: <PlotSeries>[
      RawPlotSeries(
        channel: 'V1:TEST_CHANNEL',
        displayName: 'Test Channel',
        unit: 'mbar',
        startUtcMs: 1000,
        stepMs: 1000,
        values: const <double?>[1.0, 2.0],
      ),
    ],
    live: const LiveDirective(
      mode: 'deferred',
      recommendedPollMs: 1000,
      resumeAfterUtcMs: 5000,
    ),
  );
}

PlotQueryResponse _longRangeHistoryResponse() {
  return PlotQueryResponse(
    query: const PlotQueryMeta(
      channelCount: 1,
      resolvedStartUtcMs: 0,
      resolvedStartGps: 0,
      endUtcMs: 2592000000,
      loadedEndUtcMs: 2592000000,
      historyComplete: true,
    ),
    series: <PlotSeries>[
      RawPlotSeries(
        channel: 'V1:TEST_CHANNEL',
        displayName: 'Test Channel',
        unit: 'mbar',
        startUtcMs: 0,
        stepMs: 2592000000,
        values: const <double?>[1.0, 2.0],
      ),
    ],
    live: const LiveDirective(
      mode: 'deferred',
      recommendedPollMs: 1000,
      resumeAfterUtcMs: 2592000000,
    ),
  );
}

PlotQueryResponse _firstBucketedHistoryChunkResponse() {
  return PlotQueryResponse(
    query: const PlotQueryMeta(
      channelCount: 1,
      resolvedStartUtcMs: 1000,
      resolvedStartGps: 1,
      endUtcMs: 5000,
      loadedEndUtcMs: 3000,
      historyComplete: false,
      nextChunkStartUtcMs: 3000,
    ),
    series: <PlotSeries>[
      BucketedPlotSeries(
        channel: 'V1:TEST_CHANNEL',
        displayName: 'Test Channel',
        unit: 'mbar',
        startUtcMs: 1000,
        bucketSeconds: 60,
        minValues: const <double?>[1.0, 2.0],
        maxValues: const <double?>[1.5, 2.5],
      ),
    ],
    live: const LiveDirective(
      mode: 'deferred',
      recommendedPollMs: 1000,
      resumeAfterUtcMs: 5000,
    ),
  );
}

PlotQueryResponse _finalBucketedHistoryResponse() {
  return PlotQueryResponse(
    query: const PlotQueryMeta(
      channelCount: 1,
      resolvedStartUtcMs: 1000,
      resolvedStartGps: 1,
      endUtcMs: 5000,
      loadedEndUtcMs: 5000,
      historyComplete: true,
    ),
    series: <PlotSeries>[
      BucketedPlotSeries(
        channel: 'V1:TEST_CHANNEL',
        displayName: 'Test Channel',
        unit: 'mbar',
        startUtcMs: 3000,
        bucketSeconds: 120,
        minValues: const <double?>[3.0, 4.0],
        maxValues: const <double?>[3.5, 4.5],
      ),
    ],
    live: const LiveDirective(
      mode: 'poll',
      recommendedPollMs: 1000,
      resumeAfterUtcMs: 5000,
    ),
  );
}
