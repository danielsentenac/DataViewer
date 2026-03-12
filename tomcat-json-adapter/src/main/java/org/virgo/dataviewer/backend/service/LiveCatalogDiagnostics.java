package org.virgo.dataviewer.backend.service;

public final class LiveCatalogDiagnostics {
    private final boolean liveSourceConfigured;
    private final int bufferMinutes;
    private final int configuredBufferSeconds;
    private final int bufferedSnapshots;
    private final int channelCount;
    private final long oldestBufferedUtcMs;
    private final long latestBufferedUtcMs;

    public LiveCatalogDiagnostics(
            boolean liveSourceConfigured,
            int bufferMinutes,
            int configuredBufferSeconds,
            int bufferedSnapshots,
            int channelCount,
            long oldestBufferedUtcMs,
            long latestBufferedUtcMs) {
        this.liveSourceConfigured = liveSourceConfigured;
        this.bufferMinutes = bufferMinutes;
        this.configuredBufferSeconds = configuredBufferSeconds;
        this.bufferedSnapshots = bufferedSnapshots;
        this.channelCount = channelCount;
        this.oldestBufferedUtcMs = oldestBufferedUtcMs;
        this.latestBufferedUtcMs = latestBufferedUtcMs;
    }

    public boolean isLiveSourceConfigured() {
        return liveSourceConfigured;
    }

    public int getBufferMinutes() {
        return bufferMinutes;
    }

    public int getConfiguredBufferSeconds() {
        return configuredBufferSeconds;
    }

    public int getBufferedSnapshots() {
        return bufferedSnapshots;
    }

    public int getChannelCount() {
        return channelCount;
    }

    public long getOldestBufferedUtcMs() {
        return oldestBufferedUtcMs;
    }

    public long getLatestBufferedUtcMs() {
        return latestBufferedUtcMs;
    }
}
