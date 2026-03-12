package org.virgo.dataviewer.adapter.service;

import org.virgo.dataviewer.adapter.dto.ChannelCategoriesResponseDto;
import org.virgo.dataviewer.adapter.dto.ChannelSearchRequestDto;
import org.virgo.dataviewer.adapter.dto.ChannelSearchResponseDto;

public interface ChannelCatalogService {
    ChannelSearchResponseDto search(ChannelSearchRequestDto request) throws AdapterException;

    ChannelCategoriesResponseDto categories() throws AdapterException;
}
