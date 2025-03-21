#include <stdio.h>
#include "test_lib.h"

void modifier(int *val, int i)
{
		printf("*");
		fflush(stdout);
		*val = i;
}
