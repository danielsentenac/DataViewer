package org.virgo.dataviewer.backend.live;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

import org.virgo.dataviewer.adapter.dto.ChannelSummaryDto;
import org.virgo.dataviewer.adapter.dto.LivePlotSeriesDto;
import org.virgo.dataviewer.backend.config.BackendConfig;
import org.virgo.dataviewer.backend.time.GpsTimeConverter;

public final class ZJChvBuf implements AutoCloseable {
    private static final Logger LOGGER = Logger.getLogger(ZJChvBuf.class.getName());

    private final String zcmSubEndpoint;
    private final int maxSnapshots;
    private final GpsTimeConverter gpsTimeConverter;
    private final ZfdPayloadDecoder decoder;
    private final Object bufferLock = new Object();
    private final Deque<LiveSnapshot> snapshots = new ArrayDeque<LiveSnapshot>();
    private final Map<String, String> catalogUnitsByName = new LinkedHashMap<String, String>();
    private final Map<String, Integer> catalogReferenceCounts = new HashMap<String, Integer>();
    private final Map<String, String> normalizedCatalogNames = new HashMap<String, String>();
    private volatile boolean running;
    private volatile Thread subscriberThread;

    public ZJChvBuf(BackendConfig config, GpsTimeConverter gpsTimeConverter) {
        this.zcmSubEndpoint = config.getZcmSubEndpoint();
        this.maxSnapshots = config.getLiveBufferSeconds();
        this.gpsTimeConverter = gpsTimeConverter;
        this.decoder = new ZfdPayloadDecoder(config.getGpsChannel(), gpsTimeConverter);
        if (!this.zcmSubEndpoint.isEmpty()) {
            start();
        } else {
            LOGGER.warning("zcmsubendpoint is not configured; live buffer will stay idle.");
        }
    }

    public boolean hasSource() {
        return !zcmSubEndpoint.isEmpty();
    }

    public int getConfiguredBufferSeconds() {
        return maxSnapshots;
    }

    public int snapshotCount() {
        synchronized (bufferLock) {
            return snapshots.size();
        }
    }

    public long getOldestBufferedUtcMs() {
        synchronized (bufferLock) {
            return snapshots.isEmpty() ? -1L : snapshots.getFirst().getUtcMs();
        }
    }

    public long getLatestBufferedUtcMs() {
        synchronized (bufferLock) {
            return snapshots.isEmpty() ? -1L : snapshots.getLast().getUtcMs();
        }
    }

    public List<ChannelSummaryDto> snapshotCatalog() {
        synchronized (bufferLock) {
            List<ChannelSummaryDto> entries = new ArrayList<ChannelSummaryDto>(catalogUnitsByName.size());
            for (Map.Entry<String, String> entry : catalogUnitsByName.entrySet()) {
                String name = entry.getKey();
                if (name == null || name.trim().isEmpty()) {
                    continue;
                }
                entries.add(new ChannelSummaryDto(
                        name,
                        deriveDisplayName(name),
                        entry.getValue(),
                        deriveCategory(name),
                        1));
            }
            return entries;
        }
    }

    public List<LivePlotSeriesDto> collectSeries(List<String> channels, long afterUtcMs) {
        List<LiveSnapshot> buffered;
        List<String> requestedChannels = channels == null ? Collections.<String>emptyList() : channels;
        List<String> resolvedChannels = new ArrayList<String>(requestedChannels.size());
        synchronized (bufferLock) {
            buffered = new ArrayList<LiveSnapshot>(snapshots.size());
            for (LiveSnapshot snapshot : snapshots) {
                if (snapshot.getUtcMs() > afterUtcMs) {
                    buffered.add(snapshot);
                }
            }
            for (String channel : requestedChannels) {
                resolvedChannels.add(resolveStoredChannelName(channel));
            }
        }
        if (buffered.isEmpty() || requestedChannels.isEmpty()) {
            return Collections.emptyList();
        }

        long startGps = buffered.get(0).getGpsSeconds();
        long endGps = buffered.get(buffered.size() - 1).getGpsSeconds();
        int span = (int) Math.max(1L, endGps - startGps + 1L);
        Map<Long, LiveSnapshot> byGps = new HashMap<Long, LiveSnapshot>(buffered.size());
        for (LiveSnapshot snapshot : buffered) {
            byGps.put(Long.valueOf(snapshot.getGpsSeconds()), snapshot);
        }

        List<LivePlotSeriesDto> result = new ArrayList<LivePlotSeriesDto>(requestedChannels.size());
        for (int channelIndex = 0; channelIndex < requestedChannels.size(); channelIndex++) {
            String channel = requestedChannels.get(channelIndex);
            String resolvedChannel = resolvedChannels.get(channelIndex);
            List<Double> values = new ArrayList<Double>(Collections.nCopies(span, (Double) null));
            for (long gps = startGps; gps <= endGps; gps++) {
                LiveSnapshot snapshot = byGps.get(Long.valueOf(gps));
                if (snapshot == null) {
                    continue;
                }
                values.set((int) (gps - startGps), parseNumeric(snapshot.findValue(resolvedChannel)));
            }
            result.add(new LivePlotSeriesDto(channel, gpsTimeConverter.gpsSecondsToUtcMs(startGps), 1000, values));
        }
        return result;
    }

    private void start() {
        running = true;
        Thread thread = new Thread(new Runnable() {
            @Override
            public void run() {
                runSubscriberLoop();
            }
        }, "Virgo-ZJChvBuf-Subscriber");
        thread.setDaemon(true);
        subscriberThread = thread;
        thread.start();
    }

    private void runSubscriberLoop() {
        while (running) {
            Object context = null;
            Object socket = null;
            try {
                Class<?> zmqClass = Class.forName("org.zeromq.ZMQ");
                int subType = ((Integer) zmqClass.getField("SUB").get(null)).intValue();
                context = zmqClass.getMethod("context", int.class).invoke(null, Integer.valueOf(1));
                socket = context.getClass().getMethod("socket", int.class).invoke(context, Integer.valueOf(subType));
                Class<?> socketClass = socket.getClass();
                socketClass.getMethod("setLinger", int.class).invoke(socket, Integer.valueOf(0));
                socketClass.getMethod("setReceiveTimeOut", int.class).invoke(socket, Integer.valueOf(500));
                socketClass.getMethod("subscribe", byte[].class).invoke(socket, new Object[] { new byte[0] });
                socketClass.getMethod("connect", String.class).invoke(socket, zcmSubEndpoint);

                while (running) {
                    Object frame = socketClass.getMethod("recv", int.class).invoke(socket, Integer.valueOf(0));
                    if (!(frame instanceof byte[])) {
                        continue;
                    }
                    acceptPayload((byte[]) frame);
                }
            } catch (Throwable exception) {
                if (running) {
                    LOGGER.log(Level.WARNING, "zJChv live subscriber error: " + exception.getMessage(), exception);
                }
            } finally {
                closeZmqObject(socket);
                closeZmqObject(context);
            }

            if (!running) {
                break;
            }
            try {
                Thread.sleep(1000L);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }

    private void acceptPayload(byte[] payload) {
        Map<String, String> catalogUnits = new LinkedHashMap<String, String>();
        LiveSnapshot snapshot = decoder.decode(payload, catalogUnits);
        LiveSnapshot last;
        if (snapshot == null) {
            return;
        }
        synchronized (bufferLock) {
            last = snapshots.peekLast();
            if (last != null && snapshot.getGpsSeconds() < last.getGpsSeconds()) {
                return;
            }
            if (last != null && snapshot.getGpsSeconds() == last.getGpsSeconds()) {
                snapshots.removeLast();
                releaseCatalogEntries(last);
            }
            snapshots.addLast(snapshot);
            retainCatalogEntries(snapshot, catalogUnits);
            while (snapshots.size() > maxSnapshots) {
                releaseCatalogEntries(snapshots.removeFirst());
            }
        }
    }

    private void retainCatalogEntries(LiveSnapshot snapshot, Map<String, String> catalogUnits) {
        for (String name : snapshot.getCatalogChannelNames()) {
            if (name == null || name.isEmpty()) {
                continue;
            }
            Integer count = catalogReferenceCounts.get(name);
            catalogReferenceCounts.put(name, Integer.valueOf(count == null ? 1 : count.intValue() + 1));
            if (count == null) {
                catalogUnitsByName.put(name, catalogUnits.get(name));
                normalizedCatalogNames.put(normalizeChannelKey(name), name);
            } else if (catalogUnitsByName.get(name) == null && catalogUnits.get(name) != null) {
                catalogUnitsByName.put(name, catalogUnits.get(name));
            }
        }
    }

    private void releaseCatalogEntries(LiveSnapshot snapshot) {
        for (String name : snapshot.getCatalogChannelNames()) {
            Integer count = catalogReferenceCounts.get(name);
            if (count == null) {
                continue;
            }
            if (count.intValue() <= 1) {
                catalogReferenceCounts.remove(name);
                catalogUnitsByName.remove(name);
                dropNormalizedCatalogName(name);
                continue;
            }
            catalogReferenceCounts.put(name, Integer.valueOf(count.intValue() - 1));
        }
    }

    private void dropNormalizedCatalogName(String channelName) {
        String normalized = normalizeChannelKey(channelName);
        if (!channelName.equals(normalizedCatalogNames.get(normalized))) {
            return;
        }
        normalizedCatalogNames.remove(normalized);
        for (String candidate : catalogUnitsByName.keySet()) {
            if (!channelName.equals(candidate) && normalized.equals(normalizeChannelKey(candidate))) {
                normalizedCatalogNames.put(normalized, candidate);
                break;
            }
        }
    }

    private String resolveStoredChannelName(String requestedChannel) {
        if (requestedChannel == null) {
            return null;
        }
        String trimmed = requestedChannel.trim();
        if (trimmed.isEmpty()) {
            return trimmed;
        }
        if (catalogUnitsByName.containsKey(trimmed)) {
            return trimmed;
        }
        String resolved = normalizedCatalogNames.get(normalizeChannelKey(trimmed));
        return resolved == null ? trimmed : resolved;
    }

    private static Double parseNumeric(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.isEmpty() || "NOTEXIST".equalsIgnoreCase(trimmed) || "---".equals(trimmed)) {
            return null;
        }
        try {
            double parsed = Double.parseDouble(trimmed);
            return Double.isFinite(parsed) ? Double.valueOf(parsed) : null;
        } catch (NumberFormatException exception) {
            return null;
        }
    }

    private static void closeZmqObject(Object value) {
        if (value == null) {
            return;
        }
        try {
            value.getClass().getMethod("close").invoke(value);
        } catch (Throwable firstFailure) {
            try {
                value.getClass().getMethod("term").invoke(value);
            } catch (Throwable ignored) {
            }
        }
    }

    private static String deriveDisplayName(String channelName) {
        String base = stripVersionPrefix(channelName);
        int colon = base.indexOf(':');
        if (colon >= 0 && colon + 1 < base.length()) {
            base = base.substring(colon + 1);
        }
        return base.replace('_', ' ').trim();
    }

    private static String deriveCategory(String channelName) {
        String base = stripVersionPrefix(channelName);
        int colon = base.indexOf(':');
        if (colon >= 0 && colon + 1 < base.length()) {
            base = base.substring(colon + 1);
        }
        String[] tokens = base.split("[-_]");
        if (tokens.length >= 2) {
            String first = tokens[0].trim();
            String second = tokens[1].trim();
            if (!first.isEmpty() && !second.isEmpty()) {
                String firstUpper = first.toUpperCase(Locale.US);
                if ("INF".equals(firstUpper) || "VAC".equals(firstUpper) || "HVAC".equals(firstUpper)) {
                    return firstUpper + "_" + second.toUpperCase(Locale.US);
                }
                return second.toUpperCase(Locale.US);
            }
        }
        if (tokens.length >= 1 && !tokens[0].trim().isEmpty()) {
            return tokens[0].trim().toUpperCase(Locale.US);
        }
        return null;
    }

    private static String stripVersionPrefix(String key) {
        if (key == null) {
            return "";
        }
        String trimmed = key.trim();
        int separator = trimmed.indexOf(':');
        if (separator > 1 && separator < trimmed.length() - 1
                && (trimmed.charAt(0) == 'V' || trimmed.charAt(0) == 'v')) {
            boolean digits = true;
            for (int i = 1; i < separator; i++) {
                char ch = trimmed.charAt(i);
                if (ch < '0' || ch > '9') {
                    digits = false;
                    break;
                }
            }
            if (digits) {
                return trimmed.substring(separator + 1).trim();
            }
        }
        return trimmed;
    }

    private static String normalizeChannelKey(String key) {
        return stripVersionPrefix(key).toUpperCase(Locale.US);
    }

    @Override
    public void close() {
        running = false;
        Thread thread = subscriberThread;
        if (thread != null) {
            try {
                thread.join(1000L);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
            }
            subscriberThread = null;
        }
        synchronized (bufferLock) {
            snapshots.clear();
        }
    }
}
