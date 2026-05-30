package com.cuiyue.media.exception;

public class BaseException extends RuntimeException {
    private final String errorMessage;

    public BaseException(String errorMessage) {
        this.errorMessage = errorMessage;
    }

    public String getErrorMessage() {
        return errorMessage;
    }
}
