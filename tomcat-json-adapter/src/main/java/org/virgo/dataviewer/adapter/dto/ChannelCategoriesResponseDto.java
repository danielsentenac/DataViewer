package org.virgo.dataviewer.adapter.dto;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class ChannelCategoriesResponseDto {
    private List<ChannelCategoryDto> items = new ArrayList<ChannelCategoryDto>();

    public ChannelCategoriesResponseDto() {
    }

    public ChannelCategoriesResponseDto(List<ChannelCategoryDto> items) {
        setItems(items);
    }

    public List<ChannelCategoryDto> getItems() {
        return new ArrayList<ChannelCategoryDto>(items);
    }

    public void setItems(List<ChannelCategoryDto> items) {
        this.items = new ArrayList<ChannelCategoryDto>(
                items == null ? Collections.<ChannelCategoryDto>emptyList() : items);
    }
}
