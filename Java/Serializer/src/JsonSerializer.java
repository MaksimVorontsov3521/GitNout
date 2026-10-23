import java.util.Map;

public class JsonSerializer implements Serializer {

    private static final int MAX_DEPTH = 32;

    @Override public String serialize(Object[] objs) { return serializeArray(objs, 0); }
    @Override public String serialize(Map<?, ?> map) { return serializeMap(map, 0); }

    @Override
    public String serialize(Object obj) {
        if (obj == null)                            return "null";
        if (obj instanceof Object[] array)          return serializeArray(array, 0);
        if (obj instanceof Iterable<?> iterable)    return serializeIterable(iterable, 0);
        if (obj instanceof Map<?, ?> map)           return serializeMap(map, 0);
        return serializeObj(obj, 0);
    }

    private String serializeObj(Object obj, int depth) {
        checkDepth(depth);
        StringBuilder sb = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, Object> variable : Getter.getProperties(obj).entrySet()) {
            if (!first) sb.append(", ");
            first = false;
            sb.append('"').append(escape(variable.getKey())).append("\": ")
                    .append(serializeValue(variable.getValue(), depth + 1));
        }
        return sb.append('}').toString();
    }

    private String serializeArray(Object[] objs, int depth) {
        checkDepth(depth);
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < objs.length; i++) {
            if (i > 0) sb.append(", ");
            sb.append(serializeValue(objs[i], depth + 1));
        }
        return sb.append(']').toString();
    }

    private String serializeIterable(Iterable<?> iterable, int depth) {
        checkDepth(depth);
        StringBuilder sb = new StringBuilder("[");
        boolean first = true;
        for (Object o : iterable) {
            if (!first) sb.append(", ");
            first = false;
            sb.append(serializeValue(o, depth + 1));
        }
        return sb.append(']').toString();
    }

    private String serializeMap(Map<?, ?> map, int depth) {
        checkDepth(depth);
        StringBuilder sb = new StringBuilder("[");
        boolean first = true;
        for (Object value : map.values()) {
            if (!first) sb.append(", ");
            first = false;
            sb.append(serializeValue(value, depth + 1));
        }
        return sb.append(']').toString();
    }


    private String serializeValue(Object value, int depth) {
        checkDepth(depth);
        if (value == null)                                          return "null";
        if (value instanceof Number || value instanceof Boolean)    return value.toString();
        if (value instanceof Enum<?> e)                             return '"' + escape(e.name()) + '"';
        if (value instanceof Object[] array)                        return serializeArray(array, depth);
        if (value instanceof Iterable<?> iterable)                  return serializeIterable(iterable, depth);
        return serializeObj(value, depth);
    }

    private void checkDepth(int depth) {
        if (depth > MAX_DEPTH) {
            throw new IllegalStateException( "Превышена максимальная глубина (" + MAX_DEPTH + ").");
        }
    }

    private String escape(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"'  -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default   -> sb.append(c);
            }
        }
        return sb.toString();
    }

}