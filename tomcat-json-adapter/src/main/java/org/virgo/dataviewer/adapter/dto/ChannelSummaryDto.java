package org.virgo.dataviewer.adapter.dto;

public class ChannelSummaryDto {
    private String name;
    private String displayName;
    private String unit;
    private String category;
    private int sampleRateHz;

    public ChannelSummaryDto() {
    }

    public ChannelSummaryDto(String name, String displayName, String unit, String category, int sampleRateHz) {
        this.name = name;
        this.displayName = displayName;
        this.unit = unit;
        this.category = category;
        this.sampleRateHz = sampleRateHz;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
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

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public int getSampleRateHz() {
        return sampleRateHz;
    }

    public void setSampleRateHz(int sampleRateHz) {
        this.sampleRateHz = sampleRateHz;
    }
}
