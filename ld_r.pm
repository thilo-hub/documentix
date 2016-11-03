package ld_r;
#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use doclib::pdfidx;
use Cwd 'abs_path';
use CGI;
use POSIX;

print STDERR ">>> ld_r.pm\n";
$ENV{"PATH"} .= ":/usr/pkg/bin";
my $docsrv = "ts2.nispuk.com";

my $__meta_sel;
my $q       = CGI->new;
my $ncols   = 2;
my $entries = 9;

use Sys::Hostname;
my $myhost=hostname();
# my $pdfidx = pdfidx->new();


# print pages
my $ANY = "*ANY*";

# my $dh = $pdfidx->{"dh"};

sub new {
	my $class = shift;

	my $self = {};
        $self->{pd}= pdfidx->new();
        $self->{dh}= $self->{pd}->{dh};
	setup_db($self->{dh});
	return bless $self, $class;
}

  

sub trace_db {
    my $dh=shift;
    open( TRC, ">>/tmp/db.trace" );

    sub trace_it {
        my $r = shift;

        print TRC "DB: $r\n";
    }

    $dh->sqlite_trace( \&trace_it );
}

sub setup_db {
    my $dh=shift;
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

my $s1 = q{select qidx from cache_lst where query = ?};
my $s2 = q{insert or abort into cache_lst (query) values(?)};
my $s3 = q{insert into cache_q ( qidx,idx,snippet ) select 
		qidx,docid,snippet(text) 
		from cache_lst, text  where qidx = ? and text match query
	};
my $s4 = q{delete from cache_q  where qidx=8 and idx in ( select idx from cache_q join hash using(idx)  natural join file where qidx=8 and host is NULL )};
# qidx,idx,rowid,snippet from cache_q_tmp

sub ldres {
    my $self=shift;
    my $dh = $self->{"dh"};

    my ( $class, $idx0, $ppage, $search ) = @_;

    my ( $hd, $res ) = ( "", "" );

    # my $idx0 = ( $q->param("idx") || 1 );
    # my $ppage = ( $q->param("count") || 18 );
    # my $search = $q->param("search") || undef;
    # my $ppage = $q->param("ppage")|| $entries;
    undef $search if $search && $search =~ /^\s*$/;
    $idx0  = 1        unless $idx0;
    $ppage = $entries unless $ppage;

    $class =~ s/:\d+$// if $class;
    undef $class if defined($class) && $class eq $ANY;

    # $hd=$q->header( -charset => 'utf-8' ),    # , -cookie=> \@mycookies), ;

    my $idx = $dh->selectrow_array( $s1, undef, $search );
    my ( $dmin, $dmax );

    if (   $search
        && $search =~
s/\s*daterange:\s*(\d\d\d\d-\d\d-\d\d)\s*\.\.\.\s*(\d\d\d\d-\d\d-\d\d\s*)//i
      )
    {
        # Search restrict to date-range
        $dmin = $1;
        $dmax = $2;

    }
    if ( $search && !$idx ) {

        # create cached results table
        $dh->do( $s2, undef, $search );
        $idx=$dh->last_insert_id( undef, undef, undef, undef );
        my $nres = $dh->do( $s3, undef, $idx );
	my $unavail = $dh->do( $s4, undef, $idx);
        print STDERR "nres/unavail: $nres $unavail\n";
        #$dh->do($s3_fin,undef,);
        $dh->do( 'update cache_lst set nresults=?,last_used=datetime("now")  where qidx=?',
            undef, $nres, $idx );
    }

    my $subsel = "";
    if ($class) {
        $dh->do(q{drop table if exists cls});
        $dh->do(
            q{create temporary table cls ( tagid integer primary key unique )});
        my $sth = $dh->prepare(
            q{insert into cls (tagid) select tagid from tagname where tagname=?}
        );
        foreach ( split( /\s*,\s*/, $class ) ) {
            $sth->execute($_);
        }
        $dh->do(q{drop table if exists docids});
        $dh->do(
q{create temporary table docids as select distinct(idx) idx  from cls natural join tags}
        );
        $subsel = "docids natural join ";
    }
    $dh->do(qq{drop table if exists drange });
    my ( $classes, $ndata, $stm1 );
    if ($search) {

        # get final reslist
        $dh->do(q{drop table if exists resl});
        my $rest =
qq{create temporary table resl as select * from $subsel cache_q where qidx = ?};

        $dh->do( $rest, undef, $idx );
        print TRC "Tm: $dmin ... $dmax\n";
        if ($dmin) {
            my $drest =

              print TRC "Delete timerangs\n";
            $dh->do(
qq{create temporary table subd as select distinct(idx) idx  from dates where date between ? and ?},
                undef, $dmin, $dmax
            );
            $dh->do(
                qq{ delete from resl where idx not in ( select idx from subd ) }
            );
        }

        $dh->do(
qq{ create temporary table drange as select min(date) min,max(date) max from dates natural join cache_q where qidx = ?},
            undef, $idx
        );

        # get list of classes
        $classes =
q{select tagname,count(*) from tags natural join tagname where idx in ( select idx from resl) group by 1 order by 1};

        # get number of results
        $ndata = qq{select count(*) from resl};

        # get display list
        $stm1 =
qq{ select * from resl join metadata m using (idx) where m.tag = "mtime" order by cast(m.value as integer) desc limit ?,?};
    }
    else {
        $classes =
qq{ select tagname,count(*) from $subsel tags natural join tagname group by 1};
        $ndata = qq{ select count(*) from $subsel hash };

# qq{ select idx,value snippet from $subsel metadata where tag="Content" limit ?,?  };
        $stm1 =
qq{ select s.idx,s.value snippet from $subsel metadata s join metadata m using (idx) where s.tag="Content" and m.tag="mtime" order by cast(m.value as integer)  desc limit ?,?  };
        $dh->do(
qq{ create temporary table drange as select min(date),max(date) from dates }
        );
    }

    my $dater = join( " ... ", $dh->selectrow_array("select * from drange") );
    $classes = $dh->selectall_arrayref($classes);
    $ndata   = $dh->selectrow_array($ndata);
    $stm1    = $dh->prepare($stm1);

    $stm1->bind_param( 1, $idx0 - 1 );
    $stm1->bind_param( 2, $ppage );
    $stm1->execute();

    # unshift @$classes,[$ANY,$ndata];
    # $classes=[map{ join(':',@$_)} @$classes];
    $classes = [
        map {
            my $ts = $$_[1] / "$ndata.0";
            my $bg = "";    #( $ts < 0.02 ) ? "background: #bbb" : "";
            $ts = int( $ts * 40 );
            $ts = 19 if $ts > 19;
            $ts = 9 if $ts < 9;
            $_  = $q->button(
                -name  => 'button_name',
                -class => 'tagbox',
                -style => "font-size: ${ts}px; $bg ",
                -value => $$_[0]
              )
        } @$classes
    ];

    my $out = load_results($dh,$stm1);

    $res =
        $q->div( { -class => "tick", -id => "nresults" }, $ndata )
      . $q->div( { -class => "tick", -id => "idx" },      $idx0 )
      . "&nbsp;"
      . $q->div( { -class => "tick", -id => "dates" }, $dater )
      . $q->div( { -class => "tick", -id => "pageno" },
        int( $idx0 / $ppage ) + 1 )
      . $q->div( { -class => "tick", -id => "query" }, $search )
      . $q->div(
        { -class => "tick", -id => "pages" },
        pages( $q, $idx0, $ndata, $ppage )
      ) . $q->div( { -id => "classes" }, join( "", @$classes ) );

    $res .= "<br>";
    $res .=
      $q->div(
        $q->ul( { -id => "X_results" }, $q->li( { -class => "rbox" }, $out ) )
      );
    $res .= $q->end_html;

    return $hd . $res;
}

# print page jumper  bar
sub pages {
    my ( $q, $idx0, $ndata, $ppage ) = @_;
    my @pgurl;
    my $p0     = 1;
    my $pi     = int( ( $idx0 - 1 ) / $ppage ) + $p0;
    my $prev_p = $pi - 1;
    $prev_p = 1 if $prev_p < 1;
    my $last_p = int( $ndata / $ppage ) + $p0;
    my $next_p = $pi + 1;
    $next_p = $last_p if $next_p > $last_p;

    my $lo = $pi - int( $entries / 2 );
    $lo = $p0 if $lo < 1;
    my $hi = $lo + $entries;
    $hi = $last_p if $hi > $last_p;

    push @pgurl, $q->button( -class => 'pageno', -value => "<<", -id => 1 );
    push @pgurl,
      $q->button(
        -class => 'pageno',
        -value => "<",
        -id    => ( $prev_p - 1 ) * $ppage + 1
      );

    foreach ( $lo .. $hi ) {
        my $i = ( $_ - 1 ) * $ppage + 1;
        push @pgurl,
          $q->button(
            -class => ( $_ == $pi ? 'this_page' : 'pageno' ),
            -value => $_,
            -id    => $i
          );
    }
    push @pgurl,
      $q->button(
        -class => 'pageno',
        -value => ">",
        -id    => ( $next_p - 1 ) * $ppage + 1
      );
    push @pgurl,
      $q->button(
        -class => 'pageno',
        -value => ">>",
        -id    => ( $last_p - 1 ) * $ppage + 1
      );
    return join( "", @pgurl );
    return $q->table( $q->Tr( $q->td( \@pgurl ) ) );
}

sub get_meta {
    my $dh = shift;
    my $tag = shift;
    $__meta_sel = $dh->prepare(q{select * from metadata where idx=?})
      unless $__meta_sel;
    $__meta_sel->execute($tag);
    my $r = $__meta_sel->fetchall_hashref("tag");
    return $r;
}

sub get_cell {
    my $dh = shift;
    my ($r)  = @_;
    my $meta = get_meta($dh, $r->{"idx"} );
    my $md5  = $meta->{"hash"}->{"value"};

    my $editor = "edit.cgi?send=";
    my $qt     = "'";
    $editor .= "$md5&type=lowres";
    my $s = 0;
    my $p = "1";
    my $d = $r->{"date"} || "--";
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
    $tags = $q->p(
        $q->input(
            {
                -name  => "tags",
                -id    => "$md5",
                -type  => "text",
                -class => "tagbox",
                -value => $tags
            }
        )
    );

    my $short_name = $meta->{"Docname"}->{"value"};
    $short_name =~ s/^.*\///;
    my $sshort_name = $short_name;
    $short_name =~ s/#/%23/g;

    # build various URLS
    #my $pdf    = "docs/pdf/$md5/$short_name";
    my $pdf    = "web/viewer.html?file=../docs/pdf/$md5/$short_name";
    my $lowres = "docs/lowres/$md5/$short_name";

    #my $ico    = qq{<img src='docs/ico/$md5/$short_name'};
    my $ico =
      $q->img( { -class => "thumb", -src => "docs/ico/$md5/$short_name" } );
    my $tip = $r->{"snippet"} || "";

    #$tip =~ s/(.{1024}) .*/$1/;
    #$tip =~ s/(([^\n]*\n){10}).*/$1/;
    $tip =~ s/'/&quot;/g;
    $tip =~ s/\n/<br>/g;
    $tip = qq{'$tip'};

    # print STDERR "TIP:$tip\n";

# my @a=stat($pdf); my $e= strftime("%Y-%b-%d %a  %H:%M ($a[7]) $_",localtime($a[10]));
# $meta->{PopFile}->{value} =~ s|http://$docsrv|$q->url(-base=>'1')|e
# if $meta->{PopFile};;
    my $day = $d;
    $day =~ s/\s+\d+:\d+:\d+\s+/ /;

    # $d = $&;
    $d =~ s/^\s*\S*\s+//;
    $d =~ s/\s+\d+:\d+:\d+\s+/ /;

    my $data = $q->div(
        { -class => "thumb" },
        $q->a(
            {
                -class       => "thumb",
                -href        => $pdf,
                -target      => "docpage",
                -onmouseover => "Tip($tip)",
                -onmouseout  => "UnTip()"
            },
            $ico
        )
      )
      . $q->div(
        { -class => "descr" },
        $q->a( { -href => $meta->{PopFile}->{value}, -target => "_popfile" },
            $meta->{Class}->{value} )
          . $q->br
          . $q->a( { -class => "doclink", -href => $pdf, -target => "docpage" },
            $sshort_name )
          . $q->br
          . $q->a( { -class => "dtags" }, $tags )
          . (
            ( ( $s / $p ) > 500000 )
            ? $q->a( { -href => $lowres, -target => "docpage" },
                "&lt;Lowres&gt;" )
            : ""
          )
          . $q->a( { -href => $editor, -target => "docpage" }, "&lt;Edit&gt;" )
          . "<br>$d"
          . "<br> Pages: $p <br>$s"
      );

    return $q->td( $q->div( { -class => "rcell" }, $data ) );

}

sub load_results {
    my $dh=shift;
    my ($stmt_hdl) = @_;
    my $t0 = 0;
    my @outrow;
    my @out;
    while ( my $r = $stmt_hdl->fetchrow_hashref ) {
        if (0) {
            if ( $r->{"date"} && $t0 ne $r->{"date"} ) {
                push @out, join( "\n  ", splice(@outrow) );

                push @out,
                  $q->th( { -colspan => $ncols }, $q->hr, $r->{"date"} );
                $t0 = $r->{"date"};
            }
            push @outrow, get_cell($dh,$r);
            push @out, join( "\n  ", splice(@outrow) )
              if scalar(@outrow) >= $ncols;
        }
        else {
            push @out, get_cell($dh,$r);
        }
    }

    # push @out, join( "\n  ", splice(@outrow) );
    return \@out;
}

1;
