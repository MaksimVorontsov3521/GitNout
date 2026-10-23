import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.LinkedHashMap;
import java.util.Map;

public final class Getter {

    private Getter() {}

    public static Map<String, Object> getProperties(Object obj) {
        if (obj == null) {
            throw new IllegalArgumentException("Object must not be null");
        }

        Map<String, Object> properties = new LinkedHashMap<>();

        for (Method method : obj.getClass().getMethods()) {
            if (!method.getName().startsWith("get"))    continue;
            if (method.getParameterCount() != 0)        continue;
            if (method.getReturnType() == void.class)   continue;
            if (method.getName().equals("getClass"))    continue;

            String methodName;
            Name nameAnnotation = method.getAnnotation(Name.class);
            if (nameAnnotation != null) {
                methodName = nameAnnotation.value();
            } else {
                methodName = method.getName().substring(3).toLowerCase();
            }

            try {
                properties.put(methodName, method.invoke(obj));
            } catch (IllegalAccessException | InvocationTargetException e) {
                throw new RuntimeException("Не удалось вызвать геттер " + method.getName());
            }
        }

        return properties;
    }
}