package org.virgo.dataviewer.adapter.service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class AdapterException extends Exception {
    private final int statusCode;
    private final String errorCode;
    private final List<String> details;

    public AdapterException(int statusCode, String errorCode, String message) {
        this(statusCode, errorCode, message, Collections.<String>emptyList());
    }

    public AdapterException(int statusCode, String errorCode, String message, List<String> details) {
        super(message);
        this.statusCode = statusCode;
        this.errorCode = errorCode;
        this.details = new ArrayList<String>(details == null ? Collections.<String>emptyList() : details);
    }

    public int getStatusCode() {
        return statusCode;
    }

    public String getErrorCode() {
        return errorCode;
    }

    public List<String> getDetails() {
        return new ArrayList<String>(details);
    }

    public static AdapterException badRequest(String code, String message) {
        return new AdapterException(400, code, message);
    }

    public static AdapterException badRequest(String code, String message, List<String> details) {
        return new AdapterException(400, code, message, details);
    }

    public static AdapterException serviceUnavailable(String message) {
        return new AdapterException(503, "UPSTREAM_UNAVAILABLE", message);
    }
}
