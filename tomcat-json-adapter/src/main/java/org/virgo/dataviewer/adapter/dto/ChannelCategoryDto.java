package org.virgo.dataviewer.adapter.dto;

public class ChannelCategoryDto {
    private String id;
    private String label;
    private int count;

    public ChannelCategoryDto() {
    }

    public ChannelCategoryDto(String id, String label, int count) {
        this.id = id;
        this.label = label;
        this.count = count;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label;
    }

    public int getCount() {
        return count;
    }

    public void setCount(int count) {
        this.count = count;
    }
}
