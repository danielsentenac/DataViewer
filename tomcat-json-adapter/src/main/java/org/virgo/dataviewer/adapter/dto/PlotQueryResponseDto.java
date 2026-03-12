package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class PlotQueryResponseDto {
    private PlotQueryMetadataDto query;
    private List<PlotSeriesDto> series = new ArrayList<PlotSeriesDto>();
    private LiveDirectiveDto live;

    public PlotQueryResponseDto() {
    }

    public PlotQueryResponseDto(PlotQueryMetadataDto query, List<PlotSeriesDto> series, LiveDirectiveDto live) {
        this.query = query;
        setSeries(series);
        this.live = live;
    }

    public PlotQueryMetadataDto getQuery() {
        return query;
    }

    public void setQuery(PlotQueryMetadataDto query) {
        this.query = query;
    }

    public List<PlotSeriesDto> getSeries() {
        return new ArrayList<PlotSeriesDto>(series);
    }

    public void setSeries(List<PlotSeriesDto> series) {
        this.series = new ArrayList<PlotSeriesDto>(series == null ? Collections.<PlotSeriesDto>emptyList() : series);
    }

    public LiveDirectiveDto getLive() {
        return live;
    }

    public void setLive(LiveDirectiveDto live) {
        this.live = live;
    }
}
