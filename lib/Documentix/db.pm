package Documentix::db;
use Exporter 'import';
our @EXPORT_OK = qw{dh};

use DBI qw(:sql_types);



my $_dh=undef;
my  $lpid=$$;

sub dh
{
	return $_dh if $_dh && $lpid == $$;

	$lpid = $$;
	my $dbn    = $Documentix::config->{database_provider};
	my $d_name = $Documentix::config->{database};
	my $user   = $Documentix::config->{database_user};
	my $pass   = $Documentix::config->{database_pass};

	$_dh=DBI->connect( "dbi:$dbn:$d_name", $user, $pass ,{sqlite_unicode => 1})
	|| die "Err database connection $!";
	$_dh->sqlite_busy_timeout(10000);
	#$_dh->{TraceLevel}="1|SQL";
	#$_dh->trace(1,"/tmp/foo.$$");
	if ( (my $ext=$Documentix::config->{database_extensions}) ) {
		$_dh->sqlite_enable_load_extension(1);
		foreach (@$ext) {
			print STDERR "Load extension: $_\n";
			$_dh->sqlite_load_extension( $_ ) or die "Load extension ($_)failed";
		}
	}
	$_dh->do(q{pragma journal_mode=wal});
	return $_dh;
}
my $cpid=undef;
my $_cachedh;
sub cachedh
{
	return $_cachedh if $cachedh && $cpid == $$;
	$cpid = $$;

	my $dbn    = $Documentix::config->{cache_db_provider};
	my $d_name = $Documentix::config->{cache_db};
	my $user   = $Documentix::config->{cache_db_user};
	my $pass   = $Documentix::config->{cache_db_pass};

	$_cachedh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass,{sqlite_unicode => 1})
	|| die "Err database connection $!";
	$_cachedh->do(q{pragma journal_mode=wal});
	return $_cachedh;;
}

1;
