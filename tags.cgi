#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
# use WWW::Authen::Simple;
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

# my $auth = WWW::Authen::Simple->new(
#     db             => $pdfidx->{"dh"},
#     expire_seconds => 9999,
#     cookie_domain  => $ENV{"SERVER_NAME"}
# );
# my ( $user, $uid ) = check_auth($q);

#===== AUTHENTICATED BELOW ===========
my $dh = $pdfidx->{"dh"};
print $q->header( -charset => 'utf-8' )    # , -cookie=> \@mycookies),,
  ;
print STDERR Dumper(\%ENV);
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

print $q->start_html, "Tag added";
print $q->end_html;
exit 0;
#
#sub check_auth {
#    my $q = shift;
#     $auth->logout() if $q->param('Logout');
#
#    my ( $s, $user, $uid ) =
#      $auth->login( $q->param('user'), $q->param('passwd') );
#    if ( $s != 1 ) {
#        do "login.cgi";
#        exit 0;
#    }
#    return ( $user, $uid );
#}
#
