
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "small_data.h"
#include "simple_system_common.h"

#define UNLIMIT
#define MAXARRAY 100 /* this number, if too large, will cause a seg. fault!! */

struct myStringStruct {
  char qstring[20];
};

int compare(const void *elem1, const void *elem2)
{
  int result;
  
  result = strcmp((*((struct myStringStruct *)elem1)).qstring, (*((struct myStringStruct *)elem2)).qstring);

  return (result < 0) ? 1 : ((result == 0) ? 0 : -1);
}

size_t strlcpy(char* dst, const char* src, size_t bufsize)
{
  size_t srclen =strlen(src);
  size_t result =srclen; /* Result is always the length of the src string */
  if(bufsize>0)
  {
    if(srclen>=bufsize)
       srclen=bufsize-1;
    if(srclen>0)
       memcpy(dst,src,srclen);
    dst[srclen]='\0';
  }
  return result;
}

int main(int argc, char *argv[]) {
  struct myStringStruct array[MAXARRAY] ;
  //FILE * fp;
  int i , count = 0 ;

 // snprintf(array[0].qstring, 3, "%s", "sss");
 // strlcpy( test, array_1[0].qstring, 6);
  for( i = 0; i < MAXARRAY; i++ ){
    
    strlcpy( array[i].qstring, INPUT_SMALL[i], 20);
    count++;
  }
 // array[0].qstring[128 - 1] = '\0';
  //puts(array_1[0].qstring);
  // puts(test);
  // puts("\n");
  //fp = fopen("input_small.dat","r");  
  //while((fscanf(fp, "%s", &array[count].qstring) == 1) && (count < MAXARRAY)) {
	 
  // printf("\"%s\",\n",array[count].qstring);
  // count++;
  //}
  //printf("\nSorting %d elements.\n\n",count);

  qsort(array, count, sizeof(struct myStringStruct), compare);
   // for( i=0; i < MAXARRAY ; i++ ){
    //puts(INPUT_SMALL[i]);
  //  puts(array[i].qstring);
  //  puts("\n");
 // }  
   // printf("%s\n", array[i].qstring);
  return 0;
}
