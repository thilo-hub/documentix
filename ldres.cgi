#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use WWW::Authen::Simple;
use CGI;
use ld_r;
$ENV{"PATH"} .= ":/usr/pkg/bin";

my $q     = CGI->new;
my $ncols = 2;
my $entries=9;

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
my ( $user, $uid ) = check_auth($q) unless $ENV{"DISABLE_AUTH"};

#===== AUTHENTICATED BELOW ===========


my $dbs    = ( stat("/var/db/pdf/doc_db.db") )[7] / 1e6 . " Mb";
my $sessid = $q->cookie('SessionID');

print $q->header( -charset => 'utf-8' ),    # , -cookie=> \@mycookies),
   ;
my $idx0 = ( $q->param("idx") || 1 );

#   $q->start_html( -title => 'results' ),;

# print pages
# my $ppage = ( $q->param("count") || 18 );
my $search = $q->param("search") || undef;
my $ppage = $q->param("ppage")|| $entries;
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

print ldres($class,$idx0,$ppage,$search);

exit 0;
sub check_auth {
    my $q = shift;
    $auth->logout() if $q->param('Logout');

    my ( $s, $user, $uid ) =
      $auth->login( scalar $q->param('user'), scalar $q->param('passwd') );
    if ( $s != 1 ) {
        do "login.cgi";
        exit 0;
    }
    return ( $user, $uid );
}

