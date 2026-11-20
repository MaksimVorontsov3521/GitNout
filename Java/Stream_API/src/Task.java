import java.time.LocalDate;

public class Task {
    private static int _id = 1;

    private final int id;
    private String name;
    private Priority priority;
    private LocalDate start;
    private LocalDate end;
    private double cost;
    private String SomeString;

    public Task(String name, Priority priority, LocalDate start, LocalDate end, double cost) {

        if (start == null || end == null || priority == null || name == null) {
            throw new IllegalArgumentException("Аргументы не могут быть null");
        }

        this.id = _id++;
        this.name = name;
        this.priority = priority;
        this.cost = cost;

        if (end.isBefore(start)) {
            this.start = end;
            this.end = start;
        } else {
            this.start = start;
            this.end = end;
        }
    }

    public Task(String name, Priority priority, LocalDate end, double cost) {
        this(name, priority, validateEndDate(end), end, cost);
    }

    private static LocalDate validateEndDate(LocalDate end) {
        LocalDate today = LocalDate.now();
        if (end == null || end.isBefore(today)) {
            throw new IllegalArgumentException("Дата окончания не может быть раньше текущей даты");
        }
        return today;
    }

    public int getId() { return id; }
    public String getName() { return name; }
    public double getCost() { return cost; }
    public Priority getPriority() { return priority; }
    public LocalDate getStart() {return  start;}
}
