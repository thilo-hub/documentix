#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use WWW::Authen::Simple;
use doclib::pdfidx;
use Cwd 'abs_path';
use CGI;
use JSON::PP;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $__meta_sel;
my $q = CGI->new;

my $pdfidx = pdfidx->new();

#if we have the authetication cookies in the parameters
# put them into a cookie
my @mycookies;

my $auth = WWW::Authen::Simple->new(
    db             => $pdfidx->{"dh"},
    expire_seconds => 9999,
    cookie_domain  => $ENV{"SERVER_NAME"}
);
my ( $user, $uid ) = check_auth($q);

#===== AUTHENTICATED BELOW ===========

my $dh = $pdfidx->{"dh"};
print $q->header( -charset => 'utf-8' )    # , -cookie=> \@mycookies),,
 ;
  my $json_text = $q->param('json_string');
if ($json_text) {
    my $json        = JSON::PP->new->utf8;
    my $perl_scalar = $json->decode($json_text);
    my $op_add =
"insert or ignore into tags (tagid,idx) select tagid,idx from tagname, hash  where tagname = ?  and md5  = ?";
    my $op_del =
"delete from tags where tagid = (select tagid from tagname where tagname = ? ) and idx = (select idx from hash where md5 = ?) ";
    $dh->prepare(
"delete from tagname where tagid in (select distinct(tagid) from tagname where tagid not in (select distinct(tagid) from tags))"
    ) if ( $perl_scalar->{"op"} eq "rem" );
    $dh->prepare("insert or ignore into tagname (tagname) values(?)")
      ->execute( $perl_scalar->{"tag"} )
      if ( $perl_scalar->{"op"} eq "add" );
    my $op = ( $perl_scalar->{"op"} eq "rem" ) ? $op_del : $op_add;
    $dh->prepare($op)->execute( $perl_scalar->{"tag"}, $perl_scalar->{"md5"} );
      $q->start_html( -title => 'PDF Database' ),
      $q->body( Dumper($perl_scalar) );
    open( FH, ">/tmp/tags.log" ) && print FH Dumper($perl_scalar) && close FH;

}
else {

    print $q->start_html( -title =>'PDF Database' ),
      $q->Link( { -rel  => "stylesheet", -type => "text/css", -href  => "js/docidx.css" },""),
      $q->Link( { -rel  => "stylesheet", -type => "text/css", -href  => "js/jquery.tagsinput.css" },""),
      $q->script( { -type => 'text/javascript', -src => "js/jquery/jquery.min.js" }, ""),
      $q->script( { -type => 'text/javascript', -src => "js/jquery/jquery-ui.min.js" }, "" ),
      $q->script( { -type => 'text/javascript', -src => "js/wz_tooltip.js" }, ""),
      $q->script( { -type => 'text/javascript', -src => "js/docidx.js"}, "" )
	;

    my $tags = $dh->selectall_hashref(
"select tagname,count(*) cnt from tags natural join tagname group by tagname",
        "tagname"
    );
    my $left;
    my $sum = 0;
    foreach my $tv ( sort keys %$tags ) {
        $sum += $tags->{$tv}->{cnt};
    }
    $left .=
      $q->br . "Search:" . $q->textfield( { -id => "search" }, 'search' );

    $tags = $dh->selectall_hashref(
"select tagname,count(*) cnt from tags natural join tagname group by tagname order by cnt desc limit 20",
        "tagname"
    );
    my $limit = 20;
    my $tagl;
    foreach my $tv ( sort keys %$tags ) {

        last if $limit-- eq 0;

        #print "$tv : $tags->{$tv}->{cnt}\n";
        my $ts = $tags->{$tv}->{"cnt"} / $sum;
        my $bg = ( $ts < 0.02 ) ? "background: #bbb" : "";
        $ts = 0.2 if $ts < 0.1;
        $ts = int( $ts * 30 );
        $tagl .= $q->button(
            -name  => 'button_name',
            -class => 'tagbox_l',
            -style => "font-size: ${ts}px; $bg ",
            -value => $tv
        );

    }
    $left .= $q->div( { -id => 'pagesel' }, $tagl );
    $left .= $q->div( { -id => 'taglist' }, $tagl );
    $left .= "<p>" . $q->hr . $q->div( { -id => 'msg' }, "msg" ) . "</p>";

    print <<EOP;
<div class="top">
	<div class="header">
		Title line
	</div>
</div>
<div>
	<div class="left">
		<div id="left" class="menu">
			$left
		</div>
	</div>
	<div class="right">
		<div id="result" class="results" > 
			Results
		</div>
	</div>
</div>
EOP
}

print $q->end_html;
exit 0;

sub pages {
    my ( $q, $p0, $maxpage ) = @_;
    my @pgurl;
    my $myself = $q->url( -query => 1, -relative => 1 );
    $myself =~ s/%/%%/g;
    $myself =~ s/(;|\?)/\&/g;
    $myself =~ s/&page=\d+//;
    $myself =~ s/(&|$)/\?page=%d$1/;
    push @pgurl, sprintf( "<a href=$myself>&lt;&lt;</a>", 1 );
    push @pgurl, sprintf( "<a href=$myself>&lt;</a>", $p0 > 1 ? $p0 - 1 : 1 );
    my $entries = 6;
    my $lo      = $p0 - $entries / 2;
    $maxpage++;
    $lo = $maxpage - $entries if $lo > $maxpage - $entries;
    $lo = 1 if $lo < 1;
    my $hi = $lo + $entries;
    $hi = $maxpage if $hi > $maxpage;

    foreach ( $lo .. $hi ) {
        push @pgurl,
          sprintf( "<a href=$myself>%s</a>",
            $_, ( $_ == $p0 ? "<big>&nbsp;$_&nbsp;</big>" : $_ ) );
    }
    push @pgurl, sprintf( "<a href=$myself>&gt;<a>",     $p0 + 1 );
    push @pgurl, sprintf( "<a href=$myself>&gt;&gt;<a>", $maxpage );
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


