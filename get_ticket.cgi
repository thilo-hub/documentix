#!/usr/bin/perl
use strict;
use warnings;
use doclib::pdfidx;
use CGI;
my $q = CGI->new;
my $pdfidx = pdfidx->new();
my $dh = $pdfidx->{"dh"};

my $md5=$q->param('md5');

my $idx;
if ( $md5 )
{
	$idx=$dh->selectrow_array(
		'select idx from hash where md5=?',undef,$md5);
}
	# print "IDX:$idx\n" if $idx;
my $status =200;
$status="409 Conflict" unless $idx;
$md5=$idx  if $idx;
print $q->header( -status=> $status, -charset => 'utf-8' );

print "TICKET=$md5\n";
exit 0;
