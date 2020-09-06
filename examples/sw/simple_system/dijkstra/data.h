#ifndef DATA_H_
#define DATA_H_

const int INPUT[50][100] = { {32, 32, 54, 12, 52, 56, 8, 30, 44, 94, 44, 39, 65, 19, 51, 91, 1, 5, 89, 34, 25, 58, 20, 51, 38, 65, 30, 7, 20, 10, 51, 18, 43, 71, 97, 61, 26, 5, 57, 70, 65, 0, 75, 29, 86, 93, 87, 87, 64, 75, 88, 89, 100, 7, 40, 37, 38, 36, 44, 24, 46, 95, 43, 89, 32, 5, 15, 58, 77, 72, 95, 8, 38 ,69, 37, 24, 27, 90, 77, 92, 31, 30, 80, 30, 37, 86, 33, 76, 21, 77, 100, 68, 37, 8, 22, 69, 81, 38 ,94, 57}, 
{76, 54, 65, 14, 89, 69, 4, 16, 24, 47, 7 ,21, 78, 53, 17, 81, 39, 50, 22, 60, 93, 89, 94, 30, 97, 16, 65, 43, 20, 24, 67, 62, 78, 98, 42, 67, 32, 46, 49, 57, 60, 56, 44, 37, 75, 62, 17, 13, 11, 40, 40, 4, 95, 100, 0, 57, 82, 31, 0, 1, 56, 67, 30, 100, 64, 72, 66, 63, 18, 81, 19, 44, 2, 63, 81, 78, 91, 64, 91, 2, 70, 97, 73, 64, 97, 39, 21, 78, 70, 21, 46, 25, 54, 76, 92, 84, 47, 57, 46, 31 }
};

#define NUM_NODES                          10
#define NONE                               9999

struct _NODE
{
  int iDist;
  int iPrev;
};
typedef struct _NODE NODE;

struct _QITEM
{
  int iNode;
  int iDist;
  int iPrev;
  struct _QITEM *qNext;
};
typedef struct _QITEM QITEM;

void enqueue (int iNode, int iDist, int iPrev);
void print_path (NODE *rgnNodes, int chNode);
void dequeue (int *piNode, int *piDist, int *piPrev);

#endif  // DATA_