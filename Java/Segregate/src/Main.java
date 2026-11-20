import java.util.ArrayList;
import java.util.Collection;

public class Main {

    public static void segregate(Collection<? extends Mammals> srcCollection,
                                 Collection<? super Hedgehog> collection1,
                                 Collection<? super Manul> collection2,
                                 Collection<? super Lynx> collection3) {

        for (Mammals animal : srcCollection) {
            if (animal instanceof Hedgehog) {
                collection1.add((Hedgehog) animal);
            }
            if (animal instanceof Manul) {
                collection2.add((Manul) animal);
            }
            if (animal instanceof Lynx) {
                collection3.add((Lynx) animal);
            }
        }
    }


    public static void main(String[] args) {
        task1();
        System.out.println();

        task2();
        System.out.println();

        task3();
        System.out.println();

    }

    private static void task1() {

        Collection<Mammals> mammals = new ArrayList<>();
        mammals.add(new Hedgehog());
        mammals.add(new Manul());
        mammals.add(new Lynx());
        mammals.add(new Hedgehog());

        Collection<HedgehogFamily> hedgehogFamily = new ArrayList<>();
        Collection<CatFamily> catFamily = new ArrayList<>();
        Collection<Carnivorous> carnivorous = new ArrayList<>();

        System.out.println("Task 1 mammals, hedgehogFamily, catFamily, carnivorous");
        System.out.println(mammals);

        segregate(mammals, hedgehogFamily, catFamily, carnivorous);

        System.out.println("hedgehogFamily");
        System.out.println(hedgehogFamily);

        System.out.println("catFamily");
        System.out.println(catFamily);

        System.out.println("carnivorous");
        System.out.println(carnivorous);

        System.out.println("mammals");
        System.out.println(mammals);
    }

    private static void task2() {

        Collection<Carnivorous> carnivorous = new ArrayList<>();
        carnivorous.add(new Manul());
        carnivorous.add(new Lynx());
        carnivorous.add(new Manul());

        Collection<Mammals> mammals = new ArrayList<>();
        Collection<Manul> manuls = new ArrayList<>();
        Collection<CatFamily> catFamily = new ArrayList<>();

        System.out.println("Task 2 carnivorous, mammals, manuls, catFamily");
        System.out.println(carnivorous);

        segregate(carnivorous, mammals, manuls, catFamily);

        System.out.println("mammals");
        System.out.println(mammals);

        System.out.println("manuls");
        System.out.println(manuls);

        System.out.println("catFamily");
        System.out.println(catFamily);
    }

    private static void task3() {
        Collection<HedgehogFamily> hedgehogFamily = new ArrayList<>();
        hedgehogFamily.add(new Hedgehog());
        hedgehogFamily.add(new Hedgehog());

        Collection<Insectivores> insectivores = new ArrayList<>();
        Collection<Carnivorous> shared = new ArrayList<>();

        System.out.println(hedgehogFamily);

        segregate(hedgehogFamily, insectivores, shared, shared);

        System.out.println(insectivores);
        System.out.println(shared);
        System.out.println(shared);
    }

}
