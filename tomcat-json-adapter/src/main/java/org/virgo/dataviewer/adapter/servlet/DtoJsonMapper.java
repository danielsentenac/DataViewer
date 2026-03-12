package org.virgo.dataviewer.adapter.servlet;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.virgo.dataviewer.adapter.dto.ApiErrorDto;
import org.virgo.dataviewer.adapter.dto.BucketedPlotSeriesDto;
import org.virgo.dataviewer.adapter.dto.ChannelCategoriesResponseDto;
import org.virgo.dataviewer.adapter.dto.ChannelCategoryDto;
import org.virgo.dataviewer.adapter.dto.ChannelSearchRequestDto;
import org.virgo.dataviewer.adapter.dto.ChannelSearchResponseDto;
import org.virgo.dataviewer.adapter.dto.ChannelSummaryDto;
import org.virgo.dataviewer.adapter.dto.ErrorResponseDto;
import org.virgo.dataviewer.adapter.dto.LiveDirectiveDto;
import org.virgo.dataviewer.adapter.dto.LivePlotRequestDto;
import org.virgo.dataviewer.adapter.dto.LivePlotResponseDto;
import org.virgo.dataviewer.adapter.dto.LivePlotSeriesDto;
import org.virgo.dataviewer.adapter.dto.PlotQueryMetadataDto;
import org.virgo.dataviewer.adapter.dto.PlotQueryRequestDto;
import org.virgo.dataviewer.adapter.dto.PlotQueryResponseDto;
import org.virgo.dataviewer.adapter.dto.PlotSeriesDto;
import org.virgo.dataviewer.adapter.dto.RawPlotSeriesDto;
import org.virgo.dataviewer.adapter.dto.SamplingRequestDto;
import org.virgo.dataviewer.adapter.dto.TimeRangeRequestDto;
import org.virgo.dataviewer.adapter.service.AdapterException;

public final class DtoJsonMapper {
    private DtoJsonMapper() {
    }

    public static ChannelSearchRequestDto channelSearchRequest(
            String query,
            String category,
            String limit,
            String offset) throws AdapterException {
        return new ChannelSearchRequestDto(
                query == null ? "" : query,
                category,
                parseInteger(limit, "limit"),
                parseInteger(offset, "offset"));
    }

    public static PlotQueryRequestDto plotQueryRequest(Map<String, Object> root) throws AdapterException {
        Map<String, Object> timeRange = map(root.get("timeRange"), "timeRange");
        Map<String, Object> sampling = map(root.get("sampling"), "sampling");

        return new PlotQueryRequestDto(
                stringList(root.get("channels"), "channels"),
                new TimeRangeRequestDto(
                        requiredString(timeRange.get("startLocalIso"), "timeRange.startLocalIso"),
                        requiredString(timeRange.get("timeZone"), "timeRange.timeZone")),
                new SamplingRequestDto(
                        integer(sampling.get("targetBuckets"), "sampling.targetBuckets"),
                        booleanValue(sampling.get("preserveExtrema"), "sampling.preserveExtrema", true)));
    }

    public static LivePlotRequestDto livePlotRequest(Map<String, Object> root) throws AdapterException {
        return new LivePlotRequestDto(
                stringList(root.get("channels"), "channels"),
                requiredLong(root.get("afterUtcMs"), "afterUtcMs"));
    }

    public static Map<String, Object> channelSearchResponse(ChannelSearchResponseDto dto) {
        Map<String, Object> root = new LinkedHashMap<String, Object>();
        List<Object> items = new ArrayList<Object>();
        for (ChannelSummaryDto item : dto.getItems()) {
            Map<String, Object> channel = new LinkedHashMap<String, Object>();
            channel.put("name", item.getName());
            channel.put("displayName", item.getDisplayName());
            channel.put("unit", item.getUnit());
            channel.put("category", item.getCategory());
            channel.put("sampleRateHz", item.getSampleRateHz());
            items.add(channel);
        }
        root.put("items", items);
        root.put("total", dto.getTotal());
        root.put("limit", dto.getLimit());
        root.put("offset", dto.getOffset());
        return root;
    }

    public static Map<String, Object> channelCategoriesResponse(ChannelCategoriesResponseDto dto) {
        Map<String, Object> root = new LinkedHashMap<String, Object>();
        List<Object> items = new ArrayList<Object>();
        for (ChannelCategoryDto item : dto.getItems()) {
            Map<String, Object> category = new LinkedHashMap<String, Object>();
            category.put("id", item.getId());
            category.put("label", item.getLabel());
            category.put("count", item.getCount());
            items.add(category);
        }
        root.put("items", items);
        return root;
    }

    public static Map<String, Object> plotQueryResponse(PlotQueryResponseDto dto) {
        Map<String, Object> root = new LinkedHashMap<String, Object>();
        root.put("query", plotQueryMetadata(dto.getQuery()));

        List<Object> series = new ArrayList<Object>();
        for (PlotSeriesDto item : dto.getSeries()) {
            series.add(plotSeries(item));
        }
        root.put("series", series);
        root.put("live", liveDirective(dto.getLive()));
        return root;
    }

    public static Map<String, Object> livePlotResponse(LivePlotResponseDto dto) {
        Map<String, Object> root = new LinkedHashMap<String, Object>();
        root.put("serverNowUtcMs", dto.getServerNowUtcMs());

        List<Object> series = new ArrayList<Object>();
        for (LivePlotSeriesDto item : dto.getSeries()) {
            Map<String, Object> channel = new LinkedHashMap<String, Object>();
            channel.put("channel", item.getChannel());
            channel.put("startUtcMs", item.getStartUtcMs());
            channel.put("stepMs", item.getStepMs());
            channel.put("values", item.getValues());
            series.add(channel);
        }
        root.put("series", series);
        return root;
    }

    public static Map<String, Object> errorResponse(AdapterException exception) {
        return errorResponse(new ErrorResponseDto(
                new ApiErrorDto(exception.getErrorCode(), exception.getMessage(), exception.getDetails())));
    }

    public static Map<String, Object> errorResponse(ErrorResponseDto dto) {
        Map<String, Object> root = new LinkedHashMap<String, Object>();
        Map<String, Object> error = new LinkedHashMap<String, Object>();
        error.put("code", dto.getError().getCode());
        error.put("message", dto.getError().getMessage());
        error.put("details", dto.getError().getDetails());
        root.put("error", error);
        return root;
    }

    private static Map<String, Object> plotQueryMetadata(PlotQueryMetadataDto dto) {
        Map<String, Object> query = new LinkedHashMap<String, Object>();
        query.put("channelCount", dto.getChannelCount());
        query.put("resolvedStartUtcMs", dto.getResolvedStartUtcMs());
        query.put("resolvedStartGps", dto.getResolvedStartGps());
        query.put("endUtcMs", dto.getEndUtcMs());
        return query;
    }

    private static Map<String, Object> liveDirective(LiveDirectiveDto dto) {
        Map<String, Object> live = new LinkedHashMap<String, Object>();
        live.put("mode", dto.getMode());
        live.put("recommendedPollMs", dto.getRecommendedPollMs());
        live.put("resumeAfterUtcMs", dto.getResumeAfterUtcMs());
        return live;
    }

    private static Map<String, Object> plotSeries(PlotSeriesDto dto) {
        Map<String, Object> series = new LinkedHashMap<String, Object>();
        series.put("channel", dto.getChannel());
        series.put("displayName", dto.getDisplayName());
        series.put("unit", dto.getUnit());
        series.put("samplingMode", dto.getSamplingMode().getWireValue());

        if (dto instanceof RawPlotSeriesDto) {
            RawPlotSeriesDto raw = (RawPlotSeriesDto) dto;
            series.put("startUtcMs", raw.getStartUtcMs());
            series.put("stepMs", raw.getStepMs());
            series.put("values", raw.getValues());
        } else if (dto instanceof BucketedPlotSeriesDto) {
            BucketedPlotSeriesDto bucketed = (BucketedPlotSeriesDto) dto;
            series.put("startUtcMs", bucketed.getStartUtcMs());
            series.put("bucketSeconds", bucketed.getBucketSeconds());
            series.put("minValues", bucketed.getMinValues());
            series.put("maxValues", bucketed.getMaxValues());
        }

        return series;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> map(Object value, String field) throws AdapterException {
        if (value instanceof Map) {
            return (Map<String, Object>) value;
        }
        throw AdapterException.badRequest("INVALID_PAYLOAD", "Expected JSON object at `" + field + "`.");
    }

    @SuppressWarnings("unchecked")
    private static List<String> stringList(Object value, String field) throws AdapterException {
        if (!(value instanceof List)) {
            throw AdapterException.badRequest("INVALID_PAYLOAD", "Expected array at `" + field + "`.");
        }

        List<String> result = new ArrayList<String>();
        for (Object item : (List<Object>) value) {
            if (!(item instanceof String)) {
                throw AdapterException.badRequest(
                        "INVALID_PAYLOAD",
                        "Expected string array at `" + field + "`.",
                        Arrays.asList(String.valueOf(item)));
            }
            result.add((String) item);
        }
        return result;
    }

    private static String requiredString(Object value, String field) throws AdapterException {
        if (value instanceof String && !((String) value).trim().isEmpty()) {
            return (String) value;
        }
        throw AdapterException.badRequest("INVALID_PAYLOAD", "Expected non-empty string at `" + field + "`.");
    }

    private static Integer parseInteger(String value, String field) throws AdapterException {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        try {
            return Integer.valueOf(value);
        } catch (NumberFormatException exception) {
            throw AdapterException.badRequest("INVALID_QUERY", "Expected integer query parameter `" + field + "`.");
        }
    }

    private static Integer integer(Object value, String field) throws AdapterException {
        if (value == null) {
            return null;
        }
        if (value instanceof Number) {
            return Integer.valueOf(((Number) value).intValue());
        }
        throw AdapterException.badRequest("INVALID_PAYLOAD", "Expected integer at `" + field + "`.");
    }

    private static long requiredLong(Object value, String field) throws AdapterException {
        if (value instanceof Number) {
            return ((Number) value).longValue();
        }
        throw AdapterException.badRequest("INVALID_PAYLOAD", "Expected integer at `" + field + "`.");
    }

    private static boolean booleanValue(Object value, String field, boolean defaultValue) throws AdapterException {
        if (value == null) {
            return defaultValue;
        }
        if (value instanceof Boolean) {
            return ((Boolean) value).booleanValue();
        }
        throw AdapterException.badRequest("INVALID_PAYLOAD", "Expected boolean at `" + field + "`.");
    }
}
