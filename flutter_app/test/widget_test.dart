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
