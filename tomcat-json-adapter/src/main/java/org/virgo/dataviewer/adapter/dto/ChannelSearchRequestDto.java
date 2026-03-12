package org.virgo.dataviewer.adapter.dto;

public class ChannelSearchRequestDto {
    private String query;
    private String category;
    private Integer limit;
    private Integer offset;

    public ChannelSearchRequestDto() {
    }

    public ChannelSearchRequestDto(String query, String category, Integer limit, Integer offset) {
        this.query = query;
        this.category = category;
        this.limit = limit;
        this.offset = offset;
    }

    public String getQuery() {
        return query;
    }

    public void setQuery(String query) {
        this.query = query;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public Integer getLimit() {
        return limit;
    }

    public void setLimit(Integer limit) {
        this.limit = limit;
    }

    public Integer getOffset() {
        return offset;
    }

    public void setOffset(Integer offset) {
        this.offset = offset;
    }
}
