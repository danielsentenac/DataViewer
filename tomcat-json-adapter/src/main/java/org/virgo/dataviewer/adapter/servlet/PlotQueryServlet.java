package org.virgo.dataviewer.adapter.servlet;

import java.io.IOException;
import java.util.Map;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.virgo.dataviewer.adapter.dto.PlotQueryRequestDto;
import org.virgo.dataviewer.adapter.dto.PlotQueryResponseDto;
import org.virgo.dataviewer.adapter.service.AdapterException;

@WebServlet("/api/v1/plots/query")
public class PlotQueryServlet extends AbstractJsonServlet {
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try {
            Map<String, Object> payload = readJsonObject(request);
            PlotQueryRequestDto dto = DtoJsonMapper.plotQueryRequest(payload);
            PlotQueryResponseDto result = services().plotService().query(dto);
            writeJson(response, HttpServletResponse.SC_OK, DtoJsonMapper.plotQueryResponse(result));
        } catch (AdapterException exception) {
            writeAdapterException(response, exception);
        } catch (Exception exception) {
            writeUnexpectedException(response, exception);
        }
    }
}
