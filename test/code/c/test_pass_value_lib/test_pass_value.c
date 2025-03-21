#include <stdio.h>
#include <stdlib.h>

// Test library
#include "test_lib.h"

#define N 100
int *foo();
void modifier(int *val, int i);
int main()
{
	int *a=NULL;
	a = (int*)malloc(N*sizeof(int));
	printf(" a is now %d\n", *a);
	
	for (int i = 1; i<=10; i++)
	{
		modifier(a,i);
		printf("\n\t inside loop: a[%d] = %d",i, *a);
		a++;
		fflush(stdout);
	}

	printf("\na is now %d\n", *a); // 0
	int* heap_addr = foo();
	printf("\nfoo -->%d\n\n", *heap_addr);
	return(0);
}

int* foo()
{
	int *val = NULL;
	val = malloc(sizeof(int));
	*val = 123;
	return(val);
}


