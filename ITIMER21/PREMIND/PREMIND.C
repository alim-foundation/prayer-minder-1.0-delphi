
/*  premind.c  - prayers time reminder/notification service
 *
 * Copyright (c) 1992 by Waleed A. Muhanna
 *
 * Permission for nonprofit use and redistribution of this software and 
 * its documentation is hereby granted without fee, provided that the 
 * above copyright notice appear in all copies and that both that copyright 
 * notice and this permission notice appear in supporting documentation.
 *
 * No representation is made about the suitability of this software for any
 * purpose.  It is provided "as is" without express or implied warranty.
 *
 * Send any comments/suggestions/fixes/additions to: 
 *              wmuhanna@magnus.acs.ohio-state.edu
 *
 */

#include <sys/types.h>
#include <sys/stat.h>
/*
   #include <unistd.h>   */
#include <stdio.h>
#include <time.h>
#include <ctype.h>

#ifndef PRAYTIME
#define PRAYTIME "praytime"
#endif

static char *ptcmd = PRAYTIME;
static char     *progname, *pname[5] = {
	"Fajr (dawn)", "DHuhr (noon)", "`ASir (afternoon)",
	"MaGHrib (sunset)", "`ISHaa' (evening)"};

static long     ptime[5];
static int      dmin = 5, firsttime = 1;
static unsigned int dsec;


main(argc, argv)
	int     argc;
	char    *argv[];
{
	register char c, *cp;
	void usage(), gettimes(), doit();

	progname = *argv++; argc--;

	if (argc>0 && **argv == '-') {
		cp = *argv +1;
		if (*cp++ =='d') {
			if (*cp=='\0')
				if (argc>1) {
					cp = *++argv; argc--;
				} else usage();
			for (dmin = 0; (c = *cp); ++cp) {
				if (!isdigit(c)) usage();
				dmin = dmin * 10 + (c - '0');
			}
		} else usage();
		argc--; argv++;
	}

	if (argc != 0) 
		if (argc == 1) ptcmd = *argv; else usage();

	dsec = dmin * 60;
      

	while (1) {
		gettimes();
		doit();
	}
}


void
usage()
{
	fprintf(stderr, "Usage: %s [-d min] [ptcommand]\n", progname);
	exit(1);
}

void
gettimes()
{
	FILE *fin;
	char buf[82];
	int hf, mf, hn, mn, ha, ma, hm, mm, he, me, i=0;
	extern int strncmp();

	if ((fin = popen(ptcmd, "r")) == NULL) {
		fprintf(stderr, "%s: can't find/run %s\n", progname, ptcmd);
		exit(1);
	}

	while (fgets(buf, sizeof buf, fin) != NULL) {
	    if (firsttime) fprintf(stderr,"%s", buf);
	    if (++i>8) break;  /*can't go on forever*/
	    if (strncmp(buf,"Date", 4) == 0)
		 if (fgets(buf, sizeof buf, fin) != NULL) {
		    pclose(fin);
		    if (sscanf(buf, "%*d %d:%d %*d:%*d %d:%d %d:%d %d:%d %d:%d",
			   &hf, &mf, &hn, &mn, &ha, &ma, &hm,
			   &mm, &he, &me) != 10) break;
		    if (firsttime) fprintf(stderr,"%s\n", buf);
		    if (hn<5) hn +=12;
		    ha +=12; hm +=12; he +=12;
		    ptime[0] = (hf*60+mf)*60;
		    ptime[1] = (hn*60+mn)*60;
		    ptime[2] = (ha*60+ma)*60;
		    ptime[3] = (hm*60+mm)*60;
		    ptime[4] = (he*60+me)*60;
		    return;
		 } else break;
	}

	fprintf(stderr, "%s: output format of %s unrecognized!\n",
		progname, ptcmd);
	exit(1);
}


void 
csleep(secs)
	unsigned int    secs;
{
	struct stat buf;
	unsigned int twohrs = 7200;

	while (secs>twohrs) {
		(void)sleep(twohrs);
		if (fstat(2,&buf)!=0) exit(0);
		secs -= twohrs;
	}
	(void)sleep(secs);
}


#define ONEMIN  60

void
doit()
{
	struct tm *t;
	time_t now;
	long tnow;
	int pid, i;
	void dopremind();

	now = time((time_t *)0); t = localtime(&now);
	tnow = (t->tm_hour*60L + t->tm_min)*60L + t->tm_sec;

	for (i=0; i<5; i++) 
		if (ptime[i]>tnow) {
			dopremind((unsigned int)(ptime[i]-tnow), i);
			tnow = ptime[i]+ONEMIN;
		}

	if (firsttime) {
		firsttime--;
		if (pid = fork()) { 
			fprintf(stderr, 
		"Next prayer reminder set for Fajr (dawn) tomorrow. (pid %d)\n",
				pid);
			exit(0);
		}
	}

	/* go to sleep until 2:02 the next morning */
	csleep((unsigned int)(93720L - tnow));
}



void
dopremind(secs, pi)
	unsigned int secs;
	int pi;
{
	int pid, i;
	time_t tup;

	if (firsttime) {
		firsttime--;
		fprintf(stderr,"Next prayer reminder set for %s on ",
			pname[pi]);
		if (pid = fork()) {
			(void)time(&tup);
			tup += secs;
			fprintf(stderr,"%.16s. (pid %d)\n", ctime(&tup), pid);
			exit(0);
		}
		(void)sleep((unsigned int)2);
	}

	/* if write fails, we've lost the terminal (a la BSD command leave). */

#define MSG1    "minutes.\n"
	if (dsec !=0 && secs >= dsec) {
		csleep(secs - dsec);
		fprintf(stderr, "\07\07%s Prayers in %d ", pname[pi], dmin);
		if (write(2, MSG1, sizeof(MSG1) - 1) != sizeof(MSG1) - 1)
			exit(0);
		secs = dsec;
	}

#define MSG2    "\07\07Just one more minute till prayers' time!\n"
	if (secs > ONEMIN) {
		(void)sleep(secs - ONEMIN);
		if (write(2, MSG2, sizeof(MSG2) - 1) != sizeof(MSG2) - 1)
			exit(0);
		secs = ONEMIN;
	}

	(void)sleep(secs);

#define MSG3    "\07\07Time for"
	for (i=2; i--;) {
		if (i) {
			(void)time(&tup);
			fprintf(stderr, "It is now %.16s; ", ctime(&tup));
		} else {
			(void)sleep((unsigned int)ONEMIN);
			fprintf(stderr, "You're late; ");
		}
			
		if (write(2, MSG3, sizeof(MSG3) - 1) != sizeof(MSG3) - 1)
			exit(0);
		fprintf(stderr," %s Prayers!\n", pname[pi]);
	}
}
