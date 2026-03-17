package org.virgo.dataviewer.backend.live;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class LiveSnapshot {
    private final long gpsSeconds;
    private final long utcMs;
    private final Map<String, String> values;
    private final List<String> catalogChannelNames;

    LiveSnapshot(long gpsSeconds, long utcMs, Map<String, String> values, List<String> catalogChannelNames) {
        this.gpsSeconds = gpsSeconds;
        this.utcMs = utcMs;
        this.values = Collections.unmodifiableMap(new HashMap<String, String>(values));
        this.catalogChannelNames = Collections.unmodifiableList(new ArrayList<String>(
                catalogChannelNames == null ? Collections.<String>emptyList() : catalogChannelNames));
    }

    long getGpsSeconds() {
        return gpsSeconds;
    }

    long getUtcMs() {
        return utcMs;
    }

    List<String> getCatalogChannelNames() {
        return catalogChannelNames;
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
        return null;
    }
}
