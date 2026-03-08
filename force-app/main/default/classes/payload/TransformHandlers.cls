/**
 * TransformHandlers — built-in transformation implementations.
 */
public class TransformHandlers {

    public static Object formatDate(Object value, String paramsJson) {
        if (value == null) return null;
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(paramsJson);
        DateTime dt = (DateTime) value;
        String toFormat = (String) params.get('to');
        return dt.format(toFormat);
    }

    public static Object convertCurrency(Object value, String paramsJson) {
        if (value == null) return null;
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(paramsJson);
        Decimal amount = (Decimal) value;
        Decimal rate = (Decimal) params.get('rate');
        String target = (String) params.get('target');
        if (target == 'cents') {
            return (amount * rate * 100).setScale(0);
        }
        return (amount * rate).setScale(2);
    }

    public static Object mapValue(Object value, String paramsJson) {
        if (value == null) return null;
        Map<String, Object> valueMap = (Map<String, Object>) JSON.deserializeUntyped(paramsJson);
        String key = String.valueOf(value);
        return valueMap.containsKey(key) ? valueMap.get(key) : value;
    }

    public static Object concatenate(Object value, String paramsJson) {
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(paramsJson);
        String prefix = (String) params.get('prefix');
        String suffix = (String) params.get('suffix');
        String val = value != null ? String.valueOf(value) : '';
        return (prefix != null ? prefix : '') + val + (suffix != null ? suffix : '');
    }

    public static Object evaluateFormula(Object value, String paramsJson) {
        // Placeholder for formula evaluation
        return value;
    }

    public static Object executeCustom(Object value, String className) {
        Type t = Type.forName(className);
        ITransformHandler handler = (ITransformHandler) t.newInstance();
        return handler.transform(value);
    }
}
