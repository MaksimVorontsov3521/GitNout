import java.lang.reflect.Field;

public class JsonSerializer implements Serializer {

    private String serializeObj (Object obj){

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

    @Override
    public String serialize(Object obj) {
        String json;
        if (obj instanceof Iterable<?> iterable) {
            StringBuilder SB = new StringBuilder();
            SB.append("[");

            for (Object object : iterable) {
                SB.append(serializeObj(object));
            }
            SB.deleteCharAt(SB.length() - 1);
            SB.append("]\n");
            json= SB.toString();
        } else {
            json= serializeObj(obj);
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
}