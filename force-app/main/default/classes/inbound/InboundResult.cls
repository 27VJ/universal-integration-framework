/**
 * InboundResult — return value from inbound webhook processing.
 */
public class InboundResult {
    public Boolean isSuccess;
    public List<String> errors;
    public Id recordId;
    public Integer recordCount;
}
