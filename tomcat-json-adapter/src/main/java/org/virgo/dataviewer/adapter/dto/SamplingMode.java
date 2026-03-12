package org.virgo.dataviewer.adapter.dto;

public enum SamplingMode {
    RAW("raw"),
    MINMAX_BUCKET("minmax_bucket");

    private final String wireValue;

    SamplingMode(String wireValue) {
        this.wireValue = wireValue;
    }

    public String getWireValue() {
        return wireValue;
    }

    @Override
    public String toString() {
        return wireValue;
    }
}
