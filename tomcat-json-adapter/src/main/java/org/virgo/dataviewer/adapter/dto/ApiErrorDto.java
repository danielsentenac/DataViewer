package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class ApiErrorDto {
    private String code;
    private String message;
    private List<String> details = new ArrayList<String>();

    public ApiErrorDto() {
    }

    public ApiErrorDto(String code, String message, List<String> details) {
        this.code = code;
        this.message = message;
        setDetails(details);
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public List<String> getDetails() {
        return new ArrayList<String>(details);
    }

    public void setDetails(List<String> details) {
        this.details = new ArrayList<String>(details == null ? Collections.<String>emptyList() : details);
    }
}
