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

print $q->start_html( -title =>'PDF Database' ),
# $q->Link( { -rel  => "stylesheet", -type => "text/css", -href  => "js/jquery.tagsinput.css" },""),
$q->Link( { -rel  => "stylesheet", 
		-type => "text/css", -href  => "js/docidx.css" },""),
$q->script( { -type => 'text/javascript', -src => "js/jquery/jquery.min.js" }, ""),
$q->script( { -type => 'text/javascript', -src => "js/jquery/jquery-ui.min.js" }, "" ),
$q->script( { -type => 'text/javascript', -src => "js/jquery.tagsinput.js" }, ""),
$q->script( { -type => 'text/javascript', -src => "js/wz_tooltip.js" }, ""),
$q->script( { -type => 'text/javascript', -src => "js/docidx.js"}, "" )
;

    print <<EOP;
<div class="top">
	<div class="header">
		Title line
	</div>
</div>
<div>
	<div class="left">
		<div id="left" class="menu">
			<div id="pageno" class="pageno"></div>
			Search: <input id="search"/>
			<div id="set_page"></div>
			<div id="taglist"></div>
			<div id="tagedit">
			<input id="tags"/>
			</div>
			<hr>
			<div id="msg"></div>
			<div id="scan"><a href="scanns.cgi" target="scanner">Load scanned data</a></div>
		</div>
	</div>
	<div class="right">
		<div id="result" class="results" > 
			Results
		</div>
	</div>
</div>
EOP

print $q->end_html;
exit 0;

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


