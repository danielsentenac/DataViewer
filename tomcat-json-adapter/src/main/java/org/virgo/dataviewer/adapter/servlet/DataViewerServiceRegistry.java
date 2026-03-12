package org.virgo.dataviewer.adapter.servlet;

import javax.servlet.ServletContext;

import org.virgo.dataviewer.adapter.json.JsonCodec;
import org.virgo.dataviewer.adapter.json.NashornJsonCodec;
import org.virgo.dataviewer.adapter.service.AdapterException;
import org.virgo.dataviewer.adapter.service.DataViewerServices;

public final class DataViewerServiceRegistry {
    public static final String SERVICES_ATTRIBUTE = DataViewerServices.class.getName();
    public static final String JSON_CODEC_ATTRIBUTE = JsonCodec.class.getName();

    private DataViewerServiceRegistry() {
    }

    public static void registerServices(ServletContext context, DataViewerServices services) {
        context.setAttribute(SERVICES_ATTRIBUTE, services);
    }

    public static DataViewerServices requireServices(ServletContext context) throws AdapterException {
        Object value = context.getAttribute(SERVICES_ATTRIBUTE);
        if (value instanceof DataViewerServices) {
            return (DataViewerServices) value;
        }
        throw AdapterException.serviceUnavailable(
                "DataViewer adapter services are not registered in the servlet context.");
    }

    public static void registerJsonCodec(ServletContext context, JsonCodec codec) {
        context.setAttribute(JSON_CODEC_ATTRIBUTE, codec);
    }

    public static JsonCodec resolveJsonCodec(ServletContext context) {
        Object value = context.getAttribute(JSON_CODEC_ATTRIBUTE);
        if (value instanceof JsonCodec) {
            return (JsonCodec) value;
        }
        JsonCodec codec = new NashornJsonCodec();
        context.setAttribute(JSON_CODEC_ATTRIBUTE, codec);
        return codec;
    }
}
