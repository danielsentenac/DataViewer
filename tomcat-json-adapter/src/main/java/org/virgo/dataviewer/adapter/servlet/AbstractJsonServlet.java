package org.virgo.dataviewer.adapter.servlet;

import java.io.IOException;
import java.util.Map;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.virgo.dataviewer.adapter.dto.ApiErrorDto;
import org.virgo.dataviewer.adapter.dto.ErrorResponseDto;
import org.virgo.dataviewer.adapter.json.JsonCodec;
import org.virgo.dataviewer.adapter.service.AdapterException;
import org.virgo.dataviewer.adapter.service.DataViewerServices;

public abstract class AbstractJsonServlet extends HttpServlet {
    protected DataViewerServices services() throws AdapterException {
        return DataViewerServiceRegistry.requireServices(getServletContext());
    }

    protected JsonCodec jsonCodec() {
        return DataViewerServiceRegistry.resolveJsonCodec(getServletContext());
    }

    protected Map<String, Object> readJsonObject(HttpServletRequest request) throws IOException, AdapterException {
        Object payload = jsonCodec().read(request.getInputStream());
        if (payload == null) {
            throw AdapterException.badRequest("INVALID_PAYLOAD", "Expected a JSON request body.");
        }
        if (!(payload instanceof Map)) {
            throw AdapterException.badRequest("INVALID_PAYLOAD", "Expected a JSON object request body.");
        }
        @SuppressWarnings("unchecked")
        Map<String, Object> result = (Map<String, Object>) payload;
        return result;
    }

    protected void writeJson(HttpServletResponse response, int statusCode, Object payload) throws IOException {
        response.setStatus(statusCode);
        response.setCharacterEncoding("UTF-8");
        response.setContentType("application/json");
        jsonCodec().write(response.getOutputStream(), payload);
    }

    protected void writeAdapterException(HttpServletResponse response, AdapterException exception) throws IOException {
        writeJson(response, exception.getStatusCode(), DtoJsonMapper.errorResponse(exception));
    }

    protected void writeUnexpectedException(HttpServletResponse response, Exception exception) throws IOException {
        ErrorResponseDto payload = new ErrorResponseDto(
                new ApiErrorDto("INTERNAL_ERROR", exception.getMessage() == null ? "Internal server error." : exception.getMessage(), null));
        writeJson(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, DtoJsonMapper.errorResponse(payload));
    }
}
