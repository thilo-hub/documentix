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

print STDERR  "Db loaded\n";
1;
