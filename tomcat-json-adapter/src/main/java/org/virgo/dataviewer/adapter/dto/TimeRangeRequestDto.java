package org.virgo.dataviewer.adapter.dto;

public class TimeRangeRequestDto {
    private String startLocalIso;
    private String timeZone;

    public TimeRangeRequestDto() {
    }

    public TimeRangeRequestDto(String startLocalIso, String timeZone) {
        this.startLocalIso = startLocalIso;
        this.timeZone = timeZone;
    }

    public String getStartLocalIso() {
        return startLocalIso;
    }

    public void setStartLocalIso(String startLocalIso) {
        this.startLocalIso = startLocalIso;
    }

    public String getTimeZone() {
        return timeZone;
    }

    public void setTimeZone(String timeZone) {
        this.timeZone = timeZone;
    }
}
