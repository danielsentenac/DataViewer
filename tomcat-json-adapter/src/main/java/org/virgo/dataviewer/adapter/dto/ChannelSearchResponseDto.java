package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class ChannelSearchResponseDto {
    private List<ChannelSummaryDto> items = new ArrayList<ChannelSummaryDto>();
    private int total;
    private int limit;
    private int offset;

    public ChannelSearchResponseDto() {
    }

    public ChannelSearchResponseDto(List<ChannelSummaryDto> items, int total, int limit, int offset) {
        setItems(items);
        this.total = total;
        this.limit = limit;
        this.offset = offset;
    }

    public List<ChannelSummaryDto> getItems() {
        return new ArrayList<ChannelSummaryDto>(items);
    }

    public void setItems(List<ChannelSummaryDto> items) {
        this.items = new ArrayList<ChannelSummaryDto>(
                items == null ? Collections.<ChannelSummaryDto>emptyList() : items);
    }

    public int getTotal() {
        return total;
    }

    public void setTotal(int total) {
        this.total = total;
    }

    public int getLimit() {
        return limit;
    }

    public void setLimit(int limit) {
        this.limit = limit;
    }

    public int getOffset() {
        return offset;
    }

    public void setOffset(int offset) {
        this.offset = offset;
    }
}
