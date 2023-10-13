package Documentix::search;

use Exporter 'import'; 
our @EXPORT = qw{search};

use Documentix::db qw{dh};


print STDERR dh,"\n";

#input 
# search-string
#
# output:
# w
my $cache_lookup = q{select qidx from cache_lst where query like ?};
my $cache_setup  = q{insert or ignore into cache_lst (query) values(?)};

my $cached_search = q{insert or ignore into cache_q ( qidx,idx,snippet ) 
                                select ?,docid,snippet(text,1,"<b>","</b>","...",10) 
					from text  join hash on (docid=idx) where text match ? order by rank limit 500  };
# Extend search to include date range
my $search_date_txt = $cached_search;
   $search_date_txt =~ s/where/natural join dates where date between ? and ? and/;

# special case only search for dates ( no matching )
my $search_date = "insert or ignore into cache_q (qidx, idx, snippet) select ?,idx,mtext
			from dates where date between ? and ?";

my $date_match = qr{date[:\s*](\d\d\d\d-\d\d-\d\d)\s*\.\.\.\s*(\d\d\d\d-\d\d-\d\d)(\s*|$)};


sub search {
    my ( $search ) = @_;

    return undef unless $search;
   
    # Check if search is already available
    # the fts search should have a ':' in only quoted....
    # here we simply reject such queries
    # Check if we could escape it...
    dh->do("begin transaction");
    my $n = dh->do( $cache_setup, undef, $search );
    my $idx = dh->selectrow_array( $cache_lookup, undef, $search );
    if ( $n != 0  ) {
	    # we have a new search

	    # Arguments for search query
	    my @sargs = ( $idx, $search );
	    my $srch = dh->prepare_cached($cached_search);
    $DB::single=1;

	    # if a date-range is mentioned, fix the search sql to select the time range only
	    if ( $search && $search =~ s/$date_match//i ) {
		print STDERR "Datesearch:  $1 -- $2\n";
		# daterange specified...
		# remove range from search string and process normally
		# Search restrict to date-range ( will reduce output list )
		@sargs = ( $idx, $1, $2 );
		$srch = dh->prepare_cached($search_date);
		unless ( $search =~ /^\s*$/ ) {
		    $search =~ s/:/ /gs; # fts sees arguments ... unhappy
		    # date with text match
		    push @sargs, $search;
		    $srch = dh->prepare_cached($search_date_txt);
		}
	    }

	    # Do search
	    print STDERR "S:$cached_search\n";
	    print STDERR "A:" . join( ":", @sargs ) . ":\n";
	    my $nres = $srch->execute(@sargs);
	    print STDERR "R: $nres\n";
	    dh->do(q{delete from cache_lst where qidx=?},undef,$idx)
		    if ( $srch->err );


	    # record search results
	    dh->prepare_cached( 'update cache_lst set nresults=?,last_used=datetime("now")  where qidx=?')
		->execute( $nres, $idx );
	}
    dh->do("commit");
    return $idx;
}

