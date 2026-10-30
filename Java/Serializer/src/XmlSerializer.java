import java.lang.reflect.Field;
import java.util.Map;

public class XmlSerializer implements Serializer, SerializerGetOnly {

    // Serializer 1.2
    private String serializeObjGetOnly(Object obj){
    try {
        {
        }
        String name = obj.getClass().getSimpleName();
        StringBuilder SB = new StringBuilder();
        Map<String, Object> mapGet = Getter.getProperties(obj);

        SB.append("<").append(name).append(">");

        for (Map.Entry<String, Object> entry : mapGet.entrySet()) {
            SB.append("<").append(entry.getKey()).append(">")
                    .append(entry.getValue())
                    .append("</").append(entry.getKey()).append(">");
        }

        SB.append("</").append(name).append(">\n");
        return SB.toString();
    }
    catch (RuntimeException e)
    {
        throw new RuntimeException(
                "Failed to serialize an object of class " + obj.getClass(), e);
    }

    }

    private String serializeIterableGetOnly(Iterable<?> iterable, Object obj){
        String name = obj.getClass().getSimpleName();
        StringBuilder SB = new StringBuilder();
        SB.append("<").append(name).append(">\n");

        for (Object object : iterable) {
            SB.append(serializeObjGetOnly(object));
        }

        SB.append("</").append(name).append(">\n");
        return SB.toString();
    }

    @Override
    public String serializeGetOnly(Object obj) {
        String xml;
        if (obj instanceof Iterable) {
            Iterable<?> iterable = (Iterable<?>) obj;
            xml= serializeIterableGetOnly(iterable,obj);
        } else {
            xml= serializeObjGetOnly(obj);
        }
        return xml;
    }


    @Override
    public String serializeGetOnly(Object[] objs) {

        String name = objs.getClass().getSimpleName();
        StringBuilder SB = new StringBuilder();
        SB.append("<").append(name).append(">\n");

        for (Object obj : objs) {
            SB.append(serializeObjGetOnly(obj));
        }

        SB.append("</").append(name).append(">\n");
        return SB.toString();
    }

    @Override
    public String serializeGetOnly(Map<?,?> map){
        String name = map.getClass().getSimpleName();
        StringBuilder SB = new StringBuilder();
        SB.append("<").append(name).append(">\n");
        for (Object value : map.values()) {
            SB.append(serializeObjGetOnly(value));
        }
        SB.append("</").append(name).append(">\n");
        return SB.toString();
    }

    // Serializer 1.1
    private String serializeObj(Object obj){

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

        SB.append("</").append(name).append(">\n");
        return SB.toString();

    }

    private String serializeIterable(Iterable<?> iterable, Object obj){
        String name = obj.getClass().getSimpleName();
        StringBuilder SB = new StringBuilder();
        SB.append("<").append(name).append(">\n");

        for (Object object : iterable) {
            SB.append(serializeObj(object));
        }

        SB.append("</").append(name).append(">\n");
        return SB.toString();
    }

    @Override
    public String serialize(Object obj) {
        String xml;
        if (obj instanceof Iterable) {
            Iterable<?> iterable = (Iterable<?>) obj;
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

        SB.append("</").append(name).append(">\n");
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
        SB.append("</").append(name).append(">\n");
        return SB.toString();
    }
}