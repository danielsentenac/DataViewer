package org.virgo.dataviewer.backend.history;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import org.virgo.dataviewer.adapter.service.AdapterException;

public final class JniTrendArchiveReader implements TrendArchiveReader {
    private final String trendFflPath;
    private final String libraryName;
    private final String libraryPath;
    private volatile boolean initialized;

    public JniTrendArchiveReader(String trendFflPath, String libraryName, String libraryPath) {
        this.trendFflPath = trendFflPath;
        this.libraryName = libraryName;
        this.libraryPath = libraryPath;
    }

    @Override
    public ArchiveBounds resolveBounds() throws AdapterException {
        ensureInitialized();
        try {
            long[] bounds = resolveBoundsNative(trendFflPath);
            if (bounds == null || bounds.length < 2) {
                throw AdapterException.serviceUnavailable("Frame archive JNI returned invalid archive bounds.");
            }
            return new ArchiveBounds(bounds[0], bounds[1]);
        } catch (AdapterException exception) {
            throw exception;
        } catch (Throwable throwable) {
            throw AdapterException.serviceUnavailable("Unable to inspect trend archive through JNI: " + throwable.getMessage());
        }
    }

    @Override
    public List<TrendRawSeries> readRawSeries(List<String> channels, long startGps, long durationSeconds) throws AdapterException {
        ensureInitialized();
        List<TrendRawSeries> out = new ArrayList<TrendRawSeries>();
        for (String channel : channels == null ? Collections.<String>emptyList() : channels) {
            if (channel == null || channel.trim().isEmpty()) {
                continue;
            }
            out.add(readOneChannel(channel.trim(), startGps, durationSeconds));
        }
        return out;
    }

    private TrendRawSeries readOneChannel(String channel, long startGps, long durationSeconds) throws AdapterException {
        try {
            JniArchiveSlice slice = readRawSeriesNative(trendFflPath, channel, startGps, durationSeconds);
            if (slice == null) {
                return new TrendRawSeries(channel, null, startGps, 1, nullFilledValues(durationSeconds));
            }
            return new TrendRawSeries(
                    channel,
                    slice.getUnit(),
                    slice.getStartGps(),
                    Math.max(1, slice.getStepSeconds()),
                    toNullableValues(slice.getValues()));
        } catch (Throwable throwable) {
            throw AdapterException.serviceUnavailable(
                    "Unable to read trend archive through JNI for channel " + channel + ": " + throwable.getMessage());
        }
    }

    private void ensureInitialized() throws AdapterException {
        if (initialized) {
            return;
        }
        synchronized (this) {
            if (initialized) {
                return;
            }
            try {
                if (libraryPath != null && !libraryPath.trim().isEmpty()) {
                    System.load(libraryPath);
                } else {
                    System.loadLibrary(libraryName);
                }
                initialized = true;
            } catch (Throwable throwable) {
                throw AdapterException.serviceUnavailable(
                        "Frame archive JNI runtime is unavailable. Ensure " + libraryName + " is deployed: " + throwable.getMessage());
            }
        }
    }

    private static List<Double> toNullableValues(double[] rawValues) {
        List<Double> values = new ArrayList<Double>(rawValues == null ? 0 : rawValues.length);
        if (rawValues == null) {
            return values;
        }
        for (double rawValue : rawValues) {
            values.add(Double.isFinite(rawValue) ? Double.valueOf(rawValue) : null);
        }
        return values;
    }

    private static List<Double> nullFilledValues(long sampleCount) throws AdapterException {
        if (sampleCount < 0L || sampleCount > Integer.MAX_VALUE) {
            throw AdapterException.badRequest("INVALID_TIME_RANGE", "Requested archive span is too large.");
        }
        return new ArrayList<Double>(Collections.nCopies((int) sampleCount, (Double) null));
    }

    private static native long[] resolveBoundsNative(String trendFflPath);

    private static native JniArchiveSlice readRawSeriesNative(String trendFflPath, String channel, long startGps, long durationSeconds);
}
