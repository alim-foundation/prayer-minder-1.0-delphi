
/* hcal.c
 *
 * Copyright (c) 1992 by Waleed A. Muhanna
 *
 * Permission for nonprofit use and redistribution of this software and 
 * its documentation is hereby granted without fee, provided that the 
 * above copyright notice appear in all copies and that both that copyright 
 * notice and this permission notice appear in supporting documentation.
 *
 * No representation is made about the suitability of this software for any
 * purpose.  It is provided "as is" without any express or implied warranty.
 *
 * Send any comments/suggestions/fixes/additions to:
 *		wmuhanna@magnus.acs.ohio-state.edu
 *
 */

#include <stdio.h>
#include <time.h>
#include "hconv.h"

static char	*progname;
static int	hflag=0;

main(argc, argv)
	int	argc;
	char 	*argv[];
{
	int d, m, y;
	SDATE *sd;
	struct tm *tm;
        time_t ts;

	void gcal(), hcal(), usage();
	void (*cal)() = gcal;

	progname = *argv++; argc--;

        if (argc>0 && argv[0][0]=='-' && argv[0][1]=='h') {
                cal = hcal; hflag++;
                argv++; argc--;
        }

	if (argc==0) {
                ts = time((time_t *)0); tm = localtime(&ts);
                y = 1900+tm->tm_year; m = tm->tm_mon+1; 
		if (hflag) { /* find the current Hijri month */
			d = tm->tm_mday;
			sd = hdate(y, m, d);
			y= sd->year; m = sd->mon;
		}
		(*cal)(m,y);
	} else if (argc==1) {
		y = atoi(argv[0]);
		if (y==0||(!hflag && y<0)) 
			usage("Invalid year/option specified");
		for (m=1; m<=12; m++) (*cal)(m, y);
	} else if (argc==2) {
		m = atoi(argv[0]);
		if (m<=0||m>12) usage("Invalid month number specified");
		y = atoi(argv[1]);
		if (y==0||(!hflag && y<0)) usage("Invalid year specified");
		(*cal)(m, y);
	} else usage(NULLP);

	exit(0);

}

void
usage(msg)
	char	*msg;
{
	if (msg != NULLP) fprintf(stderr, "%s: %s\n", progname, msg);
	fprintf(stderr, "Usage: %s [-h] [[month] year]\n", progname);
	exit (1);
}


void
printmcal(dw, fday, lday, nd, mday)
	int	dw, fday, lday, nd, mday;
{
	register i, hi;

	printf(" Sun   Mon   Tue   Wed   Thu   Fri   Sat\n");

	for (i=0; i<dw; i++) printf("      ");
	hi = fday;

	for (i=1; i<=nd; i++) {
		if (i==mday) hi=1;
		printf("%2d/%2d", i,hi);
		if (++dw == 7) {
			printf("\n");
			dw = 0;
		} else
			printf(" ");
		if (i==nd-lday) hi = 0;
		hi++;
	}
	if (dw) printf("\n\n"); else printf("\n");
}


/* print cal of month m of Gregorian year y */
void
gcal(m, y)
	int  m,y;
{
	SDATE fd, ld, md;
	int yr,mo;
	int nd = ndays(m,y);

	fd = *hdate(y, m, 1);
	ld = *hdate(y, m, nd);

	printf("%s %4d C.E.", mname[m-1], y);
	printf(" / %s", hmname[fd.mon-1]);
	if (fd.year != ld.year) {
		y = fd.year;
		if (y>0 && ld.year>0) printf(" %d", y);
		else if (y>0) printf(" %d A.H.",y); 
		     else printf(" %d B.H.", -y);
		yr = ld.year;
	} else yr = fd.year;
	md.day =0;
	if (fd.mon != ld.mon) {
		if ((fd.mon <ld.mon-1) || (fd.mon==12 && ld.mon==2)) {
				/*three month span*/
			if (fd.mon <ld.mon-1) mo=fd.mon+1; else mo=1;
			md = *gdate(yr,mo,1);
			printf(" - %s", hmname[mo-1]);
		}
		printf(" - %s", hmname[ld.mon-1]);
	}
	y = ld.year;
	if (y>0) printf(" %d A.H.\n",y); else printf(" %d B.H.\n", -y);
	printmcal(fd.dw, fd.day, ld.day, nd, md.day);
}

void
hcal(m, y)
	int  m,y;
{
	int nd, hr, min;
	float nmt;
	SDATE fd, ld;
	SDATE *dn;

	fd = *gdate(y, m, 1);
	ld = *gdate(y, m+1, 1);
	ld = *caldate(julianday(ld.year, ld.mon, ld.day, 0.0) -1.0);
	if (fd.mon == ld.mon)
		nd = ld.day - fd.day +1;
	else
		nd = ndays(fd.mon,fd.year) - fd.day + ld.day +1;


	if (hflag) {
		dn = caldate(fd.nmtime);
		nmt = 24.0*dn->time;
		hr = nmt;
		min = 60.0*(nmt-hr)+0.5;
		if (min>=60) { min=0; hr += 1;}
		printf("(New Moon on %s %s %d, %d at %02d%02d UT)\n",
			dow[dn->dw], mname[dn->mon-1], dn->day, dn->year,
			hr, min);
	}

	printf("%s ", hmname[m-1]);
	if (y>0) printf("%4d A.H.",y); else printf("%4d B.H.", -y);
	printf(" / %s", mname[fd.mon-1]);
	if (fd.year != ld.year)
		printf(" %d", fd.year);
	if (fd.mon != ld.mon)
		printf(" - %s", mname[ld.mon-1]);
	printf(" %d C.E.\n", ld.year);
	printmcal(fd.dw, fd.day, ld.day, nd, 0);
}
