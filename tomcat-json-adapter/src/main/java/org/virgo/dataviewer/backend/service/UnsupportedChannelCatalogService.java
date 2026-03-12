package org.virgo.dataviewer.backend.service;

import org.virgo.dataviewer.adapter.dto.ChannelCategoriesResponseDto;
import org.virgo.dataviewer.adapter.dto.ChannelSearchRequestDto;
import org.virgo.dataviewer.adapter.dto.ChannelSearchResponseDto;
import org.virgo.dataviewer.adapter.service.AdapterException;
import org.virgo.dataviewer.adapter.service.ChannelCatalogService;

public final class UnsupportedChannelCatalogService implements ChannelCatalogService {
    private static final String MESSAGE = "Channel catalog is not wired in this backend yet.";

    @Override
    public ChannelSearchResponseDto search(ChannelSearchRequestDto request) throws AdapterException {
        throw AdapterException.serviceUnavailable(MESSAGE);
    }

    @Override
    public ChannelCategoriesResponseDto categories() throws AdapterException {
        throw AdapterException.serviceUnavailable(MESSAGE);
    }
}
