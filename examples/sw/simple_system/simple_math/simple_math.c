// C code to illustrate
// the use of floor function
//#include <stdio.h>
//#include <math.h>
#include "simple_system_common.h"


int add(int b){
    return b + 4;
}

int abc(void){
    int a = 0;
    int i;
    for(i=0;i<10;i++)
        a = add(a);
    return a;
}

int main()
{
    int c;
    char ab[100] = "alaskalaska!!!";
    c = abc();
    puts(ab);
    return 0;
}
