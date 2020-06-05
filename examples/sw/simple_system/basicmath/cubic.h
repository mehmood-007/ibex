/* +++Date last modified: 05-Jul-1997 */

/*
**  CUBIC.H - Header file for CUBIC math functions and macros
*/

#ifndef CUBIC__H
#define CUBIC__H

#include "pi.h"


void SolveCubic(double a, double b, double c,      /* Cubic.C        */
                  double d, int *solutions,
                  double *x);

#endif /* CUBIC__H */