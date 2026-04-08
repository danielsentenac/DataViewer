package org.virgo.dataviewer.adapter.dto;

public class PlotQueryMetadataDto {
    private int channelCount;
    private long resolvedStartUtcMs;
    private long resolvedStartGps;
    private long endUtcMs;
    private long loadedEndUtcMs;
    private Long nextChunkStartUtcMs;
    private boolean historyComplete;

    public PlotQueryMetadataDto() {
    }

    public PlotQueryMetadataDto(
            int channelCount,
            long resolvedStartUtcMs,
            long resolvedStartGps,
            long endUtcMs,
            long loadedEndUtcMs,
            Long nextChunkStartUtcMs,
            boolean historyComplete) {
        this.channelCount = channelCount;
        this.resolvedStartUtcMs = resolvedStartUtcMs;
        this.resolvedStartGps = resolvedStartGps;
        this.endUtcMs = endUtcMs;
        this.loadedEndUtcMs = loadedEndUtcMs;
        this.nextChunkStartUtcMs = nextChunkStartUtcMs;
        this.historyComplete = historyComplete;
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

    public long getLoadedEndUtcMs() {
        return loadedEndUtcMs;
    }

    public void setLoadedEndUtcMs(long loadedEndUtcMs) {
        this.loadedEndUtcMs = loadedEndUtcMs;
    }

    public Long getNextChunkStartUtcMs() {
        return nextChunkStartUtcMs;
    }

    public void setNextChunkStartUtcMs(Long nextChunkStartUtcMs) {
        this.nextChunkStartUtcMs = nextChunkStartUtcMs;
    }

    public boolean isHistoryComplete() {
        return historyComplete;
    }

    public void setHistoryComplete(boolean historyComplete) {
        this.historyComplete = historyComplete;
    }
}
