package org.virgo.dataviewer.backend.service;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
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
import org.virgo.dataviewer.adapter.json.JsonCodec;
import org.virgo.dataviewer.adapter.json.NashornJsonCodec;
import org.virgo.dataviewer.adapter.service.AdapterException;
import org.virgo.dataviewer.adapter.service.ChannelCatalogService;
import org.virgo.dataviewer.backend.config.BackendConfig;

public final class HttpChannelCatalogService implements ChannelCatalogService {
    private static final Comparator<CatalogEntry> CATALOG_ENTRY_COMPARATOR = new Comparator<CatalogEntry>() {
        @Override
        public int compare(CatalogEntry left, CatalogEntry right) {
            return left.getName().compareToIgnoreCase(right.getName());
        }
    };

    private static final Comparator<ChannelCategoryDto> CATEGORY_COMPARATOR = new Comparator<ChannelCategoryDto>() {
        @Override
        public int compare(ChannelCategoryDto left, ChannelCategoryDto right) {
            return left.getId().compareToIgnoreCase(right.getId());
        }
    };

    private final String searchUrl;
    private final String categoriesUrl;
    private final String listUrl;
    private final int timeoutMs;
    private final long cacheTtlMs;
    private final JsonCodec jsonCodec = new NashornJsonCodec();

    private volatile CachedCatalog cachedCatalog;

    public HttpChannelCatalogService(BackendConfig config) {
        this.searchUrl = config.getChannelCatalogSearchUrl();
        this.categoriesUrl = config.getChannelCatalogCategoriesUrl();
        this.listUrl = config.getChannelCatalogListUrl();
        this.timeoutMs = config.getChannelCatalogTimeoutMs();
        this.cacheTtlMs = Math.max(0L, config.getChannelCatalogCacheSeconds()) * 1000L;
    }

    @Override
    public ChannelSearchResponseDto search(ChannelSearchRequestDto request) throws AdapterException {
        if (searchUrl != null) {
            try {
                return fetchSearchFromUpstream(request);
            } catch (AdapterException exception) {
                if (listUrl == null) {
                    throw exception;
                }
            }
        }
        if (listUrl != null) {
            return searchInCatalog(request, loadCatalogEntries());
        }
        throw unavailable("search");
    }

    @Override
    public ChannelCategoriesResponseDto categories() throws AdapterException {
        if (categoriesUrl != null) {
            try {
                return fetchCategoriesFromUpstream();
            } catch (AdapterException exception) {
                if (listUrl == null) {
                    throw exception;
                }
            }
        }
        if (listUrl != null) {
            return categoriesFromCatalog(loadCatalogEntries());
        }
        throw unavailable("categories");
    }

    private ChannelSearchResponseDto fetchSearchFromUpstream(ChannelSearchRequestDto request) throws AdapterException {
        String url = buildUrl(searchUrl,
                queryParam("q", request == null ? "" : nullToEmpty(request.getQuery())),
                queryParam("category", request == null ? null : request.getCategory()),
                queryParam("limit", request != null && request.getLimit() != null ? Integer.toString(request.getLimit().intValue()) : null),
                queryParam("offset", request != null && request.getOffset() != null ? Integer.toString(request.getOffset().intValue()) : null));
        UpstreamPayload payload = fetch(url);
        if (payload.json instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> root = (Map<String, Object>) payload.json;
            Object itemsValue = root.get("items");
            if (itemsValue != null) {
                List<CatalogEntry> items = parseCatalogEntries(itemsValue);
                int limit = integerOrDefault(root.get("limit"), defaultLimit(request));
                int offset = integerOrDefault(root.get("offset"), defaultOffset(request));
                int total = integerOrDefault(root.get("total"), items.size());
                return toSearchResponse(items, total, limit, offset);
            }
        }

        List<CatalogEntry> items = parseCatalogEntries(payload.json != null ? payload.json : payload.text);
        ChannelSearchResponseDto dto = searchInCatalog(request, items);
        return new ChannelSearchResponseDto(dto.getItems(), dto.getTotal(), defaultLimit(request), defaultOffset(request));
    }

    private ChannelCategoriesResponseDto fetchCategoriesFromUpstream() throws AdapterException {
        UpstreamPayload payload = fetch(categoriesUrl);
        if (payload.json instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> root = (Map<String, Object>) payload.json;
            Object itemsValue = root.get("items");
            if (itemsValue != null) {
                return new ChannelCategoriesResponseDto(parseCategories(itemsValue));
            }
        }
        return new ChannelCategoriesResponseDto(parseCategories(payload.json != null ? payload.json : payload.text));
    }

    private List<CatalogEntry> loadCatalogEntries() throws AdapterException {
        long now = System.currentTimeMillis();
        CachedCatalog cached = cachedCatalog;
        if (cached != null && now < cached.expiresAtMs) {
            return cached.entries;
        }
        synchronized (this) {
            cached = cachedCatalog;
            if (cached != null && now < cached.expiresAtMs) {
                return cached.entries;
            }
            UpstreamPayload payload = fetch(listUrl);
            List<CatalogEntry> entries = Collections.unmodifiableList(parseCatalogEntries(payload.json != null ? payload.json : payload.text));
            cachedCatalog = new CachedCatalog(entries, now + cacheTtlMs);
            return entries;
        }
    }

    private ChannelSearchResponseDto searchInCatalog(ChannelSearchRequestDto request, List<CatalogEntry> entries) {
        List<CatalogEntry> filtered = new ArrayList<CatalogEntry>();
        for (CatalogEntry entry : entries) {
            if (!matchesCategory(entry, request == null ? null : request.getCategory())) {
                continue;
            }
            if (!matchesQuery(entry, request == null ? null : request.getQuery())) {
                continue;
            }
            filtered.add(entry);
        }
        Collections.sort(filtered, CATALOG_ENTRY_COMPARATOR);

        int total = filtered.size();
        int offset = Math.max(0, defaultOffset(request));
        int limit = Math.max(1, defaultLimit(request));
        int from = Math.min(offset, filtered.size());
        int to = Math.min(filtered.size(), from + limit);

        List<ChannelSummaryDto> items = new ArrayList<ChannelSummaryDto>(to - from);
        for (CatalogEntry entry : filtered.subList(from, to)) {
            items.add(entry.toDto());
        }
        return new ChannelSearchResponseDto(items, total, limit, offset);
    }

    private ChannelCategoriesResponseDto categoriesFromCatalog(List<CatalogEntry> entries) {
        Map<String, Integer> counts = new LinkedHashMap<String, Integer>();
        for (CatalogEntry entry : entries) {
            String category = entry.getCategory();
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

    private UpstreamPayload fetch(String targetUrl) throws AdapterException {
        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) new URL(targetUrl).openConnection();
            connection.setConnectTimeout(timeoutMs);
            connection.setReadTimeout(timeoutMs);
            connection.setUseCaches(false);
            connection.setRequestMethod("GET");
            connection.setRequestProperty("Accept", "application/json, text/plain;q=0.9, */*;q=0.1");
            connection.connect();

            int status = connection.getResponseCode();
            byte[] body = readAllBytes(status >= 400 ? connection.getErrorStream() : connection.getInputStream());
            if (status >= 400) {
                throw AdapterException.serviceUnavailable(
                        "Upstream channel catalog request failed with HTTP " + status + " for " + targetUrl + ".");
            }
            Object json = null;
            if (body.length > 0) {
                try {
                    json = jsonCodec.read(new ByteArrayInputStream(body));
                } catch (Exception exception) {
                    json = null;
                }
            }
            return new UpstreamPayload(new String(body, StandardCharsets.UTF_8), json);
        } catch (IOException exception) {
            throw AdapterException.serviceUnavailable("Unable to reach upstream channel catalog: " + exception.getMessage());
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private List<CatalogEntry> parseCatalogEntries(Object payload) throws AdapterException {
        List<CatalogEntry> items = new ArrayList<CatalogEntry>();
        if (payload == null) {
            return items;
        }
        if (payload instanceof List) {
            @SuppressWarnings("unchecked")
            List<Object> list = (List<Object>) payload;
            for (Object item : list) {
                CatalogEntry entry = toCatalogEntry(item);
                if (entry != null) {
                    items.add(entry);
                }
            }
            return deduplicate(items);
        }
        if (payload instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> map = (Map<String, Object>) payload;
            Object itemsValue = map.get("items");
            if (itemsValue != null) {
                return parseCatalogEntries(itemsValue);
            }
            CatalogEntry entry = toCatalogEntry(map);
            if (entry != null) {
                items.add(entry);
            }
            return items;
        }
        if (payload instanceof String) {
            String[] lines = ((String) payload).split("\\r?\\n");
            for (String line : lines) {
                CatalogEntry entry = toCatalogEntry(line);
                if (entry != null) {
                    items.add(entry);
                }
            }
            return deduplicate(items);
        }
        throw AdapterException.serviceUnavailable("Unsupported upstream channel catalog payload.");
    }

    private List<ChannelCategoryDto> parseCategories(Object payload) throws AdapterException {
        List<ChannelCategoryDto> items = new ArrayList<ChannelCategoryDto>();
        if (payload == null) {
            return items;
        }
        if (payload instanceof List) {
            @SuppressWarnings("unchecked")
            List<Object> list = (List<Object>) payload;
            for (Object item : list) {
                ChannelCategoryDto category = toCategory(item);
                if (category != null) {
                    items.add(category);
                }
            }
            return items;
        }
        if (payload instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> map = (Map<String, Object>) payload;
            Object itemsValue = map.get("items");
            if (itemsValue != null) {
                return parseCategories(itemsValue);
            }
            ChannelCategoryDto category = toCategory(map);
            if (category != null) {
                items.add(category);
            }
            return items;
        }
        if (payload instanceof String) {
            String[] lines = ((String) payload).split("\\r?\\n");
            for (String line : lines) {
                ChannelCategoryDto category = toCategory(line);
                if (category != null) {
                    items.add(category);
                }
            }
            return items;
        }
        throw AdapterException.serviceUnavailable("Unsupported upstream channel category payload.");
    }

    private ChannelSearchResponseDto toSearchResponse(List<CatalogEntry> items, int total, int limit, int offset) {
        List<ChannelSummaryDto> out = new ArrayList<ChannelSummaryDto>(items.size());
        for (CatalogEntry entry : items) {
            out.add(entry.toDto());
        }
        return new ChannelSearchResponseDto(out, total, limit, offset);
    }

    private boolean matchesCategory(CatalogEntry entry, String category) {
        if (category == null || category.trim().isEmpty()) {
            return true;
        }
        return category.trim().equalsIgnoreCase(nullToEmpty(entry.getCategory()));
    }

    private boolean matchesQuery(CatalogEntry entry, String query) {
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

    private static CatalogEntry toCatalogEntry(Object raw) {
        if (raw == null) {
            return null;
        }
        if (raw instanceof String) {
            String text = ((String) raw).trim();
            if (text.isEmpty()) {
                return null;
            }
            String[] parts = text.split("\\|");
            String name = parts[0].trim();
            String displayName = parts.length > 1 && !parts[1].trim().isEmpty() ? parts[1].trim() : deriveDisplayName(name);
            String unit = parts.length > 2 && !parts[2].trim().isEmpty() ? parts[2].trim() : null;
            String category = parts.length > 3 && !parts[3].trim().isEmpty() ? parts[3].trim().toUpperCase(Locale.US)
                    : deriveCategory(name);
            int sampleRateHz = parts.length > 4 ? parseInt(parts[4].trim(), 1) : 1;
            return new CatalogEntry(name, displayName, unit, category, sampleRateHz);
        }
        if (raw instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> map = (Map<String, Object>) raw;
            String name = stringValue(map, "name", "channel", "id");
            if (name == null || name.trim().isEmpty()) {
                return null;
            }
            String displayName = firstNonEmpty(stringValue(map, "displayName", "label", "description"), deriveDisplayName(name));
            String unit = stringValue(map, "unit");
            String category = firstNonEmpty(stringValue(map, "category", "subsystem"), deriveCategory(name));
            int sampleRateHz = integerOrDefault(firstNonNull(map.get("sampleRateHz"), map.get("sampleRate"), map.get("rateHz")), 1);
            return new CatalogEntry(name.trim(), displayName, unit, category == null ? null : category.toUpperCase(Locale.US),
                    sampleRateHz);
        }
        return null;
    }

    private static ChannelCategoryDto toCategory(Object raw) {
        if (raw == null) {
            return null;
        }
        if (raw instanceof String) {
            String text = ((String) raw).trim();
            if (text.isEmpty()) {
                return null;
            }
            String[] parts = text.split("\\|");
            String id = parts[0].trim();
            String label = parts.length > 1 && !parts[1].trim().isEmpty() ? parts[1].trim() : id;
            int count = parts.length > 2 ? parseInt(parts[2].trim(), 0) : 0;
            return new ChannelCategoryDto(id, label, count);
        }
        if (raw instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> map = (Map<String, Object>) raw;
            String id = firstNonEmpty(stringValue(map, "id", "category"), stringValue(map, "label"));
            if (id == null || id.trim().isEmpty()) {
                return null;
            }
            String label = firstNonEmpty(stringValue(map, "label", "displayName"), id);
            int count = integerOrDefault(map.get("count"), 0);
            return new ChannelCategoryDto(id.trim(), label, count);
        }
        return null;
    }

    private static List<CatalogEntry> deduplicate(List<CatalogEntry> items) {
        Map<String, CatalogEntry> unique = new LinkedHashMap<String, CatalogEntry>();
        for (CatalogEntry item : items) {
            unique.put(item.getName(), item);
        }
        return new ArrayList<CatalogEntry>(unique.values());
    }

    private static String deriveDisplayName(String channelName) {
        if (channelName == null) {
            return null;
        }
        String base = stripVersionPrefix(channelName);
        int colon = base.indexOf(':');
        if (colon >= 0 && colon + 1 < base.length()) {
            base = base.substring(colon + 1);
        }
        return base.replace('_', ' ').trim();
    }

    private static String deriveCategory(String channelName) {
        String base = stripVersionPrefix(channelName);
        int colon = base.indexOf(':');
        if (colon >= 0 && colon + 1 < base.length()) {
            base = base.substring(colon + 1);
        }
        String[] tokens = base.split("[-_]");
        if (tokens.length >= 2 && !tokens[1].trim().isEmpty()) {
            return tokens[1].trim().toUpperCase(Locale.US);
        }
        if (tokens.length >= 1 && !tokens[0].trim().isEmpty()) {
            return tokens[0].trim().toUpperCase(Locale.US);
        }
        return null;
    }

    private static String stripVersionPrefix(String key) {
        if (key == null) {
            return "";
        }
        String trimmed = key.trim();
        int separator = trimmed.indexOf(':');
        if (separator > 1 && separator < trimmed.length() - 1
                && (trimmed.charAt(0) == 'V' || trimmed.charAt(0) == 'v')) {
            boolean digits = true;
            for (int i = 1; i < separator; i++) {
                char ch = trimmed.charAt(i);
                if (ch < '0' || ch > '9') {
                    digits = false;
                    break;
                }
            }
            if (digits) {
                return trimmed.substring(separator + 1).trim();
            }
        }
        return trimmed;
    }

    private static byte[] readAllBytes(InputStream inputStream) throws IOException {
        if (inputStream == null) {
            return new byte[0];
        }
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        byte[] chunk = new byte[4096];
        int read;
        while ((read = inputStream.read(chunk)) >= 0) {
            if (read == 0) {
                continue;
            }
            buffer.write(chunk, 0, read);
        }
        return buffer.toByteArray();
    }

    private static AdapterException unavailable(String capability) {
        return AdapterException.serviceUnavailable(
                "Channel catalog " + capability + " is not configured. Set virgo.channel.catalog.search.url, "
                        + "virgo.channel.catalog.categories.url, or virgo.channel.catalog.list.url.");
    }

    private static String buildUrl(String baseUrl, QueryParam... params) throws AdapterException {
        StringBuilder builder = new StringBuilder(baseUrl);
        boolean hasQuery = baseUrl.indexOf('?') >= 0;
        for (QueryParam param : params) {
            if (param == null || param.value == null) {
                continue;
            }
            builder.append(hasQuery ? '&' : '?');
            builder.append(urlEncode(param.name));
            builder.append('=');
            builder.append(urlEncode(param.value));
            hasQuery = true;
        }
        return builder.toString();
    }

    private static QueryParam queryParam(String name, String value) {
        return new QueryParam(name, value);
    }

    private static String urlEncode(String value) throws AdapterException {
        try {
            return URLEncoder.encode(value, "UTF-8");
        } catch (Exception exception) {
            throw AdapterException.badRequest("INVALID_QUERY", "Invalid query parameter value.");
        }
    }

    private static String nullToEmpty(String value) {
        return value == null ? "" : value;
    }

    private static String firstNonEmpty(String primary, String fallback) {
        return primary == null || primary.trim().isEmpty() ? fallback : primary;
    }

    private static Object firstNonNull(Object... values) {
        for (Object value : values) {
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private static String stringValue(Map<String, Object> map, String... keys) {
        for (String key : keys) {
            Object value = map.get(key);
            if (value instanceof String && !((String) value).trim().isEmpty()) {
                return ((String) value).trim();
            }
        }
        return null;
    }

    private static int integerOrDefault(Object value, int fallback) {
        if (value instanceof Number) {
            return ((Number) value).intValue();
        }
        if (value instanceof String && !((String) value).trim().isEmpty()) {
            return parseInt(((String) value).trim(), fallback);
        }
        return fallback;
    }

    private static int parseInt(String text, int fallback) {
        try {
            return Integer.parseInt(text);
        } catch (NumberFormatException exception) {
            return fallback;
        }
    }

    private static int defaultLimit(ChannelSearchRequestDto request) {
        return request != null && request.getLimit() != null ? request.getLimit().intValue() : 100;
    }

    private static int defaultOffset(ChannelSearchRequestDto request) {
        return request != null && request.getOffset() != null ? request.getOffset().intValue() : 0;
    }

    private static final class QueryParam {
        private final String name;
        private final String value;

        private QueryParam(String name, String value) {
            this.name = name;
            this.value = value;
        }
    }

    private static final class CachedCatalog {
        private final List<CatalogEntry> entries;
        private final long expiresAtMs;

        private CachedCatalog(List<CatalogEntry> entries, long expiresAtMs) {
            this.entries = entries;
            this.expiresAtMs = expiresAtMs;
        }
    }

    private static final class UpstreamPayload {
        private final String text;
        private final Object json;

        private UpstreamPayload(String text, Object json) {
            this.text = text;
            this.json = json;
        }
    }

    private static final class CatalogEntry {
        private final String name;
        private final String displayName;
        private final String unit;
        private final String category;
        private final int sampleRateHz;

        private CatalogEntry(String name, String displayName, String unit, String category, int sampleRateHz) {
            this.name = name;
            this.displayName = displayName;
            this.unit = unit;
            this.category = category;
            this.sampleRateHz = sampleRateHz <= 0 ? 1 : sampleRateHz;
        }

        private String getName() {
            return name;
        }

        private String getDisplayName() {
            return displayName;
        }

        private String getCategory() {
            return category;
        }

        private ChannelSummaryDto toDto() {
            return new ChannelSummaryDto(name, displayName, unit, category, sampleRateHz);
        }
    }
}
