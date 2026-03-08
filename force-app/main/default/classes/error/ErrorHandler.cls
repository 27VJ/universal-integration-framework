/**
 * ErrorHandler — handles integration failures and determines retryability.
 */
public with sharing class ErrorHandler {

    private static final Set<Integer> RETRYABLE_CODES =
        new Set<Integer>{ 408, 429, 500, 502, 503, 504 };

    public void handle(IntegrationContext ctx, Exception ex) {
        IntegrationLogger.logError(ctx, ex);
        if (ctx.httpStatusCode != null && isRetryable(ctx.httpStatusCode)) {
            new RetryManager().scheduleRetry(ctx);
        }
    }

    public static Boolean isRetryable(Integer statusCode) {
        return RETRYABLE_CODES.contains(statusCode);
    }
}
