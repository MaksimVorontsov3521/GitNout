#include <stdio.h>
#include <conio.h>

int calc(int x, int y) {
    int temp1;
    int temp2;
    
    temp1 = 2 * x;
    temp2 = 3 * y;
    
    return temp1 + temp2;
}

void main(void) {
    int result;
    clrscr();
    
    result = calc(10, 20);
    printf("Result: %d\n", result);
    
    getch();
}