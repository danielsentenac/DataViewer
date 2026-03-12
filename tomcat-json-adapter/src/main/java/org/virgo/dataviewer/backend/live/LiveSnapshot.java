package org.virgo.dataviewer.backend.live;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

final class LiveSnapshot {
    private final long gpsSeconds;
    private final long utcMs;
    private final Map<String, String> values;
    private final Map<String, String> normalizedValues;
    private final List<LiveCatalogChannel> catalogChannels;

    LiveSnapshot(long gpsSeconds, long utcMs, Map<String, String> values, List<LiveCatalogChannel> catalogChannels) {
        this.gpsSeconds = gpsSeconds;
        this.utcMs = utcMs;
        this.values = Collections.unmodifiableMap(new HashMap<String, String>(values));
        this.normalizedValues = Collections.unmodifiableMap(buildNormalizedValues(values));
        this.catalogChannels = Collections.unmodifiableList(new ArrayList<LiveCatalogChannel>(
                catalogChannels == null ? Collections.<LiveCatalogChannel>emptyList() : catalogChannels));
    }

    long getGpsSeconds() {
        return gpsSeconds;
    }

    long getUtcMs() {
        return utcMs;
    }

    List<LiveCatalogChannel> getCatalogChannels() {
        return new ArrayList<LiveCatalogChannel>(catalogChannels);
    }

    String findValue(String requestedChannel) {
        if (requestedChannel == null) {
            return null;
        }
        String key = requestedChannel.trim();
        if (key.isEmpty()) {
            return null;
        }
        String exact = values.get(key);
        if (exact != null) {
            return exact;
        }
        return normalizedValues.get(normalizeChannelKey(key));
    }

    private static Map<String, String> buildNormalizedValues(Map<String, String> source) {
        Map<String, String> out = new HashMap<String, String>();
        for (Map.Entry<String, String> entry : source.entrySet()) {
            String normalized = normalizeChannelKey(entry.getKey());
            if (normalized.isEmpty() || out.containsKey(normalized)) {
                continue;
            }
            out.put(normalized, entry.getValue());
        }
        return out;
    }

    private static String normalizeChannelKey(String key) {
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
                trimmed = trimmed.substring(separator + 1).trim();
            }
        }
        return trimmed.toUpperCase(Locale.US);
    }
}
