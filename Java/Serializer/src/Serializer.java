import java.util.Arrays;

public interface Serializer {
    String serialize(Object obj);
    String serialize(Object[] objs);
}