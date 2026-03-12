package org.virgo.dataviewer.adapter.service;

import org.virgo.dataviewer.adapter.dto.LivePlotRequestDto;
import org.virgo.dataviewer.adapter.dto.LivePlotResponseDto;
import org.virgo.dataviewer.adapter.dto.PlotQueryRequestDto;
import org.virgo.dataviewer.adapter.dto.PlotQueryResponseDto;

public interface PlotService {
    PlotQueryResponseDto query(PlotQueryRequestDto request) throws AdapterException;

    LivePlotResponseDto live(LivePlotRequestDto request) throws AdapterException;
}
