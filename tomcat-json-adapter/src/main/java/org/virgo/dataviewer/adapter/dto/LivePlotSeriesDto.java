package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class LivePlotSeriesDto {
    private String channel;
    private long startUtcMs;
    private int stepMs;
    private List<Double> values = new ArrayList<Double>();

    public LivePlotSeriesDto() {
    }

    public LivePlotSeriesDto(String channel, long startUtcMs, int stepMs, List<Double> values) {
        this.channel = channel;
        this.startUtcMs = startUtcMs;
        this.stepMs = stepMs;
        setValues(values);
    }

    public String getChannel() {
        return channel;
    }

    public void setChannel(String channel) {
        this.channel = channel;
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
