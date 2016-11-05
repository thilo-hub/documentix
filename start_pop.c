#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>


main(int argc,char *argv[])
{
	char *exec=argv[0];
	char *r=malloc(strlen(exec)+20);
	int res;
	if ( !r ) exit(-1);
	strcpy(r,exec);
	strcat(r,".pl");
	res=execl(r,r);
	printf("Failed starting %s %d(%s)\n",r,errno,strerror(errno));
}

