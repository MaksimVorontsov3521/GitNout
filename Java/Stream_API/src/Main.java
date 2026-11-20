import java.util.*;
import java.time.LocalDate;
import java.util.function.Predicate;
import java.util.stream.Collectors;
import java.util.function.BinaryOperator;


public class Main {
    public static void main(String[] arg) {

        // Создайте список задач (не менее 10) и выведите его на экран
        List<Task> taskList = new ArrayList<>();
        taskList.add(new Task("Задача 1",Priority.High,LocalDate.of(2026, 11, 20),
                LocalDate.of(2026, 11, 25),100));
        taskList.add(new Task("Задача 2",Priority.Low,LocalDate.of(2026, 12, 21),
                LocalDate.of(2026, 11, 25),200));
        taskList.add(new Task("Задача 3",Priority.Mid,LocalDate.of(2027, 1, 22),
                LocalDate.of(2027, 5, 25),300));
        taskList.add(new Task("Задача 4",Priority.High,LocalDate.of(2026, 1, 23),
                LocalDate.of(2027, 4, 25),400));
        taskList.add(new Task("Задача 5",Priority.Low,LocalDate.of(2027, 1, 24),
                LocalDate.of(2027, 5, 25),500));
        taskList.add(new Task("Задача 6",Priority.Mid,LocalDate.of(2027, 1, 25),
                LocalDate.of(2027, 5, 25),600));
        taskList.add(new Task("Задача 7",Priority.High,LocalDate.of(2027, 1, 10),
                LocalDate.of(2027, 5, 25),700));
        taskList.add(new Task("Задача 8",Priority.Low,LocalDate.of(2027, 2, 11),
                LocalDate.of(2027, 6, 25),800));
        taskList.add(new Task("Задача 9",Priority.Mid,LocalDate.of(2027, 2, 12),
                LocalDate.of(2027, 6, 25),900));
        taskList.add(new Task("Задача 10",Priority.High,LocalDate.of(2027, 2, 13),
                LocalDate.of(2027, 6, 25),1000));
        taskList.add(new Task("Задача 11",Priority.Low,LocalDate.of(2027, 2, 1),
                LocalDate.of(2027, 6, 25),1100));
        taskList.add(new Task("Задача 12",Priority.Mid,LocalDate.of(2027, 1, 2),
                LocalDate.of(2027, 6, 25),1200));
        taskList.add(new Task("Уборка",Priority.Mid, LocalDate.of(2027, 1, 01),200));
        taskList.add(new Task("Уборка",Priority.Mid, LocalDate.of(2027, 2, 01),200));
        taskList.add(new Task("Уборка",Priority.Mid, LocalDate.of(2027, 3, 01),200));
        taskList.add(new Task("Уборка",Priority.Mid, LocalDate.of(2027, 4, 01),200));

        String result = taskList.stream()
                .map(Task::getName)
                .collect(Collectors.joining(", "));
        System.out.println("Создайте список задач (не менее 10) и выведите его на экран");
        System.out.println(result);


        // Получите среднюю стоимость задач с высоким приоритетом, если таких нет - сгенерируйте исключение;
        System.out.println("1 ----------------------");
        try {
            System.out.println(getAvgCostPriority(taskList, Priority.High));
            System.out.println(getAvgCostPriority(taskList, Priority.VeryHigh));
        }
        catch (NoSuchElementException e){
            System.out.println(e);
        }


        // Получите общую стоимость задач, начинающихся после указанной даты (0, если таких нет);
        System.out.println("2 ----------------------");

        System.out.println(getCostAfterTheDay(taskList,LocalDate.of(2027, 01, 01) ));
        System.out.println(getCostAfterTheDay(taskList,LocalDate.of(2028, 01, 01) ));


        // Получите список задач с высоким приоритетом, отсортированных по датам начала
        System.out.println("3 ----------------------");

        List<Task> listTask3 = getSortetByDate_Priority(taskList,Priority.Mid);
        listTask3.forEach(task -> System.out.println(task.getName() + " " + task.getStart()));

        // Получите отсортированный список уникальных слов, входящих в названия задач
        System.out.println("4 ----------------------");
        getUniqueWords(taskList);

        // Получите наименьшую и наибольшую стоимости задач за один проход по списку(!)
        System.out.println("5 ----------------------");
        getMinAndMaxCost(taskList);

        // Получите Map, в которой ключ - дата, значение - список идентификаторов задач, начинающихся в эту дату
        System.out.println("6 ----------------------");
        MapDataID(taskList);

        // Получите Map, в которой ключ - дата, значение - наивысший приоритет задачи, начинающейся в эту дату
        System.out.println("7 ----------------------");
        MapDatePriority(taskList);

        // Получите строку, содержащую названия задач в алфавитном порядке, перечисленные через запятую
        System.out.println("8 ----------------------");
        sortedTaskName(taskList);



    }

    public static double getAvgCostPriority(List<Task> taskList, Priority priority ) {
        double avgCost = taskList.stream()
                .filter(task -> task.getPriority() == priority)
                .mapToDouble(Task::getCost)
                .average()
                .orElseThrow(() -> new NoSuchElementException("Задачи с приоритетом "+ priority+ " не найдены"));
        return avgCost;
    }
    public static double getCostAfterTheDay(List<Task> taskList, LocalDate TheDate) {
        double costAfterTheDate = taskList.stream()
                .filter(task -> task.getStart().isAfter(TheDate))
                .mapToDouble(Task::getCost)
                .sum();
        return costAfterTheDate;
    }

    public static List<Task>  getSortetByDate_Priority(List<Task> taskList, Priority priority) {
        List<Task> result = taskList.stream()
                .filter(task -> task.getPriority() == priority)
                .sorted(Comparator.comparing(Task::getStart))
                .collect(Collectors.toList());
        return result;
    }

    public static void getUniqueWords(List<Task> taskList ) {
        List<String> uniqueWords = taskList.stream()
                .map(Task::getName)
                .flatMap(line -> Arrays.stream(line.trim().split("\\s+")))
                .map(String::toLowerCase)
                .distinct()
                .sorted()
                .collect(Collectors.toList());
        System.out.println(uniqueWords);
    }

    public static void getMinAndMaxCost(List<Task> taskList ) {
        double[] minMax = {Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY};

        taskList.forEach(task -> {
            double cost = task.getCost();
            if (cost < minMax[0]) {
                minMax[0] = cost;
            }
            if (cost > minMax[1]) {
                minMax[1] = cost;
            }
        });

        System.out.println("Min cost: " + minMax[0]);
        System.out.println("Max cost: " + minMax[1]);
    }

    public static void MapDataID(List<Task> taskList ) {

        Map<LocalDate, List<Integer>> mapDataID = taskList.stream()
                .collect(Collectors.groupingBy(
                        Task::getStart,
                        Collectors.mapping(Task::getId, Collectors.toList())
                ));
        System.out.println(mapDataID);
    }

    public static void MapDatePriority(List<Task> taskList ) {

        Map<LocalDate, Priority> mapDatePriorityMax = taskList.stream()
                .collect(Collectors.toMap(
                        Task::getStart,
                        Task::getPriority,
                        BinaryOperator.maxBy(Comparator.naturalOrder())
                ));
        System.out.println(mapDatePriorityMax);
    }

    public static void sortedTaskName(List<Task> taskList ) {

        String sortedTaskNames = taskList.stream()
                .map(Task::getName)
                .sorted()
                .collect(Collectors.joining(", "));

        System.out.println(sortedTaskNames);
    }
}