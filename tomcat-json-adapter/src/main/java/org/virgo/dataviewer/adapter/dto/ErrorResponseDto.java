package org.virgo.dataviewer.adapter.dto;

public class ErrorResponseDto {
    private ApiErrorDto error;

    public ErrorResponseDto() {
    }

    public ErrorResponseDto(ApiErrorDto error) {
        this.error = error;
    }

    public ApiErrorDto getError() {
        return error;
    }

    public void setError(ApiErrorDto error) {
        this.error = error;
    }
}
