package org.virgo.dataviewer.adapter.dto;

public class SamplingRequestDto {
    private Integer targetBuckets;
    private boolean preserveExtrema;

    public SamplingRequestDto() {
    }

    public SamplingRequestDto(Integer targetBuckets, boolean preserveExtrema) {
        this.targetBuckets = targetBuckets;
        this.preserveExtrema = preserveExtrema;
    }

    public Integer getTargetBuckets() {
        return targetBuckets;
    }

    public void setTargetBuckets(Integer targetBuckets) {
        this.targetBuckets = targetBuckets;
    }

    public boolean isPreserveExtrema() {
        return preserveExtrema;
    }

    public void setPreserveExtrema(boolean preserveExtrema) {
        this.preserveExtrema = preserveExtrema;
    }
}
