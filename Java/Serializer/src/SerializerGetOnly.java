import java.util.Map;

public interface SerializerGetOnly {
    String serializeGetOnly(Object obj);
    String serializeGetOnly(Object[] objs);
    String serializeGetOnly(Map<?, ?> map);
}
