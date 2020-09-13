package ld_r;

use strict;
use warnings;
use Data::Dumper;
use Cwd 'abs_path';
use POSIX;
use JSON;
use Sys::Hostname;
use Date::Parse;

use MyApp::Docconf;
use doclib::pdfidx;

print STDERR ">>> ld_r.pm\n" if $Docconf::config->{debug} > 2;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $__meta_sel;
my $entries = $Docconf::config->{results_per_page};

my $myhost = hostname();

my $ANY = "*ANY*";

my $cached_search = q{insert or ignore into cache_q ( qidx,idx,snippet ) 
                                select ?,docid,snippet(text,1,"<b>","</b>","...",10) 
					from text  join hash on (docid=idx) where text match ? order by rank  };

# Extend search to include date range
my $search_date_txt = $cached_search;
   $search_date_txt =~ s/where/natural join dates where date between ? and ? and/;

# special case only search for dates ( no matching )
my $search_date = "insert or ignore into cache_q (qidx, idx, snippet) select ?,idx,mtext
			from dates where date between ? and ?";



sub new {
    my $class  = shift;
    my $chldno = shift;

    my $self = {};
    $self->{pd} = pdfidx->new($chldno,$MyApp::config);
    $self->{dh} = $self->{pd}->{dh};
    setup_db( $self->{dh} );
    print STDERR "Child number:$chldno\n" if $Docconf::config->{debug} > 2;
    update_caches($self) unless $chldno;
    return bless $self, $class;
}

#
# Update search results for new documents
sub update_caches {
    my $self = shift;
    my $dh   = $self->{"dh"};

    my @sql = (
        q{ begin exclusive transaction },
        q{ create table if not exists config (var primary key unique,value)},
	q{delete  from cache_lst where  ((length(query)-length(replace(query,"'","")))%2 == 1)},
        q{ delete from cache_lst where query like '%...%' },
        q{ create temporary table cache_q1 as
    select a.*,b.docid idx,snippet(text,1,"<b>","</b>","...",10) snippet  from cache_lst a,text b
           where text match a.query and idx >
                     (select value from config where var="max_idx") ;},
q{ create temporary table cache_q2 as select qidx,count(*) n from cache_q1 group by qidx;},
q{ insert or replace into cache_q (qidx,idx,snippet) select qidx,idx,snippet from cache_q1;},
q{ insert or replace into cache_lst (qidx,query,nresults,last_used) select qidx,query,nresults+n,last_used
	from cache_lst natural join cache_q2;},
q{ insert or replace  into config (var,value) select "max_idx",max(idx) from hash;},
        q{drop table cache_q1},
        q{drop table cache_q2},
        q{commit},
    );

    foreach (@sql) {
	#print STDERR "SQL: $_\n";
        $dh->do($_) or die "Error $_";
    }

}

sub updated_idx {
    my $self=shift;
    my $idx=shift;
    my $dh   = $self->{"dh"};
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

sub trace_db {
    my $dh = shift;
    open( TRC, ">>/tmp/db.trace" );

    sub trace_it {
        my $r = shift;

        print TRC "DB: $r\n";
    }

    $dh->sqlite_trace( \&trace_it );
}

sub setup_db {
    my $dh = shift;
    $dh->do(
q{ create table if not exists cache_lst ( qidx integer primary key autoincrement,
			query text unique, nresults integer, last_used integer )}
    );
    $dh->do(
q{ create table if not exists cache_q ( qidx integer, idx integer, snippet text, unique(qidx,idx))}
    );

    $dh->do(
        q{
		CREATE TRIGGER if not exists cache_del before delete on cache_lst begin delete
			from cache_q where cache_q.qidx = old.qidx ;
		end;
		}
    );
}

my $cache_lookup = q{select qidx from cache_lst where query = ?};
my $cache_setup  = q{insert or ignore into cache_lst (query) values(?)};

sub search {
    my ( $self, $search ) = @_;
    my $dh = $self->{"dh"};

    return undef unless $search;
   
    # Check if search is already available
    $dh->do("begin transaction");
    # the fts search should have a ':' in only quoted....
    # here we simply reject such queries
    # Check if we could escape it...
    return undef if $search =~ m/:/; 
    my $n = $dh->do( $cache_setup, undef, $search );
    my $idx = $dh->selectrow_array( $cache_lookup, undef, $search );
$DB::single = 1;
    if ( $n != 0  ) {
	    # we have a new search

	    # Arguments for search query
	    my @sargs = ( $idx, $search );
	    my $srch = $dh->prepare_cached($cached_search);

	    # if a date-range is mentioned, fix the search sql to select the time range only
	    my $date_match = '\s*(\d\d\d\d-\d\d-\d\d)\s*\.\.\.\s*(\d\d\d\d-\d\d-\d\d)(\s*|$)';
	    if ( $search && $search =~ s/date$date_match//i ) {
		# daterange specified...
		# remove range from search string and process normally
		# Search restrict to date-range ( will reduce output list )
		@sargs = ( $idx, $1, $2 );
		$srch = $dh->prepare_cached($search_date);
		unless ( $search =~ /^\s*$/ ) {
		    # date with text match
		    push @sargs, $search;
		    $srch = $dh->prepare_cached($search_date_txt);
		}
	    }

	    # Do search
	    #print STDERR "S:$cached_search\n";
	    print STDERR "A:" . join( ":", @sargs ) . ":\n";
	    my $nres = $srch->execute(@sargs);

	    # record search results
	    $dh->prepare_cached( 'update cache_lst set nresults=?,last_used=datetime("now")  where qidx=?')
		->execute( $nres, $idx );
	}
    $dh->do("commit");
    return $idx;
}

# qidx,idx,rowid,snippet from cache_q_tmp
sub ldres {
    my $self = shift;
    my $dh   = $self->{"dh"};

    my ( $class, $idx0, $ppage, $search ) = @_;
    $search =~ s/\s+$// if defined($search);
    $search =~ s/^\s+// if defined($search);

    my ( $hd, $res ) = ( "", "" );

    undef $search if $search && $search =~ /^\s*$/;
    $idx0  = 1        unless $idx0;
    $ppage = $entries unless $ppage;

    $class =~ s/:\d+$// if $class;
    undef $class if defined($class) && $class eq $ANY;

    # search results are in cache_q(idx)
    my $idx = search( $self, $search );

    #Filter tags & dates
    my $subsel = "";


    my ( $classes, $ndata, $get_res );
    my @sargs=();
    if ($idx) {
	# its a search result
	#
	#TODO: remove "deleted" tags
	#Maybe: an entry w/o tag would not show w/o the left join
	# TODO: check if order by date is better than order by rank
	# $get_res=qq{ select fileinfo.*,snippet  from cache_q natural join fileinfo where qidx=? order by cast(mtime as int) desc limit ? offset ? };
	$get_res=qq{ select *  from cache_q natural join hash natural join ftime natural join pdfinfo where qidx=? };
        push @sargs,$idx;

	# TODO: only if idx=0 first page
	# get tags in result set
	$ndata = qq{select nresults from cache_lst where qidx=?};
    $ndata   = $dh->prepare_cached($ndata);
    $ndata -> execute($idx);

	if ($idx0 eq 1){
	    $classes=q{select tagname,count(*) count  from tags natural join tagname where idx in (select idx  from cache_q where qidx=?) group by tagid};
	    my $sel_t=$dh->prepare_cached($classes);
	    $sel_t->execute($idx);
	    $classes = $sel_t->fetchall_arrayref({});
	}
	#
	# get display list
    }
    else {
	# Return all
	$get_res=qq{ select *,Content snippet  from hash natural join Content natural join ftime natural join pdfinfo};


	if ($idx0 eq 1){
	    $classes = qq{ select tagname,count(*) count from $subsel tags natural join tagname group by tagid};
	    my $sel_t=$dh->prepare_cached($classes);
	    $sel_t->execute();
	    $classes = $sel_t->fetchall_arrayref({});
	}
	$ndata = qq{ select count(*) from $subsel hash };
    $ndata   = $dh->prepare_cached($ndata);
    $ndata -> execute();
    }
    $get_res .= " order by cast(mtime as int) desc";
    # class list
    if ( $class ) {
       $get_res =~ s/from/from (select idx  from tagname natural join tags where tagname = ? limit ? offset ?) natural join/;
       unshift @sargs,$class;
    } else {
	$get_res .= " limit ? offset ?";
    }

    # Assemble final query
    push @sargs,$ppage,int($idx0-1);

    $get_res=qq{ select idx,md5,mtime dt,pdfinfo,file,tags,snippet  from ($get_res) natural left join taglist natural left join file group by idx order by dt desc };

    # total count
    # get number of results
    my $hh=$ndata;
    $ndata   = $hh->fetchrow_array();
    $hh->finish;

    #  Add selection of slice wanted

    print STDERR "$get_res\n";
    $get_res = $dh->prepare_cached($get_res);
    $get_res->execute(@sargs);

    my $out = $get_res->fetchall_arrayref({});
    foreach ( @$out ) {
	if ( my $mpdf = $_->{"pdfinfo"} ){
		$_->{sz}= conv_size($1) if $mpdf =~ /File size\s*<\/td><td>\s*(\d+)/;
		$_->{pg}= $1 if $mpdf =~ /Pages\s*<\/td><td>\s*(\d+)\s*<\/td>/;
		# $_->{dt}= str2time($1) if ( $mpdf =~ /CreationDate\s*<\/td><td>\s*(.*?)\s*<\/td>/) unless $_->{dt};
		delete $_->{"pdfinfo"};
	}
	$_->{dt} = pr_time($_->{dt});
	my $f=$_->{file}; delete $_->{file};
	$f =~ s|^.*/||;
	$f =~ s|\.([^\.]*)$||;
	$_->{doct} = $1;
	$_->{doc}  = $f;
	$_->{doc}  =~ s/%20/ /g;

	# $_->{tip}  => $tip,
	# $_->dt   => $day,
	$_->{tip} = $_->{snippet}; delete $_->{"snippet"};
	$_->{tip} =~ s/["']/&quot;/g;
	$_->{tip} =~ s/\n/<br>/g;
	$_->{tg} = $_->{tags}|| ""; delete $_->{"tags"};
    }
    my $msg = "results: $ndata<br>";
    $msg .= "qidx: $idx<br>" if $idx;
    my $m = {
	nresults => int($ndata),                        # max number of items
	idx      => int($idx0),                         # first item in response
	pageno   => int( ( $idx0 - 1 ) / $ppage ) + 1,
	nitems   => int($ppage),

	# dates => $dater,
	query => $search,

	classes => $classes,
	msg     => $msg,
	items   => $out,
    };
    return $m;
    $out = JSON->new->pretty->encode($m);

    return $out;
}

sub conv_size
{  

    my $s=shift;
    return sprintf("%.1f Gb",$s/2**30) if $s > 2**30;
    return sprintf("%.1f Mb",$s/2**20) if $s > 2**20;
    return sprintf("%.1f kb",$s/2**10);
}

#
# print formated short time string depending on how long ago
sub pr_time {
	my $t   = shift;
	my $dt = time() - $t;
	my @str = ( "%a %H:%M",  "last %a",         "%b-%d",             "%b %Y" );
	my @off = ( 24 * 60 * 60, 7 * 24 * 60 * 60, 180 * 24 * 60 * 60 );
	foreach (@off) { 
		last if $dt < $_; 
		shift @str; 
	}
	return strftime( $str[0], localtime($t) );
}

#TJ
#TJ    my $short_name = $meta->{"Docname"}->{"value"} || "-";
#TJ    $short_name =~ s/^.*\///;
#TJ    my $sshort_name = $short_name;
#TJ    $short_name =~ s/#/%23/g;
#TJ    $short_name =~ s/(\.[a-z]*)$//;
#TJ    my $short_ext = $1;
#TJ    my $tip = $r->{"snippet"} || "";
#TJ    $tip =~ s/["']/&quot;/g;
#TJ    $tip =~ s/\n/<br>/g;
#TJ
#TJ    # $meta->{PopFile}
#TJ    $s = ( $meta->{"size"}->{"value"} || "0" )
#TJ      unless defined($s);
#TJ    my $so = $s;
#TJ    $so = sprintf( "%3.1fMb", $s / 1024 / 1024 ) if $s > 1024 * 1024;
#TJ    $so = sprintf( "%3.1fKb", $s / 1024 )        if $s > 1024;
#TJ    $so = "--" unless defined($s);
#TJ    $d = scalar( localtime( $meta->{"mtime"}->{"value"} || 1 ) )
#TJ      unless $d =~ /:.*:/;
#TJ    my $day = $d;
#TJ    $day =~ s/\s+\d+:\d+:\d+\s+/ /;
#TJ    my $vals = {
#TJ	md5  => $md5,
#TJ	doc  => $short_name,
#TJ	doct => $short_ext,
#TJ	tip  => $tip,
#TJ	pg   => $p,
#TJ	sz   => $so,
#TJ	dt   => $day,
#TJ	tg   => $tags,
#TJ    };
#TJ    return $vals;
#TJ}
#TJ
#TJsub load_results {
#TJ    my $dh         = shift;
#TJ    my ($stmt_hdl) = @_;
#TJ    my $t0         = 0;
#TJ    my @outrow;
#TJ    my @out;
#TJ    while ( my $r = $stmt_hdl->fetchrow_hashref ) {
#TJ	push @out, get_cell( $dh, $r );
#TJ    }
#TJ    return \@out;
#TJ}
#TJ
1;
