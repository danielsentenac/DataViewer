package org.virgo.dataviewer.adapter.servlet;

import java.io.IOException;
import java.util.Map;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;

import org.virgo.dataviewer.adapter.dto.ApiErrorDto;
import org.virgo.dataviewer.adapter.dto.ErrorResponseDto;
import org.virgo.dataviewer.adapter.json.JsonCodec;
import org.virgo.dataviewer.adapter.service.AdapterException;
import org.virgo.dataviewer.adapter.service.DataViewerServices;

public abstract class AbstractJsonServlet extends HttpServlet {
    private static final String SESSION_MARKER_ATTRIBUTE = "org.virgo.dataviewer.session.registered";
    private static final String SESSION_LAST_SEEN_ATTRIBUTE = "org.virgo.dataviewer.session.lastSeenUtcMs";
    private static final String SESSION_USER_AGENT_ATTRIBUTE = "org.virgo.dataviewer.session.userAgent";

    @Override
    protected void service(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        registerSession(request);
        super.service(request, response);
    }

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

    protected boolean shouldRegisterSession(HttpServletRequest request) {
        return !"OPTIONS".equalsIgnoreCase(request.getMethod());
    }

    private void registerSession(HttpServletRequest request) {
        if (!shouldRegisterSession(request)) {
            return;
        }

        HttpSession session = request.getSession(true);
        session.setAttribute(SESSION_MARKER_ATTRIBUTE, Boolean.TRUE);
        session.setAttribute(SESSION_LAST_SEEN_ATTRIBUTE, Long.valueOf(System.currentTimeMillis()));

        String userAgent = request.getHeader("User-Agent");
        if (userAgent != null && !userAgent.trim().isEmpty() && session.getAttribute(SESSION_USER_AGENT_ATTRIBUTE) == null) {
            session.setAttribute(SESSION_USER_AGENT_ATTRIBUTE, userAgent);
        }
    }
}
