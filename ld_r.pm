package ld_r;

use strict;
use warnings;
use Data::Dumper;
use Cwd 'abs_path';
use POSIX;
use JSON;
use Sys::Hostname;

use Docconf;
use doclib::pdfidx;

print STDERR ">>> ld_r.pm\n" if $Docconf::config->{debug} > 2;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $__meta_sel;
my $entries = $Docconf::config->{results_per_page};

my $myhost = hostname();

my $ANY = "*ANY*";

sub new {
    my $class  = shift;
    my $chldno = shift;

    my $self = {};
    $self->{pd} = pdfidx->new($chldno);
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
        q{ delete from cache_lst where query like '%...%' },
        q{ create temporary table cache_q1 as
    select a.*,b.docid idx,snippet(text) snippet  from cache_lst a,text b
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
my $cache_setup  = q{insert or abort into cache_lst (query) values(?)};

sub search {
    my ( $self, $search ) = @_;
    my $dh = $self->{"dh"};

    # Check if search is already captured
    return undef unless $search;
    my $idx = $dh->selectrow_array( $cache_lookup, undef, $search );
    return $idx if $idx;

    #     if ( $search && !$idx ) {
    # 	$idx = search( $self, $search );
    #     }

    my $srch = $self->{"search_txt"};

    # not yet done
    # create cached results table

    $dh->do("begin transaction");

    $dh->do( $cache_setup, undef, $search );
    $idx = $dh->last_insert_id( undef, undef, undef, undef );

    # results are now available in cache_lst
    my @sargs = ( $idx, $search );

    my $date_match =
      '(\d\d\d\d-\d\d-\d\d)\s*\.\.\.\s*(\d\d\d\d-\d\d-\d\d)(\s|$)';
    if ( $search && $search =~ s/date:$date_match//i ) {

        # daterange specified...
        # remove range from search string and process normally
        # Search restrict to date-range ( will reduce output list )
        @sargs = ( $idx, $1, $2 );
        $srch = $self->{"search_date"};
        unless ( $search =~ /^\s*$/ ) {
            push @sargs, $search;
            $srch = $self->{"search_date_txt"};
        }
    }

    # Do search and filter dates
    #print STDERR "S:$cached_search\n";
    print STDERR "A:" . join( ":", @sargs ) . ":\n";
    my $nres = $srch->execute(@sargs);

    $self->{"update_cache"}->execute( $nres, $idx );
    $dh->do("commit");
    return $idx;
}

# qidx,idx,rowid,snippet from cache_q_tmp

sub ldres {
    my $self = shift;
    my $dh   = $self->{"dh"};
    unless ( $self->{"search_txt"} ) {

        # This is the main search query in the FTS table,
        # the result is saved in a caching table
        my $cached_search =
          q{insert or ignore into cache_q ( qidx,idx,snippet ) select
			?,docid,snippet(text)
			from text  join hash on (docid=idx) where text match ?
		};
        $self->{"search_txt"} = $dh->prepare($cached_search);
        $cached_search =~
          s/where/natural join dates where date between ? and ? and/;
        $self->{"search_date_txt"} = $dh->prepare($cached_search);
        $cached_search =
          "insert or ignore into cache_q (qidx, idx, snippet) select ?,idx,mtext
				from dates where date between ? and ?";
        $self->{"search_date"}  = $dh->prepare($cached_search);
        $self->{"update_cache"} = $dh->prepare(
'update cache_lst set nresults=?,last_used=datetime("now")  where qidx=?'
        );
    }

    my ( $class, $idx0, $ppage, $search ) = @_;
    $search =~ s/\s+$// if defined($search);
    $search =~ s/^\s+// if defined($search);

    my ( $hd, $res ) = ( "", "" );

    undef $search if $search && $search =~ /^\s*$/;
    $idx0  = 1        unless $idx0;
    $ppage = $entries unless $ppage;

    $class =~ s/:\d+$// if $class;
    undef $class if defined($class) && $class eq $ANY;

    my $idx = search( $self, $search );

    #Filter tags & dates
    my $subsel = "";
    if ($class) {

        # If tagname(s) specified,
        #  create junction list of docids
        $dh->do(q{drop table if exists taglist});
        $dh->do(
q{create temporary table taglist ( tagid integer primary key unique )}
        );
        my $sth = $dh->prepare(
q{insert into taglist (tagid) select tagid from tagname where tagname=?}
        );
        foreach ( split( /\s*,\s*/, $class ) ) {
            $sth->execute($_);
        }
        $dh->do(q{drop table if exists docids});
        $dh->do(
q{create temporary table docids as select distinct(idx) idx  from taglist natural join tags}
        );
        $subsel = "docids natural join ";
    }

    my ( $classes, $ndata, $get_res );
    $dh->do(qq{drop table if exists drange });
    if ($idx) {

        # Return query ($idx) result

        # get final reslist
        $dh->do(q{drop table if exists resl});
        my $rest =
qq{create temporary table resl as select * from $subsel cache_q where qidx = ?};
        $dh->do( $rest, undef, $idx );
        $dh->do(
qq{ delete from resl where idx in ( select idx from tags where tagid in ( select tagid from tagname where tagname = "deleted")) }
        );

# $dh->do( qq{ create temporary table drange as select min(date) min,max(date) max from dates natural join cache_q where qidx = ?}, undef, $idx );

        # get list of classes
        $classes =
q{select tagname,count(*) from tags natural join tagname where idx in ( select idx from resl) group by 1 order by 1};

        # get number of results
        $ndata = qq{select count(*) from resl};

        # get display list
        $get_res =
qq{ select * from resl join metadata m using (idx) where m.tag = "mtime" order by cast(m.value as integer) desc};
    }
    else {
# Return all
# $dh->do( qq{ create temporary table drange as select min(date),max(date) from dates } );

        $classes =
qq{ select tagname,count(*) from $subsel tags natural join tagname group by 1};
        $ndata = qq{ select count(*) from $subsel hash };

        $get_res =
qq{ select s.idx,s.value snippet from $subsel metadata s join metadata m using (idx) where s.tag="Content" and m.tag="mtime" order by cast(m.value as integer)  desc  };
    }

# my $dater = join( " ... ", $dh->selectrow_array("select * from drange") || "" );
    $classes = $dh->selectall_arrayref($classes);
    $ndata   = $dh->selectrow_array($ndata);

    #  Add selection of slice wanted
    $get_res .= " limit ?1 offset ?2";
    $get_res = $dh->prepare($get_res);

    $get_res->bind_param( 2, int( $idx0 - 1 ) );
    $get_res->bind_param( 1, $ppage );
    $get_res->execute();

    # unshift @$classes,[$ANY,$ndata];
    # $classes=[map{ join(':',@$_)} @$classes];
    $classes = [
        map {
            my $ts = $$_[1] / "$ndata.0";
            my $bg       = "";    #( $ts < 0.02 ) ? "background: #bbb" : "";
            my $filtered = "";
            $ts = int( $ts * 40 );
            $ts = 19 if $ts > 19;
            $ts = 9 if $ts < 9;
            my $rr = $$_[0];
            $filtered = "filtered" if ( $class && $rr !~ /$class/ );
            $_ = "<input type='button'  name='button_name'
		   value='$rr' class='tagbox $filtered' style='font-size: ${ts}px; $bg ' />";
        } @$classes
    ];

    my $out = load_results( $dh, $get_res );
    my $msg = "results: $ndata<br>";
    $msg .= "qidx: $idx<br>" if $idx;
    my $m = {
        nresults => int($ndata),                        # max number of items
        idx      => int($idx0),                         # first item in response
        pageno   => int( ( $idx0 - 1 ) / $ppage ) + 1,
        nitems   => int($ppage),

        # dates => $dater,
        query => $search,

        classes => join( "", @$classes ),
        msg     => $msg,
        items   => $out,
    };
    $out = JSON->new->pretty->encode($m);

    return $out;
}

sub get_rbox_item {
    my $self = shift;
    my $md5  = shift;
    my $dh   = $self->{"dh"};

    my $get_item =
qq{select s.idx,s.value snippet from hash natural join metadata s where md5 = ? and s.tag = "Content"};
    $get_item = $dh->prepare($get_item);
    $get_item->bind_param( 1, $md5 );
    $get_item->execute();
    my $ndata = qq{ select count(*) from hash };
    $ndata = $dh->selectrow_array($ndata);

    my $out = load_results( $dh, $get_item );
    my $msg = "Fetch";
    my $m   = {
        nresults => $ndata,

        # idx  => $idx0,
        # dates=> $dater,
        # pageno=> 1;
        # next_page => 2;
        # query=> "";
        nitems => 9999,

        # classes => join("", @$classes),
        msg   => "$ndata items",
        items => $out,
    };
    return $m;
}

# print page jumper  bar

sub get_meta {
    my $dh  = shift;
    my $tag = shift;
    $__meta_sel = $dh->prepare(q{select * from metadata where idx=?})
      unless $__meta_sel;
    $__meta_sel->execute($tag);
    my $r = $__meta_sel->fetchall_hashref("tag");
    return $r;
}

sub get_cell {
    my $dh   = shift;
    my ($r)  = @_;
    my $meta = get_meta( $dh, $r->{"idx"} );
    my $md5  = $meta->{"hash"}->{"value"} || "-";
    my $s    = undef;
    my $p    = "1";
    my $d    = $r->{"date"} || "--";
    if ( my $mpdf = $meta->{"pdfinfo"}->{"value"} ) {
        $s = $1 if $mpdf =~ /File size\s*<\/td><td>\s*(\d+)/;
        $p = $1 if $mpdf =~ /Pages\s*<\/td><td>\s*(\d+)\s*<\/td>/;
        $d = $1 if $mpdf =~ /CreationDate\s*<\/td><td>(.*?)<\/td>/;
    }
    $p = 1 unless $p;
    my $tags =
"select tagname from hash natural join tags natural join tagname where md5=\"$md5\"";
    $tags = $dh->selectall_hashref( $tags, 'tagname' );
    $tags = join( ",", sort keys %$tags );
    my $short_name = $meta->{"Docname"}->{"value"} || "-";
    $short_name =~ s/^.*\///;
    my $sshort_name = $short_name;
    $short_name =~ s/#/%23/g;
    $short_name =~ s/(\.[a-z]*)$//;
    my $short_ext = $1;
    my $tip = $r->{"snippet"} || "";
    $tip =~ s/["']/&quot;/g;
    $tip =~ s/\n/<br>/g;

    # $meta->{PopFile}
    $s = ( $meta->{"size"}->{"value"} || "0" )
      unless defined($s);
    my $so = $s;
    $so = sprintf( "%3.1fMb", $s / 1024 / 1024 ) if $s > 1024 * 1024;
    $so = sprintf( "%3.1fKb", $s / 1024 )        if $s > 1024;
    $so = "--" unless defined($s);
    $d = scalar( localtime( $meta->{"mtime"}->{"value"} || 1 ) )
      unless $d =~ /:.*:/;
    my $day = $d;
    $day =~ s/\s+\d+:\d+:\d+\s+/ /;
    my $vals = {
        md5  => $md5,
        doc  => $short_name,
        doct => $short_ext,
        tip  => $tip,
        pg   => $p,
        sz   => $so,
        dt   => $day,
        tg   => $tags,
    };
    return $vals;
}

sub load_results {
    my $dh         = shift;
    my ($stmt_hdl) = @_;
    my $t0         = 0;
    my @outrow;
    my @out;
    while ( my $r = $stmt_hdl->fetchrow_hashref ) {
        push @out, get_cell( $dh, $r );
    }
    return \@out;
}

1;
