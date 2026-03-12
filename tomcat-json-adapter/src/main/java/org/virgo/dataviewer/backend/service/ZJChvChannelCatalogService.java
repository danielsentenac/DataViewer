package org.virgo.dataviewer.backend.service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

import org.virgo.dataviewer.adapter.dto.ChannelCategoriesResponseDto;
import org.virgo.dataviewer.adapter.dto.ChannelCategoryDto;
import org.virgo.dataviewer.adapter.dto.ChannelSearchRequestDto;
import org.virgo.dataviewer.adapter.dto.ChannelSearchResponseDto;
import org.virgo.dataviewer.adapter.dto.ChannelSummaryDto;
import org.virgo.dataviewer.adapter.service.AdapterException;
import org.virgo.dataviewer.adapter.service.ChannelCatalogService;
import org.virgo.dataviewer.backend.live.ZJChvBuf;

public final class ZJChvChannelCatalogService implements ChannelCatalogService {
    private static final Comparator<ChannelSummaryDto> CHANNEL_COMPARATOR = new Comparator<ChannelSummaryDto>() {
        @Override
        public int compare(ChannelSummaryDto left, ChannelSummaryDto right) {
            return left.getName().compareToIgnoreCase(right.getName());
        }
    };

    private static final Comparator<ChannelCategoryDto> CATEGORY_COMPARATOR = new Comparator<ChannelCategoryDto>() {
        @Override
        public int compare(ChannelCategoryDto left, ChannelCategoryDto right) {
            return left.getId().compareToIgnoreCase(right.getId());
        }
    };

    private final ZJChvBuf liveBuffer;

    public ZJChvChannelCatalogService(ZJChvBuf liveBuffer) {
        this.liveBuffer = liveBuffer;
    }

    @Override
    public ChannelSearchResponseDto search(ChannelSearchRequestDto request) throws AdapterException {
        List<ChannelSummaryDto> catalog = loadCatalog();
        List<ChannelSummaryDto> filtered = new ArrayList<ChannelSummaryDto>();
        for (ChannelSummaryDto entry : catalog) {
            if (!matchesCategory(entry, request == null ? null : request.getCategory())) {
                continue;
            }
            if (!matchesQuery(entry, request == null ? null : request.getQuery())) {
                continue;
            }
            filtered.add(entry);
        }
        Collections.sort(filtered, CHANNEL_COMPARATOR);

        int total = filtered.size();
        int offset = Math.max(0, defaultOffset(request));
        int limit = Math.max(1, defaultLimit(request));
        int from = Math.min(offset, filtered.size());
        int to = Math.min(filtered.size(), from + limit);

        return new ChannelSearchResponseDto(new ArrayList<ChannelSummaryDto>(filtered.subList(from, to)), total, limit, offset);
    }

    @Override
    public ChannelCategoriesResponseDto categories() throws AdapterException {
        List<ChannelSummaryDto> catalog = loadCatalog();
        Map<String, Integer> counts = new LinkedHashMap<String, Integer>();
        for (ChannelSummaryDto item : catalog) {
            String category = item.getCategory();
            if (category == null || category.trim().isEmpty()) {
                continue;
            }
            Integer count = counts.get(category);
            counts.put(category, Integer.valueOf(count == null ? 1 : count.intValue() + 1));
        }
        List<ChannelCategoryDto> items = new ArrayList<ChannelCategoryDto>(counts.size());
        for (Map.Entry<String, Integer> entry : counts.entrySet()) {
            items.add(new ChannelCategoryDto(entry.getKey(), entry.getKey(), entry.getValue().intValue()));
        }
        Collections.sort(items, CATEGORY_COMPARATOR);
        return new ChannelCategoriesResponseDto(items);
    }

    private List<ChannelSummaryDto> loadCatalog() throws AdapterException {
        if (!liveBuffer.hasSource()) {
            throw AdapterException.serviceUnavailable("Live channel catalog is unavailable because zcmsubendpoint is not configured.");
        }
        List<ChannelSummaryDto> catalog = liveBuffer.snapshotCatalog();
        if (catalog.isEmpty()) {
            throw AdapterException.serviceUnavailable("Live channel catalog is empty. Wait for the first zJChv payload.");
        }
        return catalog;
    }

    private static boolean matchesCategory(ChannelSummaryDto entry, String category) {
        if (category == null || category.trim().isEmpty()) {
            return true;
        }
        return category.trim().equalsIgnoreCase(nullToEmpty(entry.getCategory()));
    }

    private static boolean matchesQuery(ChannelSummaryDto entry, String query) {
        if (query == null || query.trim().isEmpty()) {
            return true;
        }
        String q = query.trim();
        if (q.indexOf('*') >= 0 || q.indexOf('?') >= 0) {
            Pattern wildcard = wildcardPattern(q);
            return wildcard.matcher(entry.getName()).matches()
                    || wildcard.matcher(nullToEmpty(entry.getDisplayName())).matches();
        }
        String needle = q.toUpperCase(Locale.US);
        return entry.getName().toUpperCase(Locale.US).contains(needle)
                || nullToEmpty(entry.getDisplayName()).toUpperCase(Locale.US).contains(needle)
                || nullToEmpty(entry.getCategory()).toUpperCase(Locale.US).contains(needle);
    }

    private static Pattern wildcardPattern(String query) {
        StringBuilder regex = new StringBuilder("^");
        for (char ch : query.toCharArray()) {
            if (ch == '*') {
                regex.append(".*");
            } else if (ch == '?') {
                regex.append('.');
            } else if ("\\.[]{}()+-^$|".indexOf(ch) >= 0) {
                regex.append('\\').append(ch);
            } else {
                regex.append(ch);
            }
        }
        regex.append('$');
        return Pattern.compile(regex.toString(), Pattern.CASE_INSENSITIVE);
    }

    private static String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    private static int defaultLimit(ChannelSearchRequestDto request) {
        return request != null && request.getLimit() != null ? request.getLimit().intValue() : 100;
    }

    private static int defaultOffset(ChannelSearchRequestDto request) {
        return request != null && request.getOffset() != null ? request.getOffset().intValue() : 0;
    }
}
