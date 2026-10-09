import java.util.Arrays;
import java.util.Map;

public interface Serializer {
    String serialize(Object obj);
    String serialize(Object[] objs);
    String serialize(Map<?, ?> map);
}