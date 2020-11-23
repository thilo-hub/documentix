package Documentix::db;
use Exporter 'import'; 
our @EXPORT_OK = qw{$dh dbmaintenance};

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


sub dbmaintenance
{
	my $self=shift;
	printf STDERR  "dbmaintenance\n";
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