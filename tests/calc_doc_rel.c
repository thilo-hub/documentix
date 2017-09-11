#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <fcntl.h>
#include <unistd.h>
#include <wchar.h>
#include <string.h>

#ifndef MIN_SIZE
#define MIN_SIZE 100
#endif
#ifndef MIN_SIM
#define MIN_SIM 0.7
#endif



unsigned short	ctab[256 * 256];
#ifdef DUMP
unsigned short	rtab[256 * 256];
#endif
unsigned short	midx = 0;

void 
setup()
{
	for (unsigned int c1 = ' '; c1 <= 'Z'; c1++) {
		if (c1 == ' ' + 1)
			c1 = '0';
		if (c1 == '9' + 1)
			c1 = 'A';
		unsigned int c1h=c1<<8;
		unsigned int c1l=tolower(c1)<<8;
		for (unsigned int c2 = ' '; c2 <= 'Z'; c2++) {
			if (c2 == ' ' + 1)
				c2 = '0';
			if (c2 == '9' + 1)
				c2 = 'A';
#ifdef DUMP
			rtab[midx] = c1h | c2;
#endif
			ctab[c1l | (c2)] =
				ctab[c1l | (c2)] =
				ctab[c1h | (tolower(c2))] =
				ctab[c1h | (tolower(c2))] =
					midx++;
		}
	}
}

unsigned short *
calc(const char *txt)
{
#define ASIZE midx
	unsigned short *mem = calloc(sizeof(unsigned short), ASIZE);
	size_t		charlen, chars;
	mbstate_t	mbs;

	chars = 0;
	memset(&mbs, 0, sizeof(mbs));


	unsigned short	v1 = ' ' << 8;
	char		c;
	while ((charlen = mbrlen(txt, MB_CUR_MAX, &mbs)) != 0 &&
	       charlen != (size_t) - 1 && charlen != (size_t) - 2) {
		c = *txt;
		txt += charlen;
		chars++;
		unsigned short	v2 = ctab[v1 | (c&0xff)];
		if (charlen != 1)
			fprintf(stdout, "L: %ld\n", charlen);
		if (v2) {
			v1 = c << 8;
			mem[v2]++;
		}
	}
#ifdef DUMP
	static int	fn = 1;
	for (int i = 0; i < midx; i++) {
		if (mem[i])
			printf("%c%c <%d> %d\n", (rtab[i] >> 8) & 0xff, rtab[i] & 0xff, fn, mem[i]);
	}
	fn++;
#endif
	return mem;
}


void calc_junkt(unsigned short **vtabs,int n,void (*cb)(void *,double,int,int),void *arg)
{
	int		i;
	while (n-- > 0) {
		for (i = n - 1; i >= 0; i--) {
			//junktion between vtabs[i] && vtabs[n]
				int		c;
			int		pairs_a = 0, pairs_b = 0;
			int		junkt = 0;
			unsigned short *ta = vtabs[i];
			unsigned short *tb = vtabs[n];
			for (c = 0; c < midx; c++) {
				if (ta[c])
					pairs_a++;
				if (tb[c])
					pairs_b++;
				if (ta[c] && tb[c])
					junkt++;
			}
			double		sim = 2.0 * junkt / (double)(pairs_a + pairs_b);
			(*cb)(arg,sim,i,n);

		}
	}
}

#ifdef USE_FILES
void print_o(void *p,double sim,int i,int n)
{
	unsigned char **argv=p; 
	fprintf(stderr,"%2g\t%s\t %s\n", sim, argv[i + 1], argv[n + 1]);
}




int 
main(int argc, char *argv[])
{
	int		n = 0;
	unsigned short **vtabs = calloc(sizeof(unsigned short *), argc);
	setup();
	for (n = 0; n < argc - 1; n++) {
		int		fh = open(argv[n + 1], O_RDONLY);
		if (fh) {

			off_t		len = lseek(fh, 0, SEEK_END);
			if (len > MIN_SIZE) {
				char           *f = malloc(len + 1);
				lseek(fh, SEEK_SET, 0);
				read(fh, f, len);

				f[len] = 0;
				vtabs[n] = calc(f);
				fprintf(stderr, "%s %d Len: %lld\n", argv[n + 1], midx, len);

				free(f);
			}
			close(fh);
		}
	}
	calc_junkt(vtabs,n,&print_o,argv);
}
#else
#include <sqlite3.h>
#include <sys/time.h>

#define DB "doc_db.db"
#define QU "select idx,value from metadata where tag='Text'"
#define QU_MAX "select count(*) from metadata where tag='Text'"
#define INS_RES "insert into simidx (lvl,aidx,bidx) values(?,?,?)"

#define MK_SIM "create table if not exists simidx (lvl REAL,aidx INT,bidx INT,foreign key(aidx) references hash(idx),foreign key(bidx) references hash(idx))"

#define RV_CHECK(rval) do { int rx=rval;\
	if ( rx != SQLITE_OK ) { \
		fprintf(stderr,"Err: line:%d  %d:(%s)\n",__LINE__, rx,sqlite3_errmsg(pdb)); \
		exit(1); \
	}\
	} while(0)

#define DO_SQL(sql) RV_CHECK(sqlite3_exec(pdb,sql,NULL,NULL,NULL))

#define BEGIN_TRANS  DO_SQL("begin transaction")
#define COMMIT_TRANS  DO_SQL("commit")


sqlite3 *pdb;
sqlite3_stmt *ppins;
time_t t0=0;
time_t tn=0;
int cnt=0;

void out_o(void *p,double sim,int i,int n)
{
	sqlite3_int64 *tab=p;
	int rv;
	cnt++;
	if ( sim > MIN_SIM ) 
	{
		struct timeval rp;
		gettimeofday(&rp,NULL);
		if ( rp.tv_sec > tn ) {
			tn=rp.tv_sec+4;
			printf("(%ld %d %6g/sec) %2.4g\t%lld\t %lld\n",rp.tv_sec-t0,cnt,(double)cnt/(rp.tv_sec-t0),sim,tab[i+1],tab[n+1]);
		}
		rv = sqlite3_bind_double(ppins, 1, sim);
		RV_CHECK(rv);
		rv = sqlite3_bind_int64(ppins, 2, tab[i]);
		RV_CHECK(rv);
		rv = sqlite3_bind_int64(ppins, 3, tab[n]);
		RV_CHECK(rv);
		rv = sqlite3_step(ppins);
		if ( rv != SQLITE_DONE) RV_CHECK(rv);
		rv = sqlite3_reset(ppins);
		RV_CHECK(rv);
	}

}





int main(int argc,char *argv[])
{
	sqlite3_stmt *ppStmt;  /* OUT: Statement handle */
	sqlite3_int64 *tab;
	unsigned short **vtabs;
	int n_res;
	const char *db=DB;
	if ( argc > 1 )
		db= argv[1];

	fprintf(stderr,"Use: %s\n",db);



	struct timeval rp;
	gettimeofday(&rp,NULL);
	t0=rp.tv_sec;

	setup();

	int rv=sqlite3_open( db, &pdb);
	RV_CHECK(rv);


	rv = sqlite3_prepare_v2( pdb, QU_MAX, -1, &ppStmt, NULL);
	RV_CHECK(rv);
	if( (rv = sqlite3_step(ppStmt)) == SQLITE_ROW )  {
		sqlite3_int64 res_count=sqlite3_column_int64(ppStmt,0);
		fprintf(stderr,"Returned: %lld results\n",res_count);
		n_res=res_count;
		tab=calloc(sizeof(sqlite3_int64),n_res);
	}
	rv= sqlite3_finalize(ppStmt);
	RV_CHECK(rv);

	vtabs = calloc(sizeof(unsigned short *),n_res);
	if ( vtabs == NULL ) {
		fprintf(stderr,"Out of mem\n");
		exit(1);
	}

	rv = sqlite3_prepare_v2( pdb, QU, -1, &ppStmt, NULL);
	RV_CHECK(rv);


	int n=0;
	while( (rv = sqlite3_step(ppStmt)) == SQLITE_ROW ) 
	{
		sqlite3_int64 idx=sqlite3_column_int64(ppStmt,0);
		const unsigned char *text=sqlite3_column_text(ppStmt,1);
		int tlen=sqlite3_column_bytes(ppStmt,1);
		printf("Idx: %lld tlen: %d\n",idx,tlen);
		if ( tlen > MIN_SIZE ) {
			vtabs[n] = calc((const char *)text);
			tab[n]=idx;
			n++;
		}
	}
	if ( rv != SQLITE_DONE ) RV_CHECK(rv);
	rv= sqlite3_finalize(ppStmt);
	RV_CHECK(rv);
//  ================================

	BEGIN_TRANS;
	DO_SQL(MK_SIM);
	rv = sqlite3_prepare_v2( pdb, INS_RES, -1, &ppins, NULL);
	RV_CHECK(rv);

	calc_junkt(vtabs,n,&out_o,tab);

	rv= sqlite3_finalize(ppins);
	RV_CHECK(rv);
	COMMIT_TRANS;
	gettimeofday(&rp,NULL);
	tn=rp.tv_sec+4;
	printf("FINISH (%ld %d %6g/sec)\n",rp.tv_sec-t0,cnt,(double)cnt/(rp.tv_sec-t0));
//=======================
	rv= sqlite3_close(pdb);
	RV_CHECK(rv);
}
#endif
