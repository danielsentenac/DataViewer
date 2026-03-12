package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class RawPlotSeriesDto extends PlotSeriesDto {
    private long startUtcMs;
    private int stepMs;
    private List<Double> values = new ArrayList<Double>();

    public RawPlotSeriesDto() {
        setSamplingMode(SamplingMode.RAW);
    }

    public RawPlotSeriesDto(
            String channel,
            String displayName,
            String unit,
            long startUtcMs,
            int stepMs,
            List<Double> values) {
        super(channel, displayName, unit, SamplingMode.RAW);
        this.startUtcMs = startUtcMs;
        this.stepMs = stepMs;
        setValues(values);
    }

    public long getStartUtcMs() {
        return startUtcMs;
    }

    public void setStartUtcMs(long startUtcMs) {
        this.startUtcMs = startUtcMs;
    }

    public int getStepMs() {
        return stepMs;
    }

    public void setStepMs(int stepMs) {
        this.stepMs = stepMs;
    }

    public List<Double> getValues() {
        return new ArrayList<Double>(values);
    }

    public void setValues(List<Double> values) {
        this.values = new ArrayList<Double>(values == null ? Collections.<Double>emptyList() : values);
    }
}
