package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class PlotQueryRequestDto {
    private List<String> channels = new ArrayList<String>();
    private TimeRangeRequestDto timeRange;
    private SamplingRequestDto sampling;

    public PlotQueryRequestDto() {
    }

    public PlotQueryRequestDto(List<String> channels, TimeRangeRequestDto timeRange, SamplingRequestDto sampling) {
        setChannels(channels);
        this.timeRange = timeRange;
        this.sampling = sampling;
    }

    public List<String> getChannels() {
        return new ArrayList<String>(channels);
    }

    public void setChannels(List<String> channels) {
        this.channels = new ArrayList<String>(channels == null ? Collections.<String>emptyList() : channels);
    }

    public TimeRangeRequestDto getTimeRange() {
        return timeRange;
    }

    public void setTimeRange(TimeRangeRequestDto timeRange) {
        this.timeRange = timeRange;
    }

    public SamplingRequestDto getSampling() {
        return sampling;
    }

    public void setSampling(SamplingRequestDto sampling) {
        this.sampling = sampling;
    }
}
