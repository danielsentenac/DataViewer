package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class LivePlotRequestDto {
    private List<String> channels = new ArrayList<String>();
    private long afterUtcMs;

    public LivePlotRequestDto() {
    }

    public LivePlotRequestDto(List<String> channels, long afterUtcMs) {
        setChannels(channels);
        this.afterUtcMs = afterUtcMs;
    }

    public List<String> getChannels() {
        return new ArrayList<String>(channels);
    }

    public void setChannels(List<String> channels) {
        this.channels = new ArrayList<String>(channels == null ? Collections.<String>emptyList() : channels);
    }

    public long getAfterUtcMs() {
        return afterUtcMs;
    }

    public void setAfterUtcMs(long afterUtcMs) {
        this.afterUtcMs = afterUtcMs;
    }
}
