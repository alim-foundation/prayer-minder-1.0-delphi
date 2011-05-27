/*   praytime.c (Version 2.1)
 *
 * Program to compute Islamic prayer hour schedules.
 * This program is a modified version of Kamal Abdali's "praytimer"
 * which produces TeX code for the schedule on the standard output.
 * "praytimer" includes the following notice:
 *
 *  Copyright (c) 1987--1992 Kamal Abdali
 *
 *  Permission for nonprofit use of this software and its documentation 
 *  is hereby granted without fee, provided that the above copyright notice 
 *  appear in all copies and that both that copyright notice and this 
 *  permission notice appear in supporting documentation, and that the name 
 *  of Kamal Abdali not be used in advertising or publicity pertaining to 
 *  distribution of the software without specific, written prior permission.  
 *
 *
 * Modified by Waleed A. Muhanna (wmuhanna@magnus.acs.ohio-state.edu) to 
 * improve input checking, remove all TeX related stuff, allow a default 
 * location to be easily configured in, and permit the user to print a 
 * schedule for the current date or a specified month and year.
 *
 * Please send any comments/suggestions/fixes/additions to 
 *              wmuhanna@magnus.acs.ohio-state.edu
 *
 */

#include        <sys/types.h>
#include        <math.h>
#include        <stdio.h>
#include        <time.h>
#include        <stdlib.h>
#include        "hconv.h"

/*
 * The program generates Islamic prayer time schedules for any
 * location.  If no argument is given, the prayer time schedule
 * for the current date at the current (configured) location is
 * produced.  If a year is specified, the program outputs a schedule
 * for the entire year.  The year can be between 1900 and 2200, or 0
 * for a "perpetual" schedule.  If a month is also specified, a schedule 
 * just for that month is printed. 
 *
 * The following command line arguments control the calculation method:
 *
 * -a angle     Sun's angle of depression at Fajr in degrees (usually 18)
 * -t time      Time interval from Fajr to sunrise in minutes (usually 90)
 * -f fiqh      Value should be S(hafii) or H(anafi)
 * -r ratio     Shadow ratio at Asr. (Usually 1 for SHafii, 2 for others)
 *
 * NOTE: It is an error to specify both -a and -t or both -f and -r.
 * DEFAULT is as if called with "-a 18 -r 1"
 * 
 * To generate schedules for locations other than the default (configured)
 * location, the following command line option should be indicated.
 *
 * -i           reads name and geographical data for the location from
 *              the standard input, instead of using the default (configured)
 *              location.  If standard input is a terminal, the program 
 *              prompts the user for the values.
 *
 * Data on standard input must contain (in given order)
 *   Name of location (upto 40 caharacters) 
 *   Latitude degrees and minutes, and N or S to specify north or south
 *   Longitude degrees and minutes, and E or W to specify east or west
 *   Time Zone in hours (Decimal for fractional hour zones, negative if
 *       West of Greenwich)
 *   Y or 1 if Daylight Saving Time adjustment needed.  N or 0, otherwise.
 *
 * Data items should be separated by whitespace, but the name must be on
 * a separate line by itself because it may contain spaces or punctuation.
 *
 * Input may contain data for more than one location.
 * An interactive session may be ended by typing the End-of-File character
 *   (e.g. CTRL-D in UNIX) when prompted for Name. 
 */


#ifndef PTLOC
#define PTLOC "Makkah Al-Mukarramah  21 25 N   39 49 E   3 N"
#endif


#define MAXNAMEL 40
#define DPR     (57.29577951308230876799)/* degree per radian (180/pi) */
#define RPD     (0.01745329251994329577) /* radians per degree (pi/180) */
#define HPR     (3.81971863420548805845) /* hours per radian (12/pi) */
#define FABS(a)         ((a) > 0 ? (a) : -(a))
#define FMOD(a,b)       ((a) - floor( (a)/(b) ) * (b))
#define MAXENV 9

short   getData(/* short interactive */);
int     parseline(/* char* line, argv*/);
void    makeSchedule (/* void */);

void    computeHours(/* short first, short last */);
void    computeConstants(/* short year */);
double  qibla(/* void */);
double  noontime(/* short nday, double* coaltn */);
double  tempus(/* short nday, double coalt, double time0 */);
void    dayLight(/* short* leap, short hasDayLt,
		    short* begin, short* finish */);

void    usage(/* void */);
void    derror(/* char *s */);
void    header(/* void */);
void    display(/* short first, short last, short startdate */);

double  deg2rad(/* double degree */);
double  dm2deg(/* short degree, short minute */);
double  dms2deg(/* long degree, short min, double sec */);
void    deg2dm(/* double degree, short* deg, short* min */);
double  hms2h(/* short hour, short min, double sec */);

char    *progname, *msname[12]= {
	"J A N U A R Y", "F E B R U A R Y", "M A R C H", "A P R I L",
	"M A Y", "J U N E", "J U L Y", "A U G U S T", "S E P T E M B E R",
	"O C T O B E R", "N O V E M B E R", "D E C E M B E R" };
char    *dowl[]= { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};

char    dir[4] = {'E', 'W', 'N', 'S'};
short   leap, beginDayLight, endDayLight; 
short   latd, latm, longd, longm, latIsS, longIsW, 
	fajrByInterval, fajrByMaxInterval;
float   tim[366][8];
double  asrShadowRatio, fajrInterval, fajrDepr;
double  cosobl, sinobl, perigee, dmanom, anom0;
double  c1, c2, delsid, sidtm0;
char *envv, *enva[MAXENV];
short EnvDef =0;
SDATE   hd;

char    ptlocv[] = PTLOC;
char    name[MAXNAMEL+2];
double  latitude,  longitude, timeZone;
short   hasDayLt;
short   hflag=0; 
int stdow;


main(argc, argv)
	int     argc;
	char    *argv[];
{
	register char *cp;
	short   optA = 0, optF = 0, optR = 0, optT = 0, optM = 0,
		inputgdata = 0, interactive =0;
	short day=0, month=0, year;
	char    fiqh = 'S';
	double  ratio = 1.0, depr = 18.0, intvl = 90.0;
	char longc, latc, dlc;
	
	extern double   atof(/* const char* s */); 
	extern time_t time();
	struct tm *tm;
	time_t t;

	fajrByMaxInterval = 0; fajrByInterval = 0; fajrInterval = 1.5;
	fajrDepr = 18.0; asrShadowRatio = 1.0;

	progname = *argv++; argc--; 
	while(argc>0 && **argv == '-') {
			cp = *argv +1;
			switch(*cp++) {
				case 'i': /* Input Geographic Data */
					inputgdata = 1;
					break;
				case 'a': /* Sun's depression angle at Fajr 
					     in degrees */
					if (*cp=='\0')
						if (argc>1) {
							cp = *++argv; argc--;
						} else usage();
					depr = atof(cp); optA = 1;
					break;
				case 't': /* Fixed time interval from Fajr to 
					     Sunrise */
					if (*cp=='\0')
						if (argc>1) {
							cp = *++argv; argc--;
						} else usage();
					intvl = atof(cp); optT = 1;
					break;
				case 'm': /* Maximum time interval from Fajr to 
					     Sunrise */
					if (*cp=='\0')
						if (argc>1) {
							cp = *++argv; argc--;
						} else usage();
					intvl = atof(cp); optM = 1;
					break;
				case 'r':  /* Shadow ratio at 'Asr */
					if (*cp=='\0')
						if (argc>1) {
							cp = *++argv; argc--;
						} else usage();
					ratio = atof(cp); optR = 1;
					break;
				case 'f': /* Fiqh for 'Asr. Value to be 
					     H(anafi) or S(hafii) */
					if (*cp) fiqh = *cp;
					else if (argc>1) {
						fiqh = **++argv; --argc;
					} else usage();
					if (fiqh != 'H' && fiqh != 'S') {
						fprintf(stderr, "%s: command \
line arg -f must have value H(anafi) or S(hafii)\n", progname);
						usage();
					}
					/* Set 'Asr shadow ratio according to
					   the chosen fiqh: 1 for S, 2 for H */
					ratio = (fiqh == 'S' ? 1.0 : 2.0);
					optF = 1; 
					break;
				case 'h': /* Hijri dates */
					hflag++;
					break;
				default:
					usage();
				
			}
			argc--, argv++;
	}
	if (optF && optR) {
		fprintf(stderr, "%s: invalid command line arg combination (can't have both -f and -r)\n", progname);
		usage();
	}  
	if (optF || optR) asrShadowRatio = ratio;
	if (optA && optT) {
		fprintf(stderr, "%s: invalid command line arg combination (can't have both -a and -t)\n", progname);
		usage();
	}
	if (optM && optT) {
		fprintf(stderr, "%s: invalid command line arg combination (can't have both -m and -t)\n", progname);
		usage();
	}
	if (intvl<=0) {
		fprintf(stderr, "%s: invalid Fajr time interval specified.\n",
			progname);
		usage();
	}
	if (optT) {
		fajrByInterval = 1; fajrInterval = intvl/60.0;
	} 
	if (optM) {
		fajrByMaxInterval = 1; fajrInterval = intvl/60.0;
	} 
	if (optA) {
		fajrByInterval = 0; fajrDepr = depr;
	} 

	if (argc == 0) {
		t = time((time_t *)0);
		tm = localtime(&t);
		day = tm->tm_mday;
		month = tm->tm_mon+1;
		year = 1900 + tm->tm_year;
		if (hflag) hd = *hdate(year,month,day);
	} else if (argc <= 2) {
		if (argc==2) {
			month = atoi(argv[0]);
			if (month<=0 || month>12) usage();
			year = atoi(argv[1]);
		} else  {
			if (!isdigit(*argv[0])) usage();
			year = atoi(argv[0]);
		}
		if (hflag !=0) {
		      if (year < 1318 || year > 1625) usage();
		} else 
		      if (year != 0 && (year < 1900 || year > 2200)) usage();
	} else usage();

	if (inputgdata) {
		interactive = isatty(fileno(stdin));
		while (getData(interactive)) makeSchedule(day,month,year);
	} else {
		/* get values from the environment var (if defined) */

		if ((envv = getenv("PTLOC")) != NULL) 
			EnvDef = 1;
		else 
			envv = ptlocv;

		if (parseline(envv, enva, MAXENV) != MAXENV) 
			derror("parameter(s) missing.");
		
		strncpy(name, enva[0], MAXNAMEL);
		latd = atoi(enva[1]); latm = atoi(enva[2]);
		latc = enva[3][0];
		if (latd<0 || latd>90 || latm<0 || latm>59 ||
		    (latc != 'N' && latc != 'n' && latc != 'S' && latc != 's'))
			derror("Illegal data for geographical latitude!");
		latIsS = latc == 'S' || latc == 's';

		longd = atoi(enva[4]); longm = atoi(enva[5]);
		longc = enva[6][0];
		if (longd<0 || longd>180 || longm<0 || longm > 59 || 
		 (longc != 'E' && longc != 'e' && longc != 'W' && longc != 'w'))
			derror("Illegal data for geographical longitude!");
		longIsW = longc == 'W' || longc == 'w';

		timeZone = atof(enva[7]);
		if (timeZone <= -12.0 || timeZone > 12.0)
			derror("Illegal data for time zone!");

		dlc = enva[8][0];
		if (dlc != 'Y' && dlc != 'y' && dlc != 'N' && dlc != 'n' &&
		    dlc != '1' && dlc != '0')
			derror("Illegal data for daylight saving time!");
		hasDayLt = dlc == 'Y' || dlc == 'y' || dlc == '1';

		
		latitude = deg2rad(dm2deg(latd,latm));
		if (latIsS) latitude = - latitude;
		longitude = deg2rad(dm2deg(longd,longm));
		if (!longIsW) longitude = - longitude;
		
		makeSchedule(day,month,year);
	       
	};
	exit(0);
}

void usage() 
{
	fprintf(stderr, "Usage: %s [-i] [-f fiqh] [-r ratio] [-a angle] \
[-t time] [-m time] [-h]  [[month] year]\n", progname);
	exit(1);
}


void derror(s)
char *s;
{
	if (EnvDef) 
		fprintf(stderr, "Invalid PTLOC environment variable.\n");
	else
	     fprintf(stderr, 
		"Invalid PTLOC configuration variable compiled in.\n");
	fprintf(stderr, "%s\n", s);
	exit(1);
}

int parseline(line, argv, maxargv) 
char *line;
char *argv[];
int maxargv;
{
	int argc=0;
	char ch;

	while (argc <maxargv) {
		/* skip whitespece */
		while ((ch = *line) != '\0' && (ch == ' ' || ch == '\t'))
			line++;
		if (ch == '\0') break;
		argv[argc++] = line;
		if (argc==1) {
			while ((ch = *line) != '\0' && (ch < '0' || ch > '9'))
				line++; line--;
		} else
			while ((ch = *line) != '\0' && ch != ' ' && ch != '\t')
				line++;
		if (ch == '\0') break;
		*line = '\0'; line++;
	}
	return(argc);
}

		

/*
 *  Obtain name and geographical data for the location for which
 *  the schedule is desired.  If INTERACTIVE is true, then
 *  the user is prompted for the info at the terminal.
 *  Otherwise, the info is obtained from the standard input.
 *  Note: time data and values to control the calculation method are
 *  to be given as command line arguments, not as input.
 */

short getData(interactive)
	short   interactive;
{
	short   maxNameLength, chCount, badData;
	char    str[82];
	int     ch;
	
	maxNameLength = MAXNAMEL;
	if (interactive) /* Data to be read from terminal */
		fprintf(stderr, "Location name (%2d chars or less)? ", 
			maxNameLength);
	chCount = 0;
	/* Read Name.  First skip over leading whitespaces */
	while ((ch = getchar()) != EOF &&
	       (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'));
	if (ch == EOF) return(0);
	name[chCount++] = ch;
	while (--maxNameLength > 0 && (ch = getchar()) != EOF 
	       && ch != '\n' && (ch < '0' || ch > '9')) name[chCount++] = ch;
	if (ch >= '0' && ch <= '9') ungetc(ch, stdin);
	name[chCount++] = '\0';
	do {
		if (interactive) 
			fprintf(stderr, "Latitude (degrees minutes N/S)? ");
		badData = scanf("%hd", &latd) !=1 || scanf("%hd", &latm)!=1; 
		if (scanf("%s", str) == EOF) return(0); ch = str[0];
		badData = badData || latd<0 || latd>90 || latm<0 || latm>59 ||
			  (ch != 'N' && ch != 'n' && ch != 'S' && ch != 's');
		if (badData) {
		   fprintf(stderr, "Illegal data for geographical latitude!\n");
		   if (!interactive) return(0);
		}
	} while (badData);
	latIsS = ch == 'S' || ch == 's';
	do {
		if (interactive) 
			fprintf(stderr, "Longitude (degrees minutes E/W)? ");
		badData = scanf("%hd", &longd) !=1 || scanf("%hd", &longm)!=1; 
		if (scanf("%s", str) == EOF) return(0); ch = str[0];
		badData = badData || longd<0 || longd>180 || longm<0 || 
			  longm > 59 ||
			  (ch != 'E' && ch != 'e' && ch != 'W' && ch != 'w');
		if (badData) {
		  fprintf(stderr, "Illegal data for geographical longitude!\n");
		  if (!interactive) return(0);
		}
	} while (badData);
	longIsW = ch == 'W' || ch == 'w';
	do {
		if (interactive) 
		   fprintf(stderr,
			"Time Zone in hours (negative if West of Greenwich)? ");
		if (badData = (scanf("%lf", &timeZone) != 1 ||
				  timeZone <= -12.0 || timeZone > 12.0)) {
			fprintf(stderr, "Illegal data for time zone!\n");
			if (!interactive) return(0);
		}
	} while (badData);
	do {
		if (interactive) fprintf(stderr, "Adjust for daylight saving time (Y/N)? ");
		while ((ch = getchar()) != EOF && 
			(ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'));
		if (ch == EOF) return(0);
		if (badData = (ch != 'Y' && ch != 'y' &&
		     ch != 'N' && ch != 'n' &&
		     ch != '1' && ch != '0')) {
			fprintf(stderr, "Illegal data for daylight saving time!\n");
			if (!interactive) return(0);
		}
	} while (badData);
	hasDayLt = ch == 'Y' || ch == 'y' || ch == '1';

	latitude = deg2rad(dm2deg(latd,latm));
	if (latIsS) latitude = - latitude;
	longitude = deg2rad(dm2deg(longd,longm));
	if (!longIsW) longitude = - longitude;
	return(1);
}

/*
 * Computes day number (first is 0) in the year.
*/
short daynum(d,m,y)
	short d,m,y;
{
	register short  i, dn;

	i=1; dn= --d;
	while (i<m) dn += ndays(i++,y);
	return(dn);
}

void mnthheader(month,year)
	short month,year;
{
	month--;
	printf("\n\n\t\t%s\n", hflag==0 ? msname[month] : hmname[month]);
	if ( year==0 && hasDayLt!=0 && (month==3 || month==9)) { 
		printf("(*Subtract one hour from all times ");
		if (month==3)
		    printf("before first Sunday*)\n");
		else /* month==9 */
		    printf("starting on last Sunday*)\n");
	}
}

void setdow(y,m,d)
short   y,m,d;
{
	stdow = ((long) (julianday(y,m,d, 0.0) + 1.5)) % 7;
}

void hschedule(m,y)
	short m,y;
{
	SDATE fd, ld;
	short   cd, cm, ndays0, ndays1, sd=1, dh=1; 
	
	mnthheader(m,y); 
	
	fd = *gdate(y,m,1);  
	ld = *gdate(y, m+1, 1);
	ld = *caldate(julianday(ld.year, ld.mon, ld.day, 0.0) - 1.0);
	
	ndays0 = daynum(fd.day, fd.mon, fd.year);
	setdow(fd.year,fd.mon,fd.day);
	cd = fd.day; cm = fd.mon;
	if (fd.mon != ld.mon) {        
		ndays1 = daynum(ndays(fd.mon,fd.year), fd.mon, fd.year) +1;
		computeHours(fd.year,ndays0,ndays1);
		display(ndays0, ndays1,sd,cd,cm, dh--); 
		sd = ndays1 - ndays0 + 1;
		ndays0 = daynum(1, ld.mon, ld.year);
		cd = 1; cm = ld.mon;
	}
	ndays1 = daynum(ld.day, ld.mon, ld.year) + 1;
	computeHours(ld.year,ndays0,ndays1);
	display(ndays0,ndays1, sd, cd, cm, dh);
}


/*
 * Schedule computation section.
 * Prayer hours are computed basically following the algorithms given in
 * "Prayer Schedules for North America", American Trust Publications, 
 * Indianapolis, Indiana, 1978, Appendices A and B.
 *
 */

void makeSchedule(day,month,year)
	short day,month,year;
{
	register short  i;
	short   ndays0, ndays1;
	
	header(day,month,year); 
  
	if (day !=0) {
		ndays0 = daynum(day,month,year); 
		ndays1 = ndays0 +1;
		computeHours(year,ndays0,ndays1);
		setdow(year,month,day);
		display(ndays0,ndays1, hflag ? hd.day : day,day,month,1);
	} else if (month !=0) {
		if (!hflag) {
			mnthheader(month,year); 
			ndays0 = daynum(1,month,year);
			ndays1 = ndays0+ndays(month,year);
			computeHours(year,ndays0,ndays1);
			setdow(year,month,1);
			display(ndays0, ndays1, 1,0, 0, 1);
		} else hschedule(month,year);
	} else {
		if (!hflag) {
			computeHours(year,0,365+leap);
			ndays0 = 0;
			setdow(year,1,1);
			for (i=1; i<13; i++) {
				mnthheader(i,year);
				ndays1 = ndays0+ndays(i,year);
				display(ndays0,ndays1,1,0, 0, 1);
				ndays0 = ndays1;
			}
		} else for (i=1; i<13; i++) hschedule(i,year);
	}
	printf("\n\n");
}

/* 
 * Computes times for range of days first..last-1.
 */ 

void computeHours(year, first, last) 
	short   year,first,last;
 {
	double  coaltn,time0[6],coalt[6];
	register double t;
	register short  i,k,l;
    
	
	/* For perpetual, use 1994. (Need middle year of 4-year leap cycle */
	computeConstants(year==0 ? 1994 : year);  

	/*  find beginning and ending days for daylight saving time */
	dayLight(year, &leap, hasDayLt, &beginDayLight, &endDayLight);


	/* Approximate times of fajr,shuruq,asr,maghrib,isha */
	time0[0] = 4.0;
	time0[1] = 6.0;
	time0[3] = 15.0;
	time0[4] = 18.0;
	time0[5] = 20.0;
	/* Coaltitudes of sun at fajr,shuruq,maghrib,isha */
	coalt[0] = deg2rad((double)(90+fajrDepr));
	coalt[1] = deg2rad(90.83);
	coalt[4] = coalt[1];
	coalt[5] = coalt[0];
	/* Get approximate times for the first day specified. */
	/* Later on, each day's times used as approximate times for next day */
	t = noontime(first,&coaltn);
	coalt[3] = atan(asrShadowRatio+tan(coaltn));
	time0[1] = (((t = tempus(first,coalt[1],time0[1])) < 24.0) ? t : 6.0);  
	time0[3] = (((t = tempus(first,coalt[3],time0[3])) < 24.0) ? t : 15.0);  
	time0[4] = (((t = tempus(first,coalt[4],time0[4])) < 24.0) ? t : 18.0);
	if (fajrByInterval) {
		time0[0] = time0[1] - fajrInterval;  
		time0[5] = time0[4] + fajrInterval;
	} else {  
		time0[0] = (((t = tempus(first,coalt[0],time0[0])) < 24.0) ? t : 4.0);  
		time0[5] = (((t = tempus(first,coalt[5],time0[5])) < 24.0) ? t : 20.0);
	}         
/*  compute times for the whole range of days */
	for (l=first, i=1; l<last; i++, l++) {
/*  for perpetual calendar, february 29 and march 1 have same times */
		k = l;  
		if (l>59 && year==0) k = l-1;
		tim[l][2] = noontime(k+1,&coaltn);
		coalt[3] = atan(asrShadowRatio+tan(coaltn));
		time0[1] = (((tim[l][1] = t = tempus(k+1,coalt[1],time0[1]))
			    < 24.0) ? t : 6.0);
		time0[3] = (((tim[l][3] = t = tempus(k+1,coalt[3],time0[3]))
					< 24.0) ? t : 15.0);  
		time0[4] = (((tim[l][4] = t = tempus(k+1,coalt[4],time0[4]))
					< 24.0) ? t : 18.0);
		if (fajrByInterval) {
			tim[l][0] = time0[0] = time0[1] - fajrInterval;  
			tim[l][5] = time0[5] = time0[4] + fajrInterval;
		} else {  
			time0[0] = (((tim[l][0] = t = tempus(k+1,coalt[0],time0[0]))
					< 24.0)  ? t : 4.0);
			time0[5] = (((tim[l][5] = t = tempus(k+1,coalt[5],time0[5]))
					< 24.0) ? t : 20.0);
		}         
	}
/*  correct for daylight saving time (if necessary) */
	if (endDayLight !=0 && first<endDayLight) {
		i = beginDayLight-1;
		if (first>i) i=first;
		while (i<endDayLight && i<last) {
			for (k=0; k<6; k++) tim[i][k] += 1.0;
			i++;
		}
	}
}

/* 
 * Computes astro constants for Jan 0 of given year 
 */

void computeConstants(year)
	short   year;
{

/*  ndays = time from 12 hr(noon), Jan 0, 1900 to 0 hr, Jan 0 of year */
/*  t = same in julian centuries (units of 36525 days) */
/*  obl = obliquity of ecliptic */
/*  perigee = sun's longitude at perigee  */
/*  eccy = earth's eccentricity */
/*  dmanom,delsid = daily motion (change) in */
/*                        sun's anomaly, sidereal time */
/*  anom0,sidtm0 = sun's mean anomaly, */
/*              sidereal time, all at 0 hr, jan 0 of year year */
/*  c1,c2 = coefficients in equation of center */

	register double         t;
	long                            ndays;
	double                          obl, eccy;
	
	ndays = ((long) (year-1900))*365+(year-1901)/4;
	t = (ndays-0.5)/36525.0;
	obl = deg2rad(dms2deg(23L,27,8.26)-dms2deg(0L,0,46.845)*t);
	cosobl = cos(obl);
	sinobl = sin(obl);
	eccy = 0.01675104-4.180e-5*t-1.26e-7*t*t;
	perigee = deg2rad(FMOD(dms2deg(281L,13,15.0)+dms2deg(1L,43,9.03)*t+
			  dms2deg(0L,0,1.63)*t*t,360.0));
	dmanom = deg2rad(dms2deg(35999L,2,59.10)/36525.0);
	anom0 = deg2rad(FMOD(dms2deg(358L,28,33.0)-dms2deg(0L,0,0.54)*t*t+
			FMOD(dms2deg(35999L,2,59.10)*t,360.0),360.0));
	delsid = hms2h(2400,3,4.542)/36525.0;
	sidtm0 = FMOD(hms2h(6,38,45.836)+FMOD(hms2h(2400,3,4.542)*t,24.0),24.0);
	c1 = eccy*(2-eccy*eccy/4);
	c2 = 5*eccy*eccy/4;
}

/*
 *  Double-duty function for leap year and Daylight Saving dates info.
 *  Finds whether year is leap (sets leap = 1 if yes, 0 if no). 
 *  If hasDayLt is non-zero, then also computes the day numbers of the 
 *  start and end of Daylight Savings Time. 
 *  Sets begin = Day no. of the first Sunday of April, and 
 *      finish = Day no. of the Saturday before the last Sunday of October. 
 */

void dayLight(year, leap, hasDayLt, begin, finish)
	short   year;
	short*  leap;
	short   hasDayLt;
	short*  begin;
	short*  finish;
{
	short m4,m1,jan0,napr1,noct31,apr1,oct31;
	
	m4 = year%400;
	m1 = year%100;
	*leap = (year%4 == 0 && m1 != 0) || m4 == 0;
	if (hasDayLt==0) {
	/* No adjustment for Daylight Saving Time (year zero for perpetual) */
		*begin = 367;
		*finish = 0;
		return;
	}
	if (year==0) {
	/* Daylight Saving Time in perpetual calendar. April 1 thru Oct 31 */
		*begin = 92; /* April 1, 31+29+31+1 */
		*finish = *begin+213; /* Oct 31, -1+30+31+30+31+31+30+31 */
		return;
	}
	/* Non-zero year. for annual calendar */
	/* jan0,apr1,oct31 = day of week on those dates (fri=0,sat=1,sun=2,...) */
	/* napr1,noct31 = Day no. in year on those dates */
	jan0 = (m4/100*124+1+m1+m1/4-*leap) % 7;
	napr1 = 91 + *leap; /* 31+28+*leap+31+1 */
	noct31 = 304 + *leap; /* 365+*leap-31-30 */
	apr1 = (napr1+jan0) % 7;
	oct31 = (noct31+jan0) % 7;
	*begin = napr1+2-apr1;
	if ( *begin < napr1 ) *begin += 7;
	*finish = noct31+2-oct31;
	if ( *finish > noct31 ) *finish -= 7;
	*finish = *finish-1;
}

/*  
 * Place sun's coaltitude at noon in coaltn, 
 * and return time of noon for day no. nday of year 
 */

double noontime(nday, coaltn)
	short   nday;
	double* coaltn;
{
/*  slong =  sun's true longitude at noon */
/*  ra = sun's right ascension, decl = sun's declination */
/*  ha = sun's hour angle west */
/*  locmt = local mean time of phenomenon */

	register double t;
	double longh,days,anomaly,slong,sinslong,ra,decl,locmt;
	
	longh = longitude*HPR;
	days = nday+(12.0+longh)/24.0;
	anomaly = anom0+dmanom*days;
	slong = perigee+anomaly+c1*sin(anomaly)+c2*sin(anomaly*2);
	sinslong = sin(slong);
	ra = atan2(cosobl*sinslong,cos(slong))*HPR;
	if (ra<0.0) ra += 24.0;
	decl = asin(sinobl*sinslong);
	locmt = ra-delsid*days-sidtm0;
	t = locmt+longh+timeZone;
	if (t<0.0) t += 24.0;
	if (t>24.0) t -= 24.0;
	*coaltn = FABS(latitude-decl);
	return(t);
}

/*  
 * Returns time on day no. nday of year when sun's coaltitude is coalt.
 * If no such time, then returns a large number. 
 *    time0 is approximate time of phenomenon 
 */

double tempus(nday, coalt, time0)
	short   nday;
	double  coalt;
	double  time0;
{
/*  slong =  true longitude */
/*  ra = sun's right ascension, sindcl = sin(sun's declination) */
/*  ha = sun's hour angle west */
/*  locmt = local mean time of phenomenon */

	double longh,days,anomaly,slong,sinslong,ra,sindcl,cosha,ha,locmt;
	register double t;
	
	longh = longitude*HPR;
	days = nday+(time0+longh)/24.0;
	anomaly = anom0+dmanom*days;
	slong = perigee+anomaly+c1*sin(anomaly)+c2*sin(anomaly*2);
	sinslong = sin(slong);
	ra = atan2(cosobl*sinslong,cos(slong))*HPR;
	if (ra<0.0) ra += 24.0;
	sindcl = sinobl*sinslong;
	cosha = (cos(coalt)-sindcl*sin(latitude))/
		       (sqrt(1.0-sindcl*sindcl)*cos(latitude));
	/*  if cos(ha)>1, then time cannot be evaluated */
	if (FABS(cosha)>1.0) return(1.0e7);
	ha = acos(cosha)*HPR;
	if (time0<12.0) ha = 24.0-ha;
	locmt = ha+ra-delsid*days-sidtm0;
	t = locmt+longh+timeZone;
	if (t<0.0) t += 24.0;
	if (t>24.0) t -= 24.0;
	return(t);
}

/*
 * Returns the direction of qibla in radians. Eastward from north is positive. 
 */

double qibla()
{

	/*  lat0, long0 are Makkah's latitude and longitude in radians */
	double lat0 = 0.3739077, long0 = -0.69504828, dflong;
	
	dflong = longitude-long0;
	return( atan2(sin(dflong),
		      cos(latitude)*tan(lat0)-sin(latitude)*cos(dflong)) );
		      /*
		      cos(lat0)*tan(latitude)-sin(latitude)*cos(dflong)) );
		      */
}


/*  
 * Print title material.
 */

void header(day,month,year)
short day,month,year; 
{
	double direc;
	short qibd, qibm, zoneH, zoneM;
	char sgnlat, sgnlng, sgnzon, sgnqib;
	
	sgnlat = (latIsS ? dir[3] : dir[2]);
	sgnlng = (longIsW ? dir[1] : dir[0]);

	deg2dm(timeZone, &zoneH, &zoneM);
	sgnzon = (timeZone<0 ? '-' : '+');

	direc = qibla() * DPR;
	deg2dm(direc, &qibd, &qibm);
	sgnqib = (direc<0 ? dir[1] : dir[0]);

	if (day!=0) {
		if (hflag) printf("Today's (%s %2d, %4d) ",hmname[hd.mon-1],hd.day, hd.year);
		else printf("Today's (%s %2d, %4d) ",mname[month-1],day, year);
	} else {
		if (month!=0) printf("%s ", hflag==0 ? mname[month-1] : hmname[month-1]);
		if (year==0) printf("Perpetual "); 
		else if (!hflag) printf("%4d C.E. ",year);
		else printf("%4d A.H. ", year);
	}                   
	printf("Prayer Schedule for %s\n",name);
	printf(" Latitude = %3d %02d' %c\t", latd,latm,sgnlat);
	printf("Longitude = %3d %02d' %c\t",longd,longm,sgnlng);
	printf("Zone Time = GMT %c%2dh",sgnzon,zoneH);
	if (zoneM) printf("%3dm",zoneM);
	printf("\n\t\tQiblah = %3d %02d' %c (From N)\n", qibd,qibm,sgnqib);
}

/* 
 * Print times for range of days (in the year) first..last-1.
 * Days in month range from startdate to startdate+last-first
 */

void display(first, last, startdate, cd, cm, header)    
	short   first;
	short   last;
	short   startdate, cd, cm, header;
{
	short     hour,minute;
	double    t;
	register short  i,j,l;
	if (header) {
	  printf("\n-----------------------------------------------------------------------\n");
	  printf("              Fajr      SHorwwQ   DHuhr    `ASr       MaGHrib  `ISHaa'\n");
	  printf("Date Day      Dawn      Sunrise   Noon      Afternoon Sunset    Evening\n");
	  printf("-----------------------------------------------------------------------\n");
	}

	for (l=first, i=startdate; l<last; l++, i++) {
			printf("%2d   ",i);
			printf("%3s",dowl[stdow++]); stdow %= 7;
			for (j=0; j<6; j++) {
			       t = tim[l][j];
			       if (fajrByMaxInterval) {
				 if (j==0 && (t>360.0 || t<0.0 ||
					      (tim[l][1]-t)> fajrInterval)) 
					t = tim[l][1] - fajrInterval;
				 if (j==5 && (t>360.0 || t<0.0 ||
					      (t-tim[l][4])> fajrInterval))
					t = tim[l][4] + fajrInterval;
				}
				
				if (t>360.0) {
					printf("       *  ");
				} else if (t<0.0) {
					printf("          ");
				} else {
					/* time conversion to am and pm hours and rounded minutes */
					hour = t;  minute = 60.0*(t-hour)+0.5;
					if (minute>=60) {
						minute = 0;
						hour += 1;
					}
					if (hour>12) hour -= 12;
					printf("    %3d:%02d",hour,minute);
				}
			}
			if (hflag) printf("    %2d/%2d", cd++, cm);
			printf("\n");
		}
		
}


/*
 *  Utility functions
 *
 */

double deg2rad(degree)
	double  degree;
{
	return(degree*RPD);
}

double dm2deg(degree, minute)
	short   degree;
	short   minute;
{
	return((double) degree + minute/60.0);
}

void deg2dm(degree, deg, min)
	double  degree;
	short   *deg;
	short   *min;
{
	double dabs;
	dabs = FABS(degree);
	*deg = dabs;
	*min = 60.0*(dabs - *deg) +0.5;
	if (*min>=60) {
		*min = 0;
		*deg += 1;
	}
}

double dms2deg(degree, min, sec)
	long    degree;
	short   min;
	double  sec;
{
	return((double) degree + min/60.0 + sec/3600.0);
}

double hms2h(hour, min, sec)
	short   hour;
	short   min;
	double  sec;
{
	return((double) hour + min/60.0 + sec/3600.0);
}

