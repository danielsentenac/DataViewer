package org.virgo.dataviewer.adapter.servlet;

import java.io.IOException;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.virgo.dataviewer.adapter.dto.ChannelCategoriesResponseDto;
import org.virgo.dataviewer.adapter.service.AdapterException;

@WebServlet("/api/v1/channels/categories")
public class ChannelCategoriesServlet extends AbstractJsonServlet {
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try {
            ChannelCategoriesResponseDto result = services().channelCatalogService().categories();
            writeJson(response, HttpServletResponse.SC_OK, DtoJsonMapper.channelCategoriesResponse(result));
        } catch (AdapterException exception) {
            writeAdapterException(response, exception);
        } catch (Exception exception) {
            writeUnexpectedException(response, exception);
        }
    }
}
