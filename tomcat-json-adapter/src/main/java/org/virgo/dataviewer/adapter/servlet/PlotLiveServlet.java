package org.virgo.dataviewer.adapter.servlet;

import java.io.IOException;
import java.util.Map;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.virgo.dataviewer.adapter.dto.LivePlotRequestDto;
import org.virgo.dataviewer.adapter.dto.LivePlotResponseDto;
import org.virgo.dataviewer.adapter.service.AdapterException;

@WebServlet("/api/v1/plots/live")
public class PlotLiveServlet extends AbstractJsonServlet {
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try {
            Map<String, Object> payload = readJsonObject(request);
            LivePlotRequestDto dto = DtoJsonMapper.livePlotRequest(payload);
            LivePlotResponseDto result = services().plotService().live(dto);
            writeJson(response, HttpServletResponse.SC_OK, DtoJsonMapper.livePlotResponse(result));
        } catch (AdapterException exception) {
            writeAdapterException(response, exception);
        } catch (Exception exception) {
            writeUnexpectedException(response, exception);
        }
    }
}
