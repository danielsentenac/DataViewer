package org.virgo.dataviewer.backend.service;

import java.util.ArrayList;
import java.util.List;

import org.virgo.dataviewer.adapter.dto.BucketedPlotSeriesDto;
import org.virgo.dataviewer.adapter.dto.LiveDirectiveDto;
import org.virgo.dataviewer.adapter.dto.LivePlotRequestDto;
import org.virgo.dataviewer.adapter.dto.LivePlotResponseDto;
import org.virgo.dataviewer.adapter.dto.LivePlotSeriesDto;
import org.virgo.dataviewer.adapter.dto.PlotQueryMetadataDto;
import org.virgo.dataviewer.adapter.dto.PlotQueryRequestDto;
import org.virgo.dataviewer.adapter.dto.PlotQueryResponseDto;
import org.virgo.dataviewer.adapter.dto.PlotSeriesDto;
import org.virgo.dataviewer.adapter.dto.RawPlotSeriesDto;
import org.virgo.dataviewer.adapter.dto.SamplingRequestDto;
import org.virgo.dataviewer.adapter.dto.TimeRangeRequestDto;
import org.virgo.dataviewer.adapter.service.AdapterException;
import org.virgo.dataviewer.adapter.service.PlotService;
import org.virgo.dataviewer.backend.history.ArchiveBounds;
import org.virgo.dataviewer.backend.history.TrendArchiveReader;
import org.virgo.dataviewer.backend.history.TrendRawSeries;
import org.virgo.dataviewer.backend.live.ZJChvBuf;
import org.virgo.dataviewer.backend.time.GpsTimeConverter;

public final class VirgoPlotService implements PlotService {
    private static final int MIN_PROGRESSIVE_TARGET_BUCKETS = 120;

    private final TrendArchiveReader archiveReader;
    private final ZJChvBuf liveBuffer;
    private final GpsTimeConverter gpsTimeConverter;
    private final int livePollMs;

    public VirgoPlotService(
            TrendArchiveReader archiveReader,
            ZJChvBuf liveBuffer,
            GpsTimeConverter gpsTimeConverter,
            int livePollMs) {
        this.archiveReader = archiveReader;
        this.liveBuffer = liveBuffer;
        this.gpsTimeConverter = gpsTimeConverter;
        this.livePollMs = livePollMs;
    }

    @Override
    public PlotQueryResponseDto query(PlotQueryRequestDto request) throws AdapterException {
        validateChannels(request == null ? null : request.getChannels());
        TimeRangeRequestDto timeRange = request.getTimeRange();
        if (timeRange == null) {
            throw AdapterException.badRequest("INVALID_TIME_RANGE", "timeRange is required.");
        }

        long requestedStartUtcMs = gpsTimeConverter.localTimeToUtcMs(timeRange.getStartLocalIso(), timeRange.getTimeZone());
        long requestedStartGps = gpsTimeConverter.utcMsToGpsSeconds(requestedStartUtcMs);
        ArchiveBounds bounds = archiveReader.resolveBounds();
        long effectiveStartGps = Math.max(requestedStartGps, bounds.getStartGps());
        long archiveEndGps = bounds.getEndGps();
        long liveOldestUtcMs = liveBuffer.getOldestBufferedUtcMs();
        long handoffGps = archiveEndGps;
        if (liveOldestUtcMs > 0L) {
            handoffGps = Math.min(archiveEndGps, gpsTimeConverter.utcMsToGpsSeconds(liveOldestUtcMs));
        }
        if (handoffGps < effectiveStartGps) {
            handoffGps = effectiveStartGps;
        }
        long resolvedStartUtcMs = gpsTimeConverter.gpsSecondsToUtcMs(effectiveStartGps);
        long computedHistoryEndUtcMs = gpsTimeConverter.gpsSecondsToUtcMs(handoffGps);
        long historyTargetEndUtcMs = resolveHistoryTargetEndUtcMs(
                request.getHistoryTargetEndUtcMs(),
                resolvedStartUtcMs,
                computedHistoryEndUtcMs);
        long cursorStartUtcMs = resolveCursorStartUtcMs(
                request.getHistoryCursorUtcMs(),
                resolvedStartUtcMs,
                historyTargetEndUtcMs);
        int historyChunkSeconds = resolveHistoryChunkSeconds(
                request.getHistoryChunkSeconds(),
                cursorStartUtcMs,
                historyTargetEndUtcMs);
        long cursorStartGps = gpsTimeConverter.utcMsToGpsSeconds(cursorStartUtcMs);
        long chunkEndGps = Math.min(handoffGps, cursorStartGps + historyChunkSeconds);
        long chunkLoadedEndUtcMs = gpsTimeConverter.gpsSecondsToUtcMs(chunkEndGps);
        boolean historyComplete = chunkLoadedEndUtcMs >= historyTargetEndUtcMs;
        Long nextChunkStartUtcMs = historyComplete ? null : Long.valueOf(chunkLoadedEndUtcMs);
        long totalHistoryDurationSeconds = Math.max(0L, handoffGps - effectiveStartGps);
        long chunkDurationSeconds = Math.max(0L, chunkEndGps - cursorStartGps);

        List<PlotSeriesDto> series = new ArrayList<PlotSeriesDto>();
        if (chunkDurationSeconds > 0L) {
            List<TrendRawSeries> rawSeries = archiveReader.readRawSeries(request.getChannels(), cursorStartGps, chunkDurationSeconds);
            for (TrendRawSeries rawSeriesEntry : rawSeries) {
                series.add(toPlotSeries(
                        rawSeriesEntry,
                        request.getSampling(),
                        totalHistoryDurationSeconds,
                        chunkDurationSeconds));
            }
        }

        PlotQueryMetadataDto metadata = new PlotQueryMetadataDto(
                request.getChannels().size(),
                resolvedStartUtcMs,
                effectiveStartGps,
                historyTargetEndUtcMs,
                chunkLoadedEndUtcMs,
                nextChunkStartUtcMs,
                historyComplete);
        LiveDirectiveDto liveDirective = new LiveDirectiveDto(
                historyComplete ? "poll" : "deferred",
                livePollMs,
                historyTargetEndUtcMs);
        return new PlotQueryResponseDto(metadata, series, liveDirective);
    }

    @Override
    public LivePlotResponseDto live(LivePlotRequestDto request) throws AdapterException {
        validateChannels(request == null ? null : request.getChannels());
        long afterUtcMs = request.getAfterUtcMs();
        if (afterUtcMs < 0L) {
            throw AdapterException.badRequest("INVALID_LIVE_RANGE", "afterUtcMs must be >= 0.");
        }
        List<LivePlotSeriesDto> series = liveBuffer.collectSeries(request.getChannels(), afterUtcMs);
        long serverNowUtcMs = liveBuffer.getLatestBufferedUtcMs();
        if (serverNowUtcMs <= 0L) {
            serverNowUtcMs = System.currentTimeMillis();
        }
        return new LivePlotResponseDto(serverNowUtcMs, series);
    }

    private void validateChannels(List<String> channels) throws AdapterException {
        if (channels == null || channels.isEmpty()) {
            throw AdapterException.badRequest("INVALID_CHANNELS", "At least one channel is required.");
        }
    }

    private PlotSeriesDto toPlotSeries(
            TrendRawSeries rawSeries,
            SamplingRequestDto samplingRequest,
            long totalHistoryDurationSeconds,
            long chunkDurationSeconds) {
        Integer effectiveTargetBuckets = resolveChunkTargetBuckets(
                samplingRequest == null ? null : samplingRequest.getTargetBuckets(),
                totalHistoryDurationSeconds,
                chunkDurationSeconds);
        if (effectiveTargetBuckets == null || rawSeries.getValues().size() <= effectiveTargetBuckets.intValue()) {
            return new RawPlotSeriesDto(
                    rawSeries.getChannel(),
                    rawSeries.getChannel(),
                    rawSeries.getUnit(),
                    gpsTimeConverter.gpsSecondsToUtcMs(rawSeries.getStartGps()),
                    rawSeries.getStepSeconds() * 1000,
                    rawSeries.getValues());
        }
        return bucket(rawSeries, effectiveTargetBuckets.intValue());
    }

    private BucketedPlotSeriesDto bucket(TrendRawSeries rawSeries, int targetBuckets) {
        int bucketSize = Math.max(1, (int) Math.ceil(rawSeries.getValues().size() / (double) targetBuckets));
        List<Double> minValues = new ArrayList<Double>();
        List<Double> maxValues = new ArrayList<Double>();
        for (int offset = 0; offset < rawSeries.getValues().size(); offset += bucketSize) {
            int end = Math.min(rawSeries.getValues().size(), offset + bucketSize);
            Double min = null;
            Double max = null;
            for (int i = offset; i < end; i++) {
                Double value = rawSeries.getValues().get(i);
                if (value == null) {
                    continue;
                }
                if (min == null || value.doubleValue() < min.doubleValue()) {
                    min = value;
                }
                if (max == null || value.doubleValue() > max.doubleValue()) {
                    max = value;
                }
            }
            minValues.add(min);
            maxValues.add(max);
        }
        return new BucketedPlotSeriesDto(
                rawSeries.getChannel(),
                rawSeries.getChannel(),
                rawSeries.getUnit(),
                gpsTimeConverter.gpsSecondsToUtcMs(rawSeries.getStartGps()),
                bucketSize * rawSeries.getStepSeconds(),
                minValues,
                maxValues);
    }

    private long resolveHistoryTargetEndUtcMs(
            Long requestedTargetEndUtcMs,
            long resolvedStartUtcMs,
            long computedHistoryEndUtcMs) throws AdapterException {
        long historyTargetEndUtcMs = requestedTargetEndUtcMs == null
                ? computedHistoryEndUtcMs
                : requestedTargetEndUtcMs.longValue();
        if (historyTargetEndUtcMs < resolvedStartUtcMs) {
            throw AdapterException.badRequest(
                    "INVALID_TIME_RANGE",
                    "historyTargetEndUtcMs must be >= the resolved start time.");
        }
        if (historyTargetEndUtcMs > computedHistoryEndUtcMs) {
            return computedHistoryEndUtcMs;
        }
        return historyTargetEndUtcMs;
    }

    private long resolveCursorStartUtcMs(
            Long requestedCursorStartUtcMs,
            long resolvedStartUtcMs,
            long historyTargetEndUtcMs) throws AdapterException {
        long cursorStartUtcMs = requestedCursorStartUtcMs == null
                ? resolvedStartUtcMs
                : requestedCursorStartUtcMs.longValue();
        if (cursorStartUtcMs < resolvedStartUtcMs) {
            throw AdapterException.badRequest(
                    "INVALID_TIME_RANGE",
                    "historyCursorUtcMs must be >= the resolved start time.");
        }
        if (cursorStartUtcMs > historyTargetEndUtcMs) {
            throw AdapterException.badRequest(
                    "INVALID_TIME_RANGE",
                    "historyCursorUtcMs must be <= historyTargetEndUtcMs.");
        }
        return cursorStartUtcMs;
    }

    private int resolveHistoryChunkSeconds(
            Integer requestedChunkSeconds,
            long cursorStartUtcMs,
            long historyTargetEndUtcMs) throws AdapterException {
        long remainingSeconds = Math.max(0L, gpsTimeConverter.utcMsToGpsSeconds(historyTargetEndUtcMs)
                - gpsTimeConverter.utcMsToGpsSeconds(cursorStartUtcMs));
        if (requestedChunkSeconds == null) {
            if (remainingSeconds > Integer.MAX_VALUE) {
                throw AdapterException.badRequest("INVALID_TIME_RANGE", "Requested archive span is too large.");
            }
            return (int) remainingSeconds;
        }
        if (requestedChunkSeconds.intValue() <= 0) {
            throw AdapterException.badRequest(
                    "INVALID_TIME_RANGE",
                    "historyChunkSeconds must be > 0 when provided.");
        }
        return Math.min(requestedChunkSeconds.intValue(), (int) Math.min(Integer.MAX_VALUE, remainingSeconds));
    }

    private Integer resolveChunkTargetBuckets(
            Integer requestedTargetBuckets,
            long totalHistoryDurationSeconds,
            long chunkDurationSeconds) {
        if (requestedTargetBuckets == null || requestedTargetBuckets.intValue() <= 0 || totalHistoryDurationSeconds <= 0L
                || chunkDurationSeconds <= 0L || chunkDurationSeconds >= totalHistoryDurationSeconds) {
            return requestedTargetBuckets;
        }
        int scaledTarget = (int) Math.ceil(
                requestedTargetBuckets.doubleValue() * chunkDurationSeconds / (double) totalHistoryDurationSeconds);
        int minimumTarget = Math.min(requestedTargetBuckets.intValue(), MIN_PROGRESSIVE_TARGET_BUCKETS);
        return Integer.valueOf(Math.max(minimumTarget, Math.min(requestedTargetBuckets.intValue(), scaledTarget)));
    }
}
