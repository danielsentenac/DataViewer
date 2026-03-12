package org.virgo.dataviewer.adapter.dto;

public class LiveDirectiveDto {
    private String mode;
    private int recommendedPollMs;
    private long resumeAfterUtcMs;

    public LiveDirectiveDto() {
    }

    public LiveDirectiveDto(String mode, int recommendedPollMs, long resumeAfterUtcMs) {
        this.mode = mode;
        this.recommendedPollMs = recommendedPollMs;
        this.resumeAfterUtcMs = resumeAfterUtcMs;
    }

    public String getMode() {
        return mode;
    }

    public void setMode(String mode) {
        this.mode = mode;
    }

    public int getRecommendedPollMs() {
        return recommendedPollMs;
    }

    public void setRecommendedPollMs(int recommendedPollMs) {
        this.recommendedPollMs = recommendedPollMs;
    }

    public long getResumeAfterUtcMs() {
        return resumeAfterUtcMs;
    }

    public void setResumeAfterUtcMs(long resumeAfterUtcMs) {
        this.resumeAfterUtcMs = resumeAfterUtcMs;
    }
}
