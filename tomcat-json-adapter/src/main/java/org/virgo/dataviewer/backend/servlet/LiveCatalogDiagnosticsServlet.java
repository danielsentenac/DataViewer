package org.virgo.dataviewer.backend.servlet;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.virgo.dataviewer.adapter.service.AdapterException;
import org.virgo.dataviewer.adapter.servlet.AbstractJsonServlet;
import org.virgo.dataviewer.backend.service.LiveCatalogDiagnostics;
import org.virgo.dataviewer.backend.service.VirgoTomcatServices;

@WebServlet("/api/v1/diagnostics/live-catalog")
public final class LiveCatalogDiagnosticsServlet extends AbstractJsonServlet {
    @Override
    protected boolean shouldRegisterSession(HttpServletRequest request) {
        return false;
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try {
            if (!(services() instanceof VirgoTomcatServices)) {
                throw AdapterException.serviceUnavailable("Live catalog diagnostics are unavailable for this backend.");
            }
            LiveCatalogDiagnostics diagnostics = ((VirgoTomcatServices) services()).liveCatalogDiagnostics();
            writeJson(response, HttpServletResponse.SC_OK, toPayload(diagnostics));
        } catch (AdapterException exception) {
            writeAdapterException(response, exception);
        } catch (Exception exception) {
            writeUnexpectedException(response, exception);
        }
    }

    private static Map<String, Object> toPayload(LiveCatalogDiagnostics diagnostics) {
        Map<String, Object> payload = new LinkedHashMap<String, Object>();
        payload.put("liveSourceConfigured", Boolean.valueOf(diagnostics.isLiveSourceConfigured()));
        payload.put("bufferMinutes", Integer.valueOf(diagnostics.getBufferMinutes()));
        payload.put("configuredBufferSeconds", Integer.valueOf(diagnostics.getConfiguredBufferSeconds()));
        payload.put("bufferedSnapshots", Integer.valueOf(diagnostics.getBufferedSnapshots()));
        payload.put("channelCount", Integer.valueOf(diagnostics.getChannelCount()));
        payload.put("oldestBufferedUtcMs", Long.valueOf(diagnostics.getOldestBufferedUtcMs()));
        payload.put("latestBufferedUtcMs", Long.valueOf(diagnostics.getLatestBufferedUtcMs()));
        return payload;
    }
}
