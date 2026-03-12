package org.virgo.dataviewer.backend.history;

import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

import org.virgo.dataviewer.adapter.service.AdapterException;

public final class SwigTrendArchiveReader implements TrendArchiveReader {
    private static final Logger LOGGER = Logger.getLogger(SwigTrendArchiveReader.class.getName());

    private final String trendFflPath;
    private volatile boolean initialized;
    private volatile Class<?> swigFrFileClass;
    private volatile Class<?> swigFrVectClass;
    private volatile Method frFileINew;
    private volatile Method frFileIEnd;
    private volatile Method frFileITStart;
    private volatile Method frFileITEnd;
    private volatile Method frFileIGetVAdc;
    private volatile Method frVectSetMissingValues;
    private volatile Method frVectFree;
    private volatile Method frVectGetValueI;
    private volatile Method swigFrVectGetCPtr;
    private volatile Constructor<?> frVectCtor;
    private volatile Method frVectGetUnitY;
    private volatile Method frVectGetGTime;
    private volatile Method frVectGetNData;
    private volatile Method frVectGetDx;
    private volatile Method doubleArrayGetItem;

    public SwigTrendArchiveReader(String trendFflPath) {
        this.trendFflPath = trendFflPath;
    }

    @Override
    public ArchiveBounds resolveBounds() throws AdapterException {
        Object file = openFile();
        try {
            double start = ((Number) frFileITStart.invoke(null, file)).doubleValue();
            double end = ((Number) frFileITEnd.invoke(null, file)).doubleValue();
            return new ArchiveBounds(Math.round(start), Math.round(end));
        } catch (Exception exception) {
            throw AdapterException.serviceUnavailable("Unable to inspect trend archive: " + exception.getMessage());
        } finally {
            closeFile(file);
        }
    }

    @Override
    public List<TrendRawSeries> readRawSeries(List<String> channels, long startGps, long durationSeconds) throws AdapterException {
        Object file = openFile();
        List<TrendRawSeries> result = new ArrayList<TrendRawSeries>();
        try {
            for (String channel : channels == null ? Collections.<String>emptyList() : channels) {
                if (channel == null || channel.trim().isEmpty()) {
                    continue;
                }
                result.add(readOneChannel(file, channel.trim(), startGps, durationSeconds));
            }
            return result;
        } finally {
            closeFile(file);
        }
    }

    private TrendRawSeries readOneChannel(Object file, String channel, long startGps, long durationSeconds) throws AdapterException {
        Object vect = null;
        try {
            vect = frFileIGetVAdc.invoke(null, file, channel, Double.valueOf(startGps), Double.valueOf(durationSeconds), Integer.valueOf(1));
            if (vect == null) {
                return new TrendRawSeries(channel, null, startGps, 1,
                        new ArrayList<Double>(Collections.nCopies((int) durationSeconds, (Double) null)));
            }

            frVectSetMissingValues.invoke(null, vect, Double.valueOf(Double.NaN));

            long cPtr = ((Number) swigFrVectGetCPtr.invoke(null, vect)).longValue();
            Object frVect = frVectCtor.newInstance(Long.valueOf(cPtr), Boolean.FALSE);
            long seriesStartGps = Math.round(((Number) frVectGetGTime.invoke(frVect)).doubleValue());
            int sampleCount = Math.max(0, ((Number) frVectGetNData.invoke(frVect)).intValue());
            int stepSeconds = Math.max(1,
                    (int) Math.round(((Number) doubleArrayGetItem.invoke(null, frVectGetDx.invoke(frVect), Integer.valueOf(0))).doubleValue()));
            String unit = (String) frVectGetUnitY.invoke(frVect);
            List<Double> values = new ArrayList<Double>(sampleCount);
            for (int i = 0; i < sampleCount; i++) {
                double value = ((Number) frVectGetValueI.invoke(null, vect, Long.valueOf(i))).doubleValue();
                values.add(Double.isFinite(value) ? Double.valueOf(value) : null);
            }
            return new TrendRawSeries(channel, unit, seriesStartGps, stepSeconds, values);
        } catch (Exception exception) {
            throw AdapterException.serviceUnavailable("Unable to read trend archive for channel " + channel + ": " + exception.getMessage());
        } finally {
            if (vect != null) {
                try {
                    frVectFree.invoke(null, vect);
                } catch (Exception exception) {
                    LOGGER.log(Level.FINE, "Unable to free FrVect", exception);
                }
            }
        }
    }

    private Object openFile() throws AdapterException {
        ensureInitialized();
        try {
            Object file = frFileINew.invoke(null, trendFflPath);
            if (file == null) {
                throw AdapterException.serviceUnavailable("Unable to open trend archive: " + trendFflPath);
            }
            return file;
        } catch (AdapterException exception) {
            throw exception;
        } catch (Exception exception) {
            throw AdapterException.serviceUnavailable("Unable to open trend archive: " + exception.getMessage());
        }
    }

    private void closeFile(Object file) {
        if (file == null || frFileIEnd == null) {
            return;
        }
        try {
            frFileIEnd.invoke(null, file);
        } catch (Exception exception) {
            LOGGER.log(Level.FINE, "Unable to close FrFile", exception);
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
                System.loadLibrary("FraplotImp");
                Class<?> fraplotImpClass = Class.forName("FraplotImp");
                Class<?> swigDoubleClass = Class.forName("SWIGTYPE_p_double");
                swigFrFileClass = Class.forName("SWIGTYPE_p_FrFile");
                swigFrVectClass = Class.forName("SWIGTYPE_p_FrVect");
                Class<?> frVectClass = Class.forName("FrVect");

                frFileINew = fraplotImpClass.getMethod("FrFileINew", String.class);
                frFileIEnd = fraplotImpClass.getMethod("FrFileIEnd", swigFrFileClass);
                frFileITStart = fraplotImpClass.getMethod("FrFileITStart", swigFrFileClass);
                frFileITEnd = fraplotImpClass.getMethod("FrFileITEnd", swigFrFileClass);
                frFileIGetVAdc = fraplotImpClass.getMethod("FrFileIGetVAdc", swigFrFileClass, String.class, double.class,
                        double.class, int.class);
                frVectSetMissingValues = fraplotImpClass.getMethod("FrVectSetMissingValues", swigFrVectClass, double.class);
                frVectFree = fraplotImpClass.getMethod("FrVectFree", swigFrVectClass);
                frVectGetValueI = fraplotImpClass.getMethod("FrVectGetValueI", swigFrVectClass, long.class);
                doubleArrayGetItem = fraplotImpClass.getMethod("doubleArray_getitem", swigDoubleClass, int.class);

                swigFrVectGetCPtr = swigFrVectClass.getDeclaredMethod("getCPtr", swigFrVectClass);
                swigFrVectGetCPtr.setAccessible(true);
                frVectCtor = frVectClass.getDeclaredConstructor(long.class, boolean.class);
                frVectCtor.setAccessible(true);
                frVectGetUnitY = frVectClass.getMethod("getUnitY");
                frVectGetGTime = frVectClass.getMethod("getGTime");
                frVectGetNData = frVectClass.getMethod("getNData");
                frVectGetDx = frVectClass.getMethod("getDx");
                initialized = true;
            } catch (Throwable throwable) {
                throw AdapterException.serviceUnavailable(
                        "Frame archive runtime is unavailable. Ensure fraplot SWIG classes and libFraplotImp are deployed: "
                                + throwable.getMessage());
            }
        }
    }
}
