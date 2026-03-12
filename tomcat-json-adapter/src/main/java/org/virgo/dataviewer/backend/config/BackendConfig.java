package org.virgo.dataviewer.backend.config;

import javax.servlet.ServletContext;

public final class BackendConfig {
    private final String trendFflPath;
    private final String zcmSubEndpoint;
    private final String gpsChannel;
    private final String historyBackend;
    private final String frameJniLibraryName;
    private final String frameJniLibraryPath;
    private final String channelCatalogSearchUrl;
    private final String channelCatalogCategoriesUrl;
    private final String channelCatalogListUrl;
    private final int channelCatalogTimeoutMs;
    private final int channelCatalogCacheSeconds;
    private final int liveBufferMinutes;
    private final int liveBufferSeconds;
    private final int livePollMs;

    private BackendConfig(
            String trendFflPath,
            String zcmSubEndpoint,
            String gpsChannel,
            String historyBackend,
            String frameJniLibraryName,
            String frameJniLibraryPath,
            String channelCatalogSearchUrl,
            String channelCatalogCategoriesUrl,
            String channelCatalogListUrl,
            int channelCatalogTimeoutMs,
            int channelCatalogCacheSeconds,
            int liveBufferMinutes,
            int liveBufferSeconds,
            int livePollMs) {
        this.trendFflPath = trendFflPath;
        this.zcmSubEndpoint = zcmSubEndpoint;
        this.gpsChannel = gpsChannel;
        this.historyBackend = historyBackend;
        this.frameJniLibraryName = frameJniLibraryName;
        this.frameJniLibraryPath = frameJniLibraryPath;
        this.channelCatalogSearchUrl = channelCatalogSearchUrl;
        this.channelCatalogCategoriesUrl = channelCatalogCategoriesUrl;
        this.channelCatalogListUrl = channelCatalogListUrl;
        this.channelCatalogTimeoutMs = channelCatalogTimeoutMs;
        this.channelCatalogCacheSeconds = channelCatalogCacheSeconds;
        this.liveBufferMinutes = liveBufferMinutes;
        this.liveBufferSeconds = liveBufferSeconds;
        this.livePollMs = livePollMs;
    }

    public static BackendConfig from(ServletContext context) {
        String trendFflPath = trimToDefault(context.getInitParameter("virgo.trend.ffl"), "/virgoData/ffl/trend.ffl");
        String zcmSubEndpoint = trimToDefault(context.getInitParameter("zcmsubendpoint"), "");
        String gpsChannel = trimToDefault(context.getInitParameter("zcmgpschannel"), "GPS");
        String historyBackend = trimToDefault(context.getInitParameter("virgo.history.backend"), "jni");
        String frameJniLibraryName = trimToDefault(context.getInitParameter("virgo.frame.jni.library"), "virgo_frame_jni");
        String frameJniLibraryPath = trimToNull(context.getInitParameter("virgo.frame.jni.path"));
        String channelCatalogSearchUrl = trimToNull(context.getInitParameter("virgo.channel.catalog.search.url"));
        String channelCatalogCategoriesUrl = trimToNull(context.getInitParameter("virgo.channel.catalog.categories.url"));
        String channelCatalogListUrl = trimToNull(context.getInitParameter("virgo.channel.catalog.list.url"));
        int channelCatalogTimeoutMs = parsePositiveInt(context.getInitParameter("virgo.channel.catalog.timeout.ms"), 5000);
        int channelCatalogCacheSeconds = parsePositiveInt(context.getInitParameter("virgo.channel.catalog.cache.seconds"), 60);
        int liveBufferMinutes = parsePositiveInt(context.getInitParameter("virgo.live.buffer.minutes"), 5);
        int liveBufferSeconds = parsePositiveInt(
                context.getInitParameter("virgo.live.buffer.seconds"),
                liveBufferMinutes * 60);
        int livePollMs = parsePositiveInt(context.getInitParameter("virgo.live.poll.ms"), 1000);
        return new BackendConfig(
                trendFflPath,
                zcmSubEndpoint,
                gpsChannel,
                historyBackend,
                frameJniLibraryName,
                frameJniLibraryPath,
                channelCatalogSearchUrl,
                channelCatalogCategoriesUrl,
                channelCatalogListUrl,
                channelCatalogTimeoutMs,
                channelCatalogCacheSeconds,
                liveBufferMinutes,
                liveBufferSeconds,
                livePollMs);
    }

    public String getTrendFflPath() {
        return trendFflPath;
    }

    public String getZcmSubEndpoint() {
        return zcmSubEndpoint;
    }

    public String getGpsChannel() {
        return gpsChannel;
    }

    public String getHistoryBackend() {
        return historyBackend;
    }

    public String getFrameJniLibraryName() {
        return frameJniLibraryName;
    }

    public String getFrameJniLibraryPath() {
        return frameJniLibraryPath;
    }

    public String getChannelCatalogSearchUrl() {
        return channelCatalogSearchUrl;
    }

    public String getChannelCatalogCategoriesUrl() {
        return channelCatalogCategoriesUrl;
    }

    public String getChannelCatalogListUrl() {
        return channelCatalogListUrl;
    }

    public int getChannelCatalogTimeoutMs() {
        return channelCatalogTimeoutMs;
    }

    public int getChannelCatalogCacheSeconds() {
        return channelCatalogCacheSeconds;
    }

    public int getLiveBufferMinutes() {
        return liveBufferMinutes;
    }

    public int getLiveBufferSeconds() {
        return liveBufferSeconds;
    }

    public int getLivePollMs() {
        return livePollMs;
    }

    private static String trimToDefault(String value, String fallback) {
        if (value == null) {
            return fallback;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? fallback : trimmed;
    }

    private static String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private static int parsePositiveInt(String value, int fallback) {
        if (value == null) {
            return fallback;
        }
        try {
            int parsed = Integer.parseInt(value.trim());
            return parsed > 0 ? parsed : fallback;
        } catch (NumberFormatException exception) {
            return fallback;
        }
    }
}
