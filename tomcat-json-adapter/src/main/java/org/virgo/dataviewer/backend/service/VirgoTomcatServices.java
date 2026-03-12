package org.virgo.dataviewer.backend.service;

import java.util.Locale;

import org.virgo.dataviewer.adapter.service.ChannelCatalogService;
import org.virgo.dataviewer.adapter.service.DataViewerServices;
import org.virgo.dataviewer.adapter.service.PlotService;
import org.virgo.dataviewer.backend.config.BackendConfig;
import org.virgo.dataviewer.backend.history.JniTrendArchiveReader;
import org.virgo.dataviewer.backend.history.SwigTrendArchiveReader;
import org.virgo.dataviewer.backend.history.TrendArchiveReader;
import org.virgo.dataviewer.backend.live.ZJChvBuf;
import org.virgo.dataviewer.backend.time.GpsTimeConverter;

public final class VirgoTomcatServices implements DataViewerServices, AutoCloseable {
    private final ChannelCatalogService channelCatalogService;
    private final VirgoPlotService plotService;
    private final ZJChvBuf liveBuffer;
    private final BackendConfig config;

    public VirgoTomcatServices(BackendConfig config) {
        this.config = config;
        GpsTimeConverter gpsTimeConverter = new GpsTimeConverter();
        this.liveBuffer = new ZJChvBuf(config, gpsTimeConverter);
        this.channelCatalogService = createChannelCatalogService(config, liveBuffer);
        this.plotService = new VirgoPlotService(
                createArchiveReader(config),
                liveBuffer,
                gpsTimeConverter,
                config.getLivePollMs());
    }

    @Override
    public ChannelCatalogService channelCatalogService() {
        return channelCatalogService;
    }

    @Override
    public PlotService plotService() {
        return plotService;
    }

    @Override
    public void close() {
        liveBuffer.close();
    }

    public LiveCatalogDiagnostics liveCatalogDiagnostics() {
        return new LiveCatalogDiagnostics(
                liveBuffer.hasSource(),
                config.getLiveBufferMinutes(),
                liveBuffer.getConfiguredBufferSeconds(),
                liveBuffer.snapshotCount(),
                liveBuffer.snapshotCatalog().size(),
                liveBuffer.getOldestBufferedUtcMs(),
                liveBuffer.getLatestBufferedUtcMs());
    }

    private static TrendArchiveReader createArchiveReader(BackendConfig config) {
        String backend = config.getHistoryBackend().trim().toLowerCase(Locale.US);
        if ("swig".equals(backend)) {
            return new SwigTrendArchiveReader(config.getTrendFflPath());
        }
        if ("jni".equals(backend)) {
            return new JniTrendArchiveReader(
                    config.getTrendFflPath(),
                    config.getFrameJniLibraryName(),
                    config.getFrameJniLibraryPath());
        }
        throw new IllegalArgumentException("Unsupported virgo.history.backend: " + config.getHistoryBackend());
    }

    private static ChannelCatalogService createChannelCatalogService(BackendConfig config, ZJChvBuf liveBuffer) {
        if (hasExternalCatalogOverride(config)) {
            return new HttpChannelCatalogService(config);
        }
        return new ZJChvChannelCatalogService(liveBuffer);
    }

    private static boolean hasExternalCatalogOverride(BackendConfig config) {
        return hasText(config.getChannelCatalogSearchUrl())
                || hasText(config.getChannelCatalogCategoriesUrl())
                || hasText(config.getChannelCatalogListUrl());
    }

    private static boolean hasText(String value) {
        return value != null && !value.trim().isEmpty();
    }
}
