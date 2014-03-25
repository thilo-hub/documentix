#!/usr/bin/perl -It2

########################################################################
# This is a very simple addusers script. Tweak to your needs
########################################################################
# In order to run this script:
#  1)you will need to setup your database tables. Example database
#    scheme's are available in the examples/ subdirectory.
#  4)change the globals below to match your situation.
#
########################################################################

use strict;
use DBI;
use Digest::MD5 ();
use pdfidx;
my $pdfidx=pdfidx->new();
my $dbh=$pdfidx->{"dh"};
use XMLRPC::Lite;
my $popsession  = XMLRPC::Lite->proxy('http://localhost:8081/RPC2')
                      ->call( 'POPFile/API.get_session_key', 
			      'admin', '' )->result;

my $bk=get_buckets();


# Add users
my $usr = $dbh->prepare("select uid,login,Name  from Users natural join Groups natural join UserGroups");
$usr->execute();
# my $res=$usr->fetchall_hashref("login");
my $gl;
while (my $r = $usr->fetchrow_hashref) 
{
	$gl->{$r->{"login"}}->{$r->{"Name"}} ++;
}


use Data::Dumper;

# print Dumper($bk);
# print Dumper($gl);

my $hdr ="";
my @bk=sort keys(%$bk);
my $ind="";
foreach( @bk )
{
	$hdr .= $ind . ",-".$_."\n";
	$ind .=  "|".(" " x 3) ;
}
print "$hdr";
foreach my $u ( sort keys %$gl )
{
	my $l="";
	foreach( @bk )
	{
		#my $a=$_;
		#$a =~ s/\S/ /g;
		my $s=".";
		$s="X" if $gl->{$u}->{$_};
		$l .= $s.(" " x 3) ;
	}
	print "$l  $u\n";
}



$dbh->disconnect();

exit(0);
#===================================================
sub add_bucket
{
	my $bucket=shift;
	my $r=
	XMLRPC::Lite->proxy('http://localhost:8081/RPC2')
	 ->call('POPFile/API.create_bucket', $popsession, $bucket)->result;
	warn "Cannot create bucket" unless $r;
}
sub get_buckets
{
	my $bk;
	my $r=
	    XMLRPC::Lite->proxy('http://localhost:8081/RPC2')
	     ->call('POPFile/API.get_all_buckets',$popsession)->result;
	foreach( @$r )
	{
	    $bk->{$_}=1;
	}
	return $bk;
}




