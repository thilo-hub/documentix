#!/usr/bin/perl
use strict;
use warnings;
use doclib::pdfidx;
use WWW::Authen::Simple;
use feed;
use HTTP::Message;

use CGI;
$ENV{"PATH"} .= ":/usr/bin:/usr/pkg/bin";


my $q = CGI->new;

# Process an HTTP request
my $values  = scalar $q->param('send');

my $md5=$values;
my $pdfidx=pdfidx->new();
my $t=scalar $q->param('type');
my $dh= $pdfidx->{"dh"};

my $auth=WWW::Authen::Simple->new(
	db => $dh,
	cookie_domain => $ENV{"SERVER_NAME"}
);
my ($f,$ext);
open(F,">>/tmp/f.log"); foreach(keys %ENV){ print F "$_ => $ENV{$_}\n" }; 

my $pi=$ENV{'PATH_INFO'};
my($username,$passwd)=(scalar $q->param('user'),scalar $q->param('passwd'));

# my ($t,$m)=feed($md5,$t,$pi);

my($s,$user,$uid)=$auth->login($username,$passwd);
if ( 0&& $s != 1 )
{
	do "login.cgi";
	exit 0;
}

print HTTP::Message->new(feed_m($md5,$t,$pi))->as_string;
exit(0);

