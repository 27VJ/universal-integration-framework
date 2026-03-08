/**
 * RetryQueueSchedulable — scheduled job to process the retry queue.
 * Schedule: System.schedule('IntegrationRetry', '0 0/5 * * * ?', new RetryQueueSchedulable());
 */
public class RetryQueueSchedulable implements Schedulable {

    public void execute(SchedulableContext sc) {
        new RetryManager().processRetryQueue();
    }
}
