#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int main(int argc, char *argv[]) {
	unsigned MAXSIZE;
	unsigned MAXWAVES;
	unsigned i,j;

	MAXSIZE = 4096;
	MAXWAVES = 1;

	float RealIn[MAXSIZE];
	float ImagIn[MAXSIZE];
	float RealOut[MAXSIZE];
	float ImagOut[MAXSIZE];
	float coeff[MAXWAVES];
	float amp[MAXWAVES];
	int invfft=0;
	char str[20];
	double tt = 1.5;
/*
	if (argc<3)
	{
		printf("Usage: fft <waves> <length> -i\n");
		printf("-i performs an inverse fft\n");
		printf("make <waves> random sinusoids");
		printf("<length> is the number of samples\n");
		exit(-1);
	}
	else if (argc==4)
		invfft = !strncmp(argv[3],"-i",2);
	MAXSIZE=atoi(argv[2]);
	MAXWAVES=atoi(argv[1]);
		*/


// srand(1);

 /*
 RealIn=(float*)malloc(sizeof(float)*MAXSIZE);
 ImagIn=(float*)malloc(sizeof(float)*MAXSIZE);
 RealOut=(float*)malloc(sizeof(float)*MAXSIZE);
 ImagOut=(float*)malloc(sizeof(float)*MAXSIZE);
 coeff=(float*)malloc(sizeof(float)*MAXWAVES);
 amp=(float*)malloc(sizeof(float)*MAXWAVES);
*/
//	ftoa( tt, str, 2 );
//	sprintf(str, "%f", tt);
   // puts( str ); //printf("\n");
 /* Makes MAXWAVES waves of random amplitude and period */
	for(i=0;i<MAXWAVES;i++) 
	{
		coeff[i] = myRand()%1000;
		amp[i] = myRand()%1000;
	
	}
 for(i=0;i<MAXSIZE;i++) 
 {
   /*   RealIn[i]=rand();*/
	 RealIn[i]=0;
	 for(j=0;j<MAXWAVES;j++) 
	 {
		 /* randomly select sin or cos */
		 if (myRand()%2)
		 {
		 	RealIn[i]+=coeff[j]*cos(amp[j]*i);
		 }
		 else
		 {
		 	RealIn[i]+=coeff[j]*sin(amp[j]*i);
		 }
  	 ImagIn[i]=0;
	 }
 }

 /* regular*/
 fft_float (MAXSIZE,invfft,RealIn,ImagIn,RealOut,ImagOut);

/* puts("RealOut:");

 puts("\n");
// printf("RealOut:\n");
 for (i = 0; i < MAXSIZE; i++){
	// float_to_string(4.2, str);
	// puts(str);
	// sprintf(str, "%f", tt);
	ftoa(tt, str, 2); 

 //  printf("%f \t", RealOut[i]);
 }
 puts("\n");
 */
// printf("\n");
/*
printf("ImagOut:\n");
 for (i=0;i<MAXSIZE;i++)
   printf("%f \t", ImagOut[i]);
   printf("\n");
*/
/* free(RealIn);
 free(ImagIn);
 free(RealOut);
 free(ImagOut);
 free(coeff);
 free(amp);
 */
 //exit(0);


}
