package Documentix::db;
use Exporter 'import'; 
our @EXPORT_OK = qw{$dh};
$DB::single=1;

use DBI qw(:sql_types);

my $dbn    = $Documentix::config->{database_provider};
my $d_name = $Documentix::config->{database};
my $user   = $Documentix::config->{database_user};
my $pass   = $Documentix::config->{database_pass};



our $dh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass ,{sqlite_unicode => 1})
|| die "Err database connection $!";
$dh->sqlite_busy_timeout(10000);
if ( (my $ext=$Documentix::config->{database_extensions}) ) {
	$dh->sqlite_enable_load_extension(1);
	foreach (@$ext) {
		print STDERR "Load extension: $_\n";
		$dh->sqlite_load_extension( $_ ) or die "Load extension ($_)failed";
	}
}
$dh->do(q{pragma journal_mode=wal});

our $cachedh;
{
	my $dbn    = $Documentix::config->{cache_db_provider};
	my $d_name = $Documentix::config->{cache_db};
	my $user   = $Documentix::config->{cache_db_user};
	my $pass   = $Documentix::config->{cache_db_pass};

	$cachedh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass )
	|| die "Err database connection $!";
}


#
# Update search results for new documents
#TODO: moveinto worker to improve startup
sub update_caches {
    my $self = shift;
    my $dh   = $self->{"dh"};

    my @sql = (
        q{ begin exclusive transaction },
	q{ attach ":memory:" as ndb},
	q{ create table ndb.vtext as select * from vtext where docid >(select value from config where var="max_idx")},
	q{ CREATE VIRTUAL TABLE ndb.text using fts5(docid UNINDEXED,content,  content='vtext', content_rowid='rowid', tokenize = 'snowball german english')},
	q{ insert into ndb.text(rowid,docid,content)  select * from ndb.vtext},
        q{ create temporary table cache_q1 as
	    select a.*,b.docid idx,snippet(text,1,"<b>","</b>","...",10) snippet  from cache_lst a,ndb.text b
           where text match a.query and idx >
                     (select value from config where var="max_idx") ;},
	q{ create temporary table cache_q2 as select qidx,count(*) n from cache_q1 group by qidx;},
	q{ insert or replace into cache_q (qidx,idx,snippet) select qidx,idx,snippet from cache_q1;},
	q{ insert or replace into cache_lst (qidx,query,nresults,last_used) select qidx,query,nresults+n,last_used
		from cache_lst natural join cache_q2;},
	q{ insert or replace  into config (var,value) select "max_idx",max(idx) from hash;},
        q{drop table cache_q1},
        q{drop table cache_q2},
        q{drop table ndb.text},
        q{commit},
	q{ detach ndb},
    );

    foreach (@sql) {
	# print STDERR "SQL: $_\n";
        $dh->do($_) or die "Error $_";
    }

}

sub updated_idx {
    my $self=shift;
    my $idx=shift;
    my $dh   = $dh;
    print STDERR "Fixup cache for id: $idx\n";
    my @sql = (
        q{ begin exclusive transaction },
        q{ create temporary table cache_q1 as
		    select a.*,b.docid idx,snippet(text) snippet  from cache_lst a,text b
			   where text match a.query and idx = ?},
	q{ create temporary table cache_q2 as select qidx,count(*) n from cache_q1 group by qidx;},
	q{ insert or replace into cache_q (qidx,idx,snippet) select qidx,idx,snippet from cache_q1;},
	q{ insert or replace into cache_lst (qidx,query,nresults,last_used) select qidx,query,nresults+n,last_used
	from cache_lst natural join cache_q2;},
        q{drop table cache_q1},
        q{drop table cache_q2},
        q{commit},
    );

    foreach (@sql) {
	if (/\?/) {
	    $dh->do($_,undef,$idx) or die "Error $_";
	} else {
	    $dh->do($_) or die "Error $_";
	}
    }

}

sub dbmaintenance
{
	my $self=shift;
	warn "dbmaintenance";
	$dh->do("begin exclusive transaction");
	$dh->do(qq{insert into text_tmp(rowid,docid,content) 
			 select rowid,docid,content from vtext 
			 where docid>(select value from config where var='max_idx') });
	$dh->do(q{
		create temporary table cache_q1 as
			select qidx,text_tmp.docid idx,snippet(text_tmp,1,"<b>","</b>","...",4) snippet 
			       from cache_lst a,text_tmp(a.query);
		});
	$dh->do(q{
		insert or replace into cache_q(qidx,idx,snippet) select qidx,idx,snippet from cache_q1;
		});
	$dh->do(q{
		update cache_lst set 
			last_used=datetime('now'), 
			nresults=count(*) from cache_q 
		       where cache_lst.qidx in (select distinct(qidx) from cache_q1) and 
		             cache_q.qidx=cache_lst.qidx;
		});
	$dh->do(q{
		delete from text_tmp;
		});
	$dh->do(q{
		drop table cache_q1;
		});
	$dh->do(q{
		update config set value=max(idx) from hash where var="max_idx";
		});
	$dh->do(q{commit });
	return "Done";
}







print STDERR  "Db loaded\n";
1;
