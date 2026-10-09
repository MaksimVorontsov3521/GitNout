import java.lang.reflect.Field;
import java.util.Map;

public class XmlSerializer implements Serializer {

    private String serializeObj (Object obj){

        String name = obj.getClass().getSimpleName();
        StringBuilder SB = new StringBuilder();
        SB.append("<").append(name).append(">");

        for (Field field : obj.getClass().getDeclaredFields()) {
            field.setAccessible(true);
            try {
                Object value = field.get(obj);
                SB.append("<").append(field.getName()).append(">")
                        .append(value)
                        .append("<").append(field.getName()).append(">");
            } catch (IllegalAccessException e) {
                throw new RuntimeException("Не удалось прочитать поле " + field.getName(), e);
            }
        }

        SB.append("<").append(name).append(">\n");
        return SB.toString();

    }

    private String serializeIterable(Iterable<?> iterable, Object obj){
        String name = obj.getClass().getSimpleName();
        StringBuilder SB = new StringBuilder();
        SB.append("<").append(name).append(">\n");

        for (Object object : iterable) {
            SB.append(serializeObj(object));
        }

        SB.append("<").append(name).append(">\n");
        return SB.toString();
    }

    @Override
    public String serialize(Object obj) {
        String xml;
        if (obj instanceof Iterable<?> iterable) {
            xml= serializeIterable(iterable,obj);
        } else {
            xml= serializeObj(obj);
        }
        return xml;
    }



    @Override
    public String serialize(Object[] objs) {

        String name = objs.getClass().getSimpleName();
        StringBuilder SB = new StringBuilder();
        SB.append("<").append(name).append(">\n");

        for (Object obj : objs) {
            SB.append(serializeObj(obj));
        }

        SB.append("<").append(name).append(">\n");
        return SB.toString();
    }

    @Override
    public String serialize(Map<?,?> map){
        String name = map.getClass().getSimpleName();
        StringBuilder SB = new StringBuilder();
        SB.append("<").append(name).append(">\n");
        for (Object value : map.values()) {
            SB.append(serializeObj(value));
        }
        SB.append("<").append(name).append(">\n");
        return SB.toString();
    }
}