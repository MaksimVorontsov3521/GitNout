import java.util.ArrayList;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        Task task1 = new Task("Проснуться", Priority.MEDIUM);
        Task task2 = new Task("Улыбнуться", Priority.LOW);
        Task task3 = new Task("Идти на учёбу", Priority.HIGH);

        Serializer xmlSerializer = new XmlSerializer();
        System.out.println("\nXML:" + xmlSerializer.serialize(task1));

        Serializer jsonSerializer = new JsonSerializer();
        System.out.println("\nJSON:" + jsonSerializer.serialize(task1));

        System.out.println("Сериализация Списка");

        List<Task> taskList = new ArrayList<>();
        taskList.add(task1);
        taskList.add(task2);
        taskList.add(task3);

        System.out.println("\nXML:" + xmlSerializer.serialize(taskList));
        System.out.println("\nJSON:" + jsonSerializer.serialize(taskList));

        System.out.println("\nСериализация Массива");

        Task[] taskArray = {task1, task2, task3};

        System.out.println("\nXML:" + xmlSerializer.serialize(taskArray));
        System.out.println("\nJSON:" + jsonSerializer.serialize(taskArray));
    }
}