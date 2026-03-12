package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class LivePlotResponseDto {
    private long serverNowUtcMs;
    private List<LivePlotSeriesDto> series = new ArrayList<LivePlotSeriesDto>();

    public LivePlotResponseDto() {
    }

    public LivePlotResponseDto(long serverNowUtcMs, List<LivePlotSeriesDto> series) {
        this.serverNowUtcMs = serverNowUtcMs;
        setSeries(series);
    }

    public long getServerNowUtcMs() {
        return serverNowUtcMs;
    }

    public void setServerNowUtcMs(long serverNowUtcMs) {
        this.serverNowUtcMs = serverNowUtcMs;
    }

    public List<LivePlotSeriesDto> getSeries() {
        return new ArrayList<LivePlotSeriesDto>(series);
    }

    public void setSeries(List<LivePlotSeriesDto> series) {
        this.series = new ArrayList<LivePlotSeriesDto>(
                series == null ? Collections.<LivePlotSeriesDto>emptyList() : series);
    }
}
