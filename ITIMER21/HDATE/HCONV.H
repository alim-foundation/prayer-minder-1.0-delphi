
extern char	*mname[], *hmname[], *dow[];

typedef struct sdate {
	float time;
	int day;
	int mon;
	int year;
	int dw;
	double nmtime;
} SDATE;

extern SDATE *caldate(), *hdate(), *gdate();

extern double tmoonphase(), julianday();
extern int ndays();

#define NULLP    ((char *)0)

/* for portability */
#include <sys/types.h>
