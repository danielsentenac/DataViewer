package org.virgo.dataviewer.adapter.dto;

public class PlotQueryMetadataDto {
    private int channelCount;
    private long resolvedStartUtcMs;
    private long resolvedStartGps;
    private long endUtcMs;

    public PlotQueryMetadataDto() {
    }

    public PlotQueryMetadataDto(int channelCount, long resolvedStartUtcMs, long resolvedStartGps, long endUtcMs) {
        this.channelCount = channelCount;
        this.resolvedStartUtcMs = resolvedStartUtcMs;
        this.resolvedStartGps = resolvedStartGps;
        this.endUtcMs = endUtcMs;
    }

    public int getChannelCount() {
        return channelCount;
    }

    public void setChannelCount(int channelCount) {
        this.channelCount = channelCount;
    }

    public long getResolvedStartUtcMs() {
        return resolvedStartUtcMs;
    }

    public void setResolvedStartUtcMs(long resolvedStartUtcMs) {
        this.resolvedStartUtcMs = resolvedStartUtcMs;
    }

    public long getResolvedStartGps() {
        return resolvedStartGps;
    }

    public void setResolvedStartGps(long resolvedStartGps) {
        this.resolvedStartGps = resolvedStartGps;
    }

    public long getEndUtcMs() {
        return endUtcMs;
    }

    public void setEndUtcMs(long endUtcMs) {
        this.endUtcMs = endUtcMs;
    }
}
