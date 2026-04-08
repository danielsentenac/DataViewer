package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class PlotQueryRequestDto {
    private List<String> channels = new ArrayList<String>();
    private TimeRangeRequestDto timeRange;
    private SamplingRequestDto sampling;
    private Integer historyChunkSeconds;
    private Long historyCursorUtcMs;
    private Long historyTargetEndUtcMs;

    public PlotQueryRequestDto() {
    }

    public PlotQueryRequestDto(
            List<String> channels,
            TimeRangeRequestDto timeRange,
            SamplingRequestDto sampling,
            Integer historyChunkSeconds,
            Long historyCursorUtcMs,
            Long historyTargetEndUtcMs) {
        setChannels(channels);
        this.timeRange = timeRange;
        this.sampling = sampling;
        this.historyChunkSeconds = historyChunkSeconds;
        this.historyCursorUtcMs = historyCursorUtcMs;
        this.historyTargetEndUtcMs = historyTargetEndUtcMs;
    }

    public List<String> getChannels() {
        return new ArrayList<String>(channels);
    }

    public void setChannels(List<String> channels) {
        this.channels = new ArrayList<String>(channels == null ? Collections.<String>emptyList() : channels);
    }

    public TimeRangeRequestDto getTimeRange() {
        return timeRange;
    }

    public void setTimeRange(TimeRangeRequestDto timeRange) {
        this.timeRange = timeRange;
    }

    public SamplingRequestDto getSampling() {
        return sampling;
    }

    public void setSampling(SamplingRequestDto sampling) {
        this.sampling = sampling;
    }

    public Integer getHistoryChunkSeconds() {
        return historyChunkSeconds;
    }

    public void setHistoryChunkSeconds(Integer historyChunkSeconds) {
        this.historyChunkSeconds = historyChunkSeconds;
    }

    public Long getHistoryCursorUtcMs() {
        return historyCursorUtcMs;
    }

    public void setHistoryCursorUtcMs(Long historyCursorUtcMs) {
        this.historyCursorUtcMs = historyCursorUtcMs;
    }

    public Long getHistoryTargetEndUtcMs() {
        return historyTargetEndUtcMs;
    }

    public void setHistoryTargetEndUtcMs(Long historyTargetEndUtcMs) {
        this.historyTargetEndUtcMs = historyTargetEndUtcMs;
    }
}
