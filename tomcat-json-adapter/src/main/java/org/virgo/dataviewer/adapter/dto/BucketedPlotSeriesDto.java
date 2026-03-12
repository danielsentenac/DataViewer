package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class BucketedPlotSeriesDto extends PlotSeriesDto {
    private long startUtcMs;
    private int bucketSeconds;
    private List<Double> minValues = new ArrayList<Double>();
    private List<Double> maxValues = new ArrayList<Double>();

    public BucketedPlotSeriesDto() {
        setSamplingMode(SamplingMode.MINMAX_BUCKET);
    }

    public BucketedPlotSeriesDto(
            String channel,
            String displayName,
            String unit,
            long startUtcMs,
            int bucketSeconds,
            List<Double> minValues,
            List<Double> maxValues) {
        super(channel, displayName, unit, SamplingMode.MINMAX_BUCKET);
        this.startUtcMs = startUtcMs;
        this.bucketSeconds = bucketSeconds;
        setMinValues(minValues);
        setMaxValues(maxValues);
    }

    public long getStartUtcMs() {
        return startUtcMs;
    }

    public void setStartUtcMs(long startUtcMs) {
        this.startUtcMs = startUtcMs;
    }

    public int getBucketSeconds() {
        return bucketSeconds;
    }

    public void setBucketSeconds(int bucketSeconds) {
        this.bucketSeconds = bucketSeconds;
    }

    public List<Double> getMinValues() {
        return new ArrayList<Double>(minValues);
    }

    public void setMinValues(List<Double> minValues) {
        this.minValues = new ArrayList<Double>(minValues == null ? Collections.<Double>emptyList() : minValues);
    }

    public List<Double> getMaxValues() {
        return new ArrayList<Double>(maxValues);
    }

    public void setMaxValues(List<Double> maxValues) {
        this.maxValues = new ArrayList<Double>(maxValues == null ? Collections.<Double>emptyList() : maxValues);
    }
}
