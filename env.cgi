#!/usr/bin/perl
use CGI;
use Data::Dumper;
use WWW::Authen::Simple;
my $q = CGI->new;

my $auth = WWW::Authen::Simple->new(
    db             => $pdfidx->{"dh"},
    expire_seconds => 9999,
    cookie_domain  => $ENV{"SERVER_NAME"}
);
my ( $user, $uid ) = check_auth($q);
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



print $q->header(-charset=>'utf-8'),
$q->start_html(-title=>'env');
print "<PRE>\n";
print Dumper($q->Vars);
print Dumper(\%ENV);
print "</PRE>\n";
print end_html;
		 

