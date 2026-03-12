package org.virgo.dataviewer.adapter.servlet;

import java.io.IOException;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.virgo.dataviewer.adapter.dto.ChannelSearchRequestDto;
import org.virgo.dataviewer.adapter.dto.ChannelSearchResponseDto;
import org.virgo.dataviewer.adapter.service.AdapterException;

@WebServlet("/api/v1/channels/search")
public class ChannelSearchServlet extends AbstractJsonServlet {
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try {
            ChannelSearchRequestDto query = DtoJsonMapper.channelSearchRequest(
                    request.getParameter("q"),
                    request.getParameter("category"),
                    request.getParameter("limit"),
                    request.getParameter("offset"));
            ChannelSearchResponseDto result = services().channelCatalogService().search(query);
            writeJson(response, HttpServletResponse.SC_OK, DtoJsonMapper.channelSearchResponse(result));
        } catch (AdapterException exception) {
            writeAdapterException(response, exception);
        } catch (Exception exception) {
            writeUnexpectedException(response, exception);
        }
    }
}
