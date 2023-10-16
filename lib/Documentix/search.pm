package Documentix::search;

use Exporter 'import'; 
our @EXPORT = qw{fts_search fts_loadmore};

use Documentix::db qw{dh};


# print STDERR dh,"\n";



#
my $cache_lookup = q{select qidx,nresults,hits from cache_lst where query like ?};
my $cache_setup  = q{insert or ignore into cache_lst (query,nresults) values(?,?)};

# special case only search for dates ( no matching )

sub  fts_loadmore{
	my ( $qidx, $nresults) = @_;
	my $q = dh->prepare_cached(qq{update cache_lst set nresults=? where qidx=?});
	$q->execute($nresults,$qidx);
}

sub fts_search {
    my ( $search,$slimit ) = @_;

    return undef unless $search;
   
    # Check if search is already available
    # the fts search should have a ':' in only quoted....
    # here we simply reject such queries
    # Check if we could escape it...
    dh->do("begin transaction");

    # Clean search from fts syntax.. unless quoted
    unless ( $search =~ s|^QUOTE:|| ) {
	$search =~ s/[(){}\.\;,\$]/ /gs;
	$search = "NEAR($search ,100)";
    }


    # $DB::single=1;
    my $n = dh->do( $cache_setup, undef, $search, $slimit || 100 );
    my $idx = dh->last_insert_id();  
    dh->do("commit");
    my @idx = dh->selectrow_array( $cache_lookup, undef, $search ) ;
    return @idx;

    # TODO: read acces does not trigger time-stamp...
    dh->prepare_cached( 'update cache_lst set last_used=datetime("now") where qidx=?')
		->execute( $idx );
}

