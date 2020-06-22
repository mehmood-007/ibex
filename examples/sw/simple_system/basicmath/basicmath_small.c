#include "snipmath.h"
#include <math.h>
#include "cubic.h"
//#include "simple_system_common.h"



/** Number on countu **/
/*
int n_tu(int number, int count)
{
    int result = 1;
    while(count-- > 0)
        result *= number;

    return result;
}
*/
/*** Convert float to string ***/
/*
void float_to_string(float f, char r[])
{
    long long int length, length2, i, number, position, sign;
    float number2;

    sign = -1;   // -1 == positive number
    if (f < 0)
    {
        sign = '-';
        f *= -1;
    }

    number2 = f;
    number = f;
    length = 0;  // Size of decimal part
    length2 = 0; // Size of tenth

    /* Calculate length2 tenth part 
    while( (number2 - (float)number) != 0.0 && !((number2 - (float)number) < 0.0) )
    {
         number2 = f * (n_tu(10.0, length2 + 1));
         number = number2;

         length2++;
    }

    /* Calculate length decimal part 
    for (length = (f > 1) ? 0 : 1; f > 1; length++)
        f /= 10;

    position = length;
    length = length + 1 + length2;
    number = number2;
    if (sign == '-')
    {
        length++;
        position++;
    }

    for (i = length; i >= 0 ; i--)
    {
        if (i == (length))
            r[i] = '\0';
        else if(i == (position))
            r[i] = '.';
        else if(sign == '-' && i == 0)
            r[i] = '-';
        else
        {
            r[i] = (number % 10) + '0';
            number /=10;
        }
    }
}
*/
/* The printf's may be removed to isolate just the math calculations */

int main(int argc, char **argv)
{
  double  a1 = 1.0, b1 = -10.5, c1 = 32.0, d1 = -30.0;
  double  a2 = 1.0, b2 = -4.5, c2 = 17.0, d2 = -30.0;
  double  a3 = 1.0, b3 = -3.5, c3 = 22.0, d3 = -31.0;
  double  a4 = 1.0, b4 = -13.7, c4 = 1.0, d4 = -35.0;
  double  x[3];
  double X;
  int     solutions;
  int i;
  unsigned long l = 0x3fed0169L;
  struct int_sqrt q;
  long n = 0;
 // char str[200];
  
//  gcvt(t2,10,str);
  //sprintf(str, "%.2f", x[0]); 
    /* solve soem cubic functions */
 // printf("********* CUBIC FUNCTIONS ***********\n");
  /* should get 3 solutions: 2, 6 & 2.5   */
  SolveCubic(a1, b1, c1, d1, &solutions, x); 

 // printf("Solutions:");
 // for( i=0; i<solutions; i++ ){
 //   float_to_string( x[i], str);
  //  puts( str ); printf("\n");
 //   sprintf(str, "%.2f", x[i]); 
 //   strcpy(str, ""); 
//  }
 //   printf(" %f",x[i]);
  //printf("\n");
  /* should get 1 solution: 2.5           */
  SolveCubic(a2, b2, c2, d2, &solutions, x);  
 // printf("Solutions:");
 // for(i=0;i<solutions;i++){
 //   float_to_string( x[i], str);
   // puts( str ); printf("\n");
 // }
  //  printf(" %f",x[i]);
 // printf("\n");
  SolveCubic(a3, b3, c3, d3, &solutions, x);
 // printf("Solutions:");
//  for(i=0;i<solutions;i++){
 //   float_to_string( x[i], str);
    //puts( str ); printf("\n");
//  }
  //  printf(" %f",x[i]);
  //printf("\n");
  SolveCubic(a4, b4, c4, d4, &solutions, x);
  //printf("Solutions:");
//  for(i=0;i<solutions;i++){
 //   float_to_string( x[i], str);
   // puts( str ); printf("\n");
 // }
 //   printf(" %f",x[i]);
 // printf("\n");
  /* Now solve some random equations */
  for(a1=1;a1<10;a1++) {
    for(b1=10;b1>0;b1--) {
     for(c1=5;c1<15;c1+=0.5) {
    	for(d1=-1;d1>-11;d1--) {
	      SolveCubic(a1, b1, c1, d1, &solutions, x);  
	 // printf("Solutions:");
	//  for(i=0;i<solutions;i++){
  //    float_to_string( x[i], str);
     // puts( str ); printf("\n");
  //  }
	  //  printf(" %f",x[i]);
	  //printf("\n");
	      }
      }
    }  
  //printf("********* INTEGER SQR ROOTS ***********\n");
  /* perform some integer square roots */
  for (i = 0; i < 1001; ++i)
    {
      usqrt(i, &q);
			// remainder differs on some machines
     // printf("sqrt(%3d) = %2d, remainder = %2d\n",
    // printf("sqrt(%3d) = %2d\n",
	//     i, q.sqrt);
    }
    usqrt(l, &q);
  //printf("\nsqrt(%lX) = %X, remainder = %X\n", l, q.sqrt, q.frac);
  //printf("\nsqrt(%lX) = %X\n", l, q.sqrt);
  }
 // printf("********* ANGLE CONVERSION ***********\n");
  /* convert some rads to degrees */
  //for (X = 0.0; X <= 360.0; X += 1.0)
  //  printf("%3.0f degrees = %.12f radians\n", X, deg2rad(X));
//  puts("Test");
 // for (X = 0.0; X <= (2 * PI + 1e-6); X += (PI / 180))
 //   printf("%.12f radians = %3.0f degrees\n", X, rad2deg(X));
  
  return 0;
}
