import java.util.Arrays;

public interface TaskSerializer {
    String serialize(Task task);
    String serialize(Iterable<Task> tasks);

    default String serialize(Task[] tasks) {
        return serialize(Arrays.asList(tasks));
    }
}