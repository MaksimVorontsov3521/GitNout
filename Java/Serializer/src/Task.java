public class Task {

    private static int _id = 1;

    private final int id;
    private String name;
    private Priority priority;
    private String SomeString;

    public Task(String name, Priority priority) {
        this.id = _id++;
        this.name = name;
        this.priority = priority;
    }

    public int getId() { return id; }
    @Name("task-name")
    public String getName() { return name; }
    public Priority getPriority() { return priority; }
}

