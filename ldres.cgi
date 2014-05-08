#!/usr/bin/perl -It2
use strict;
use warnings;
use Data::Dumper;
use WWW::Authen::Simple;
use t2::pdfidx;
use Cwd 'abs_path';
use CGI;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $__meta_sel;
my $q     = CGI->new;
my $ncols = 2;

my $pdfidx = pdfidx->new();

#if we have the authetication cookies in the parameters
# put them into a cookie
my @mycookies;

# push @mycookies, $q->cookie(-name=>'login',-value=>[$q->param('login')]) if $q->param('login');
# push @mycookies, $q->cookie(-name=>'ticket',-value=>[$q->param('ticket')]) if $q->param('ticket');

my $auth = WWW::Authen::Simple->new(
    db             => $pdfidx->{"dh"},
    expire_seconds => 9999,
    cookie_domain  => $ENV{"SERVER_NAME"}
);
my ( $user, $uid ) = check_auth($q);

#===== AUTHENTICATED BELOW ===========

my $dbs    = ( stat("/var/db/pdf/doc_db.db") )[7] / 1e6 . " Mb";
my $sessid = $q->cookie('SessionID');

print $q->header( -charset => 'utf-8' ),    # , -cookie=> \@mycookies),
   ;
#   $q->start_html( -title => 'results' ),;

# print pages
my $p0 = ( $q->param("page") || 1 );
my $search = $q->param("search") || undef;
undef $search if $search && $search =~ /^\s*$/;

my $ANY       = "*ANY*";
my $json_text = $q->param('json_string');
my $perl_scalar;
if ($json_text) {
    my $json = JSON::PP->new->utf8;
    $perl_scalar = $json->decode($json_text);
}
my $class = $q->param("class") || $perl_scalar->{"class"} || undef;
$class =~ s/:\d+$// if $class;
undef $class if defined($class) && $class eq $ANY;

# use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
# use File::Copy;

use POSIX;

my $dh = $pdfidx->{"dh"};

$dh->do(
q{ create table if not exists cache_lst ( qidx integer primary key autoincrement,
		query text unique, last_used integer )}
);
$dh->do(
q{ create table if not exists cache_q ( qidx integer, idx integer, snippet text, unique(qidx,idx))}
);

my $s1 = q{select qidx from cache_lst where query = ?};
my $s2 = q{insert or abort into cache_lst (query) values(?)};
my $s3 =
q{insert into cache_q ( qidx,idx,snippet ) select ?, docid idx,snippet(text) snippet from text where text match ? };

my $idx = $dh->selectrow_array( $s1, undef, $search );

unless ($idx) {

    # create cached results table
    $dh->do( $s2, undef, $search );
    $idx = $dh->last_insert_id( undef, undef, undef, undef );
    $dh->do( $s3, undef, $idx, $search );
}

my $subsel = "";
if ($class) {
    $dh->do(q{drop table if exists cls});
    $dh->do(q{create table cls ( tagid integer primary key unique )});
    my $sth = $dh->prepare(
        q{insert into cls (tagid) select tagid from tagname where tagname=?});
    foreach ( split( /\s*,\s*/, $class ) ) {
        $sth->execute($_);
    }
    $dh->do(q{drop table if exists docids});
    $dh->do(q{create table docids as select idx  from cls natural join tags});
    $subsel = "docids natural join ";
}
my ( $classes, $ndata, $stm1 );
if ($search) {

    # get final reslist
    $dh->do(q{drop table if exists resl});
    my $rest =
      qq{create table resl as select * from $subsel cache_q where qidx = ?};
    $dh->do( $rest, undef, $idx );

    # get list of classes
    $classes =
q{select tagname,count(*) from tags natural join tagname where idx in ( select idx from resl) group by 1 order by 1};

    # get number of results
    $ndata = qq{select count(*) from resl};

    # get display list
    $stm1 = qq{ select * from resl limit ?,?};
}
else {
    $classes =
qq{ select tagname,count(*) from $subsel tags natural join tagname group by 1};
    $ndata = qq{ select count(*) from $subsel hash };
    $stm1 =
qq{ select idx,value snippet from $subsel metadata where tag="Content" limit ?,?  };
}

$classes = $dh->selectall_arrayref($classes);
$ndata   = $dh->selectrow_array($ndata);
$stm1    = $dh->prepare($stm1);

my $ppage = 18;
my $max_page = int( ( $ndata - 1 ) / $ppage );
$max_page = 0             if $max_page < 0;
$p0       = $max_page + 1 if $p0 > $max_page;
$stm1->bind_param( 1, ( $p0 - 1 ) * $ppage );
$stm1->bind_param( 2, $ppage );
$stm1->execute();

# unshift @$classes,[$ANY,$ndata];
# $classes=[map{ join(':',@$_)} @$classes];
$classes = [
    map {
        my $ts = $$_[1] / "$ndata.0";
        my $bg = ( $ts < 0.02 ) ? "background: #bbb" : "";
        $ts = 0.2 if $ts < 0.1;
        $ts = int( $ts * 60 );
        $_  = $q->button(
            -name  => 'button_name',
            -class => 'tagbox_l',
            -style => "font-size: ${ts}px; $bg ",
            -value => $$_[0]
          )
    } @$classes
];

my $out = load_results($stm1);

print $q->div( { -id => "nresults" }, $ndata ),
  $q->span( { -style => "display:none" },
    $q->div( { -id => "pages" }, pages($q,$p0,$max_page) ) ,
    $q->div( { -id => "classes" }, join( "", @$classes ) ) );

print $q->table( { -border => 1, -frame => 1 }, $q->Tr($out) ), $q->end_html;

exit(0);

sub pages {
    my ( $q, $p0, $maxpage ) = @_;
    my @pgurl;
    my $myself = $q->url( -query => 1, -relative => 1 );
    $myself =~ s/%/%%/g;
    $myself =~ s/(;|\?)/\&/g;
    $myself =~ s/&page=\d+//;
    $myself =~ s/(&|$)/\?page=%d$1/;
    push @pgurl, sprintf( "<a OnClick=load_res($myself)>&lt;&lt;</a>", 1 );
    push @pgurl, sprintf( "<a OnClick=load_res($myself)>&lt;</a>", $p0 > 1 ? $p0 - 1 : 1 );
    my $entries = 6;
    my $lo      = $p0 - $entries / 2;
    $maxpage++;
    $lo = $maxpage - $entries if $lo > $maxpage - $entries;
    $lo = 1 if $lo < 1;
    my $hi = $lo + $entries;
    $hi = $maxpage if $hi > $maxpage;

    foreach ( $lo .. $hi ) {
        push @pgurl,
          sprintf( "<a OnClick=load_res($myself)>%s</a>",
            $_, ( $_ == $p0 ? "<big>&nbsp;$_&nbsp;</big>" : $_ ) );
    }
    push @pgurl, sprintf( "<a OnClick=load_res($myself)>&gt;<a>",     $p0 + 1 );
    push @pgurl, sprintf( "<a OnClick=load_res($myself)>&gt;&gt;<a>", $maxpage );
    return $q->table( $q->Tr( $q->td( \@pgurl ) ) );
}

sub check_auth {
    my $q = shift;
    $auth->logout() if $q->param('Logout');

    my ( $s, $user, $uid ) =
      $auth->login( $q->param('user'), $q->param('passwd') );
    if ( $s != 1 ) {
        do "login.cgi";
        exit 0;
    }
    return ( $user, $uid );
}

sub get_meta {
    my $tag = shift;
    $__meta_sel = $dh->prepare(q{select * from metadata where idx=?})
      unless $__meta_sel;
    $__meta_sel->execute($tag);
    my $r = $__meta_sel->fetchall_hashref("tag");
    return $r;
}

sub get_cell {
    my ($r)  = @_;
    my $meta = get_meta( $r->{"idx"} );
    my $md5  = $meta->{"hash"}->{"value"};

    my $editor = "edit.cgi?send=";
    my $qt     = "'";
    $editor .= "$md5&type=lowres";
    my $s = 0;
    my $p = "1";
    my $d = "--";
    if ( my $mpdf=$meta->{"pdfinfo"}->{"value"} )
    {
	    $s = $1 if $mpdf =~ /File size\s*<\/td><td>\s*(\d+)/;
	    $p = $1 if $mpdf =~ /Pages\s*<\/td><td>\s*(\d+)\s*<\/td>/;
	    $d = $1 if $mpdf =~ /CreationDate\s*<\/td><td>(.*?)<\/td>/;
    }

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
    my $pdf    = "docs/pdf/$md5/$short_name";
    my $lowres = "docs/lowres/$md5/$short_name";
    my $ico    = qq{<img width=150 heigth=212 src='docs/ico/$md5/$short_name'};
    my $tip    = qq{<table><tr><td>$meta->{Content}->{value}</td></tr></table>};
    $tip = $r->{"snippet"} if $r->{"snippet"};
    $tip =~ s/'/&quot;/g;
    $tip =~ s/\n/<br>/g;
    $tip = qq{'$tip'};
    #print STDERR "TIP:$tip\n";

# my @a=stat($pdf); my $e= strftime("%Y-%b-%d %a  %H:%M ($a[7]) $_",localtime($a[10]));
    $meta->{PopFile}->{value} =~ s|http://maggi|$q->url(-base=>'1')|e;
    my $day = $d;
    $day =~ s/\s+\d+:\d+:\d+\s+/ /;
    $d = $&;

    my $data = 
            $q->a(
                {   -class=>"thumb",
                    -href        => $pdf,
                    -onmouseover => "Tip($tip)",
                    -onmouseout  => "UnTip()"
                },
                $ico
            ).
            $q->div({-class=>"descr"}, 
		   $q->a(
                { -href => $meta->{PopFile}->{value}, -target => "_popfile" },
                $meta->{Class}->{value} )
              . $q->br
              . $q->a( { -class=>"doclink", -href => $pdf }, $sshort_name )
              . $q->br
              . $q->a($tags).
            (
                ( ( $s / $p ) > 500000 )
                ? "<br>"
                  . $q->a( { -href => $lowres, -target => "_pdf" },
                    "&lt;Lowres&gt;" )
                : ""
              )
              . "<br>"
              . $q->a( { -href => $editor, -target => "results" },
                "&lt;Edit&gt;" )
              . "<br> Pages: $p <br>$s");

    return $q->td( $q->div({-class=>"rcell"},$data));

}

sub load_results {
    my ($stmt_hdl) = @_;
    my $t0 = 0;
    my @outrow;
    my @out;
    while ( my $r = $stmt_hdl->fetchrow_hashref ) {
        if ( $r->{"date"} && $t0 ne $r->{"date"} ) {
            push @out, join( "\n  ", splice(@outrow) );

            push @out, $q->th( { -colspan => $ncols }, $q->hr, $r->{"date"} );
            $t0 = $r->{"date"};
        }
        push @outrow, get_cell($r);
        push @out, join( "\n  ", splice(@outrow) ) if scalar(@outrow) >= $ncols;
    }
    push @out, join( "\n  ", splice(@outrow) );
    return \@out;
}

