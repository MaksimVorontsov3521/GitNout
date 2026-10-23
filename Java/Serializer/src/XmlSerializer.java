import java.util.Map;

public class XmlSerializer implements Serializer {

    private static final int MAX_DEPTH = 32;

    @Override public String serialize(Object[] objs) { return serializeArray(objs, 0); }
    @Override public String serialize(Map<?, ?> map) { return serializeMap(map, 0); }

    @Override
    public String serialize(Object obj) {
        if (obj == null)                            return "<null/>";
        if (obj instanceof Object[] array)          return serializeArray(array, 0);
        if (obj instanceof Iterable<?> iterable)    return serializeIterable(iterable, 0);
        if (obj instanceof Map<?, ?> map)           return serializeMap(map, 0);
        return serializeObj(obj, 0);
    }

    private String serializeObj(Object obj, int depth) {
        checkDepth(depth);
        String name = obj.getClass().getSimpleName();
        StringBuilder sb = new StringBuilder("<").append(name).append(">");
        for (Map.Entry<String, Object> variable : Getter.getProperties(obj).entrySet()) {
            sb.append("<").append(variable.getKey()).append(">")
                    .append(serializeValue(variable.getValue(), depth + 1))
                    .append("</").append(variable.getKey()).append(">");
        }
        return sb.append("</").append(name).append(">").toString();
    }

    private String serializeArray(Object[] objs, int depth) {
        checkDepth(depth);
        String name = objs.getClass().getSimpleName();
        StringBuilder sb = new StringBuilder("<").append(name).append(">");
        for (Object obj : objs) {
            sb.append(serializeValue(obj, depth + 1));
        }
        return sb.append("</").append(name).append(">").toString();
    }

    private String serializeIterable(Iterable<?> iterable, int depth) {
        checkDepth(depth);
        String name = iterable.getClass().getSimpleName();
        StringBuilder sb = new StringBuilder("<").append(name).append(">");
        for (Object obj : iterable) {
            sb.append(serializeValue(obj, depth + 1));
        }
        return sb.append("</").append(name).append(">").toString();
    }

    private String serializeMap(Map<?, ?> map, int depth) {
        checkDepth(depth);
        String name = map.getClass().getSimpleName();
        StringBuilder sb = new StringBuilder("<").append(name).append(">");
        for (Object value : map.values()) {
            sb.append(serializeValue(value, depth + 1));
        }
        return sb.append("</").append(name).append(">").toString();
    }

    private String serializeValue(Object value, int depth) {
        checkDepth(depth);
        if (value == null)                                          return "";
        if (value instanceof Number || value instanceof Boolean)    return value.toString();
        if (value instanceof Enum<?> e)                             return escape(e.name());
        if (value instanceof Object[] array)                        return serializeArray(array, depth);
        if (value instanceof Iterable<?> iterable)                  return serializeIterable(iterable, depth);
        if (value instanceof Map<?, ?> map)                         return serializeMap(map, depth);
        return serializeObj(value, depth);
    }

    private void checkDepth(int depth) {
        if (depth > MAX_DEPTH) {
            throw new IllegalStateException("Превышена максимальная глубина (" + MAX_DEPTH + ").");
        }
    }

    private String escape(String s) {
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&apos;");
    }

}