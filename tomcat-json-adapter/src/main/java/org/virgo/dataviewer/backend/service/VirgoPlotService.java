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

        List<PlotSeriesDto> series = new ArrayList<PlotSeriesDto>();
        if (handoffGps > effectiveStartGps) {
            long durationSeconds = handoffGps - effectiveStartGps;
            List<TrendRawSeries> rawSeries = archiveReader.readRawSeries(request.getChannels(), effectiveStartGps, durationSeconds);
            for (TrendRawSeries rawSeriesEntry : rawSeries) {
                series.add(toPlotSeries(rawSeriesEntry, request.getSampling()));
            }
        }

        long resolvedStartUtcMs = gpsTimeConverter.gpsSecondsToUtcMs(effectiveStartGps);
        long historyEndUtcMs = gpsTimeConverter.gpsSecondsToUtcMs(handoffGps);
        PlotQueryMetadataDto metadata = new PlotQueryMetadataDto(
                request.getChannels().size(),
                resolvedStartUtcMs,
                effectiveStartGps,
                historyEndUtcMs);
        LiveDirectiveDto liveDirective = new LiveDirectiveDto("poll", livePollMs, historyEndUtcMs);
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

    private PlotSeriesDto toPlotSeries(TrendRawSeries rawSeries, SamplingRequestDto samplingRequest) {
        if (samplingRequest == null || samplingRequest.getTargetBuckets() == null
                || rawSeries.getValues().size() <= samplingRequest.getTargetBuckets().intValue()) {
            return new RawPlotSeriesDto(
                    rawSeries.getChannel(),
                    rawSeries.getChannel(),
                    rawSeries.getUnit(),
                    gpsTimeConverter.gpsSecondsToUtcMs(rawSeries.getStartGps()),
                    rawSeries.getStepSeconds() * 1000,
                    rawSeries.getValues());
        }
        return bucket(rawSeries, samplingRequest.getTargetBuckets().intValue());
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
}
