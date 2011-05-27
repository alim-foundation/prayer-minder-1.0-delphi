
/*  hdate.c  v1.1
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
 *		wmuhanna@magnus.acs.ohio-state.edu
 *
 */

#include <stdio.h>
#include <time.h>
#include "hconv.h"

static char    *progname;

main(argc, argv)
	int	argc;
	char 	*argv[];
{
	int 	d, m, y, hflag=0;
	SDATE	*sd;
	struct tm *tm;
	time_t	 ts;
	void usage();

        progname = *argv++; argc--;


        if (argc>0 && argv[0][0]=='-' && argv[0][1]=='h') {
                hflag++; argv++; argc--;
        }

	if (argc==0) {
		if (hflag) usage("Hijri date must be given");
		ts = time((time_t *)0); tm = localtime(&ts);
		y = 1900+tm->tm_year; m = tm->tm_mon+1; d = tm->tm_mday;
	} else if (argc==3) {
		d = atoi(argv[0]);
		m = atoi(argv[1]);
		if (m<1||m>12) usage("Invalid month number specified");
		y = atoi(argv[2]);
		if (y==0 || (!hflag && y<0)) usage("Invalid year specified");
		if (hflag && d>30) usage("Invalid Hijri day number specified");
		if (d<1 || (!hflag && d>ndays(m,y))) 
			usage("Invalid day number specified");
	} else 
		usage(NULLP);

	if (hflag) {
		sd = gdate(y, m, d);
		printf("%s %d %s %d C.E.\n", dow[sd->dw], sd->day,
			mname[sd->mon-1], sd->year);
	} else {
		sd = hdate(y, m, d);
		printf("%s %d %s", dow[sd->dw], sd->day, hmname[sd->mon-1]);
		if (sd->year>0) printf(" %d A.H.\n", sd->year);
		else printf(" %d B.H.\n", -sd->year);
	}
	exit(0);
}

void
usage(msg)
	char	*msg;
{
	if (msg != NULLP) fprintf(stderr, "%s: %s\n", progname, msg);
	fprintf(stderr, 
		"Usage: %s [ [day month year] | [-h hday hmonth hyear] ]\n",
		progname);
	exit(1);
}
