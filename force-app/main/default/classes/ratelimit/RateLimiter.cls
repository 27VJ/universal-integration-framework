/**
 * RateLimiter — prevents exceeding external API rate limits using Platform Cache.
 * Requires a Platform Cache partition named "Integration" with >= 1 MB Org cache.
 */
public with sharing class RateLimiter {

    public static Boolean canProceed(String configName) {
        Integer count = (Integer) Cache.Org.get('local.Integration.' + configName + '_count');
        // Rate limit can be configured as a custom field on Integration_Config__mdt if needed
        return count == null || count < 1000; // default 1000 calls/minute
    }

    public static void recordCall(String configName) {
        String key = 'local.Integration.' + configName + '_count';
        Integer count = (Integer) Cache.Org.get(key);
        Cache.Org.put(key, (count != null ? count + 1 : 1), 60);
    }
}
