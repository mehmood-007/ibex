#ifndef CUSTOM_LIB_H__
#define CUSTOM_LIB_H__

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

    int state = 777;

    void ftoa(float n, char* res, int afterpoint) ;
    int intToStr(int x, char str[], int d) ;
    void reverse(char* str, int len);
//    int n_tu(int number, int count);
    int myRand(void);

#endif  // CUSTOM_LIB_H__