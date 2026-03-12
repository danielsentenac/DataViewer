package org.virgo.dataviewer.adapter.dto;

public abstract class PlotSeriesDto {
    private String channel;
    private String displayName;
    private String unit;
    private SamplingMode samplingMode;

    protected PlotSeriesDto() {
    }

    protected PlotSeriesDto(String channel, String displayName, String unit, SamplingMode samplingMode) {
        this.channel = channel;
        this.displayName = displayName;
        this.unit = unit;
        this.samplingMode = samplingMode;
    }

    public String getChannel() {
        return channel;
    }

    public void setChannel(String channel) {
        this.channel = channel;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public String getUnit() {
        return unit;
    }

    public void setUnit(String unit) {
        this.unit = unit;
    }

    public SamplingMode getSamplingMode() {
        return samplingMode;
    }

    public void setSamplingMode(SamplingMode samplingMode) {
        this.samplingMode = samplingMode;
    }
}
