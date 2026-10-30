import java.lang.reflect.Field;
import java.util.Map;

public class JsonSerializer implements Serializer, SerializerGetOnly {

    // Serializer 1.2

    private String serializeObjGetOnly(Object obj){
        try {
            Map<String, Object> mapGet = Getter.getProperties(obj);
            StringBuilder SB = new StringBuilder();
            SB.append("{");

            for (Map.Entry<String, Object> entry : mapGet.entrySet()) {
                SB.append("\"").append(entry.getKey()).append("\": ")
                        .append(entry.getValue())
                        .append(",");

            }

            SB.append("}\n");
            return SB.toString();
        }
        catch (RuntimeException e)
        {
            throw new RuntimeException(
                    "Failed to serialize an object of class " + obj.getClass(), e);
        }

    }

    private String serializeIterableGetOnly(Iterable<?> iterable, Object obj){
        StringBuilder SB = new StringBuilder();
        SB.append("[");

        for (Object object : iterable) {
            SB.append(serializeObjGetOnly(object));
        }
        SB.deleteCharAt(SB.length() - 1);
        SB.append("]\n");
        return SB.toString();
    }

    @Override
    public String serializeGetOnly(Object obj) {
        String json;
        if (obj instanceof Iterable) {
            Iterable<?> iterable = (Iterable<?>) obj;
            json = serializeIterableGetOnly(iterable,obj);
        } else {
            json = serializeObjGetOnly(obj);
        }
        return json;
    }

    @Override
    public String serializeGetOnly(Object[] objs) {

        StringBuilder SB = new StringBuilder();
        SB.append("[");

        for (Object obj : objs) {
            SB.append(serializeObjGetOnly(obj));
        }
        SB.deleteCharAt(SB.length() - 1);
        SB.append("]\n");
        return SB.toString();
    }

    @Override
    public String serializeGetOnly(Map<?,?> map){
        StringBuilder SB = new StringBuilder();
        SB.append("[");
        for (Object value : map.values()) {
            SB.append(serializeObjGetOnly(value));
        }
        SB.deleteCharAt(SB.length() - 1);
        SB.append("]\n");
        return SB.toString();
    }


    // Serializer 1.1

    private String serializeObj(Object obj){

        StringBuilder SB = new StringBuilder();
        SB.append("{");

        for (Field field : obj.getClass().getDeclaredFields()) {
            field.setAccessible(true);
            try {
                Object value = field.get(obj);
                SB.append("\"").append(field.getName()).append("\": ")
                        .append(value)
                        .append(",");
            } catch (IllegalAccessException e) {
                throw new RuntimeException("Не удалось прочитать поле " + field.getName(), e);
            }
        }

        SB.append("}\n");
        return SB.toString();

    }

    private String serializeIterable(Iterable<?> iterable, Object obj){
        StringBuilder SB = new StringBuilder();
        SB.append("[");

        for (Object object : iterable) {
            SB.append(serializeObj(object));
        }
        SB.deleteCharAt(SB.length() - 1);
        SB.append("]\n");
        return SB.toString();
    }

    @Override
    public String serialize(Object obj) {
        String json;
        if (obj instanceof Iterable) {
            Iterable<?> iterable = (Iterable<?>) obj;
            json = serializeIterable(iterable,obj);
        } else {
            json = serializeObj(obj);
        }
        return json;
    }

    @Override
    public String serialize(Object[] objs) {

        StringBuilder SB = new StringBuilder();
        SB.append("[");

        for (Object obj : objs) {
            SB.append(serializeObj(obj));
        }
        SB.deleteCharAt(SB.length() - 1);
        SB.append("]\n");
        return SB.toString();
    }

    @Override
    public String serialize(Map<?,?> map){
        StringBuilder SB = new StringBuilder();
        SB.append("[");
        for (Object value : map.values()) {
            SB.append(serializeObj(value));
        }
        SB.deleteCharAt(SB.length() - 1);
        SB.append("]\n");
        return SB.toString();
    }
}