// C code to illustrate
// the use of floor function
//#include <stdio.h>
//#include <math.h>
#include "simple_system_common.h"
#include <stdio.h>
#include <stdlib.h>
 
struct node {
  int x;
  int y;
  int z;
  struct node *next;
};
 
int main()
{

int a = 543210 ;
char arr[10] ="" ;

   // itoa() is a function of stdlib.h file that convert integer 
                   // int to array itoa( integer, targated array, base u want to             
                   //convert like decimal have 10 
                   puts(arr);
    /* This won't change, or we would lose the list in memory */
    struct node *root;       
    /* This will point to each node as it traverses the list */
    struct node *conductor;  
    puts( "Out of memory" );
    root = malloc( sizeof(struct node) ); 
    if (root == NULL) {
        root->next = 0;   
    //		perror("Allocating p-trie node");
	//	exit(0);
	} 
    root->next = 0;   
    root->x = 12;
    root->y = 12;
    root->z = 12;

    conductor = root; 
    if ( conductor != 0 ) {
        while ( conductor->next != 0)
        {
            conductor = conductor->next;
        }
    }
    /* Creates a node at the end of the list */
    conductor->next = malloc( sizeof(struct node) );  
 
    conductor = conductor->next; 
 
    if ( conductor == 0 )
    {
        //printf( "Out of memory" );
        //return 0;
    }
    /* initialize the new memory */
    conductor->next = 0;         
    conductor->x = 42;
    conductor->y = 0;
    conductor->z = 0;

    conductor = root;
    if ( conductor != 0 ) { /* Makes sure there is a place to start */
        while ( conductor->next != 0 ) {
            //itoa(conductor->next,arr,10) ;
           // putchar(*(conductor->x) + '0');
           // printf( "%d\n", conductor->x );
            conductor = conductor->next;
        }
        //printf( "%d\n", conductor->x );
    }

    return 0;
}
