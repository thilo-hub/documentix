#!/usr/bin/perl

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
use doclib::pdfidx;
my $pdfidx=pdfidx->new();
my $dbh=$pdfidx->{"dh"};
use XMLRPC::Lite;
my $popsession  = XMLRPC::Lite->proxy('http://localhost:8081/RPC2')
                      ->call( 'POPFile/API.get_session_key', 
			      'admin', '' )->result;



my @users = (
	[1,'admin','adminpw','0'], # admin account
	[2,'test','testpw','0'], # readonly account
	);
my @groups = (
	[1,'admins'], # admin group
	[2,'users'], # some other group
	);
my %user_groups = (
	'admin' => [ 
	    	     ['admins',3],
		     ['users',3],
		   ],
	'test' => [ 
		     ['users',3],
		   ],
	);

# Add users
my $uids;
my $adduser = $dbh->prepare("INSERT or replace INTO Users (uid,login,passwd,Disabled) VALUES (?,?,?,?)")
	or die "can't prepare new user statement: $DBI::errstr";
foreach my $user (@users)
{
	print STDERR "Install user: $user->[0]($user->[1]) pw:$user->[2]\n";
	$user->[2] = Digest::MD5::md5_base64($user->[2]);
	$adduser->execute(@{$user}) or die "can't insert user: $DBI::errstr";
	$uids->{$user->[1]}=$user->[0];
}
$adduser->finish;

# Add groups
my $bk=get_buckets();
my $gids;
my $addgroup = $dbh->prepare("INSERT or replace INTO Groups (gid,Name) VALUES (?,?)")
	or die "can't prepare new user statement: $DBI::errstr";
foreach my $group (@groups)
{
	$addgroup->execute(@{$group}) or die "can't insert group: $DBI::errstr";
	add_bucket($group->[1]) unless $bk->{$group->[1]};
	$gids->{$group->[1]}=$group->[0];
	print STDERR "Installed group $group->[1]\n";
}
$addgroup->finish;

# Put users into groups
my $add_ug = $dbh->prepare("INSERT or replace INTO UserGroups (uid,gid,accessbit) VALUES (?,?,?)")
	or die "can't prepare new usergroup statement: $DBI::errstr";
foreach my $uid (keys %user_groups)
{
	foreach my $access ( @{$user_groups{$uid}} )
	{
		print STDERR "Install rigth: $uid -> $access->[0]\n";
	    	$access->[0]=$gids->{$access->[0]};
		$add_ug->execute($uids->{$uid}, @{$access}) or die "can't insert usergroup: $DBI::errstr";
	}
}
$add_ug->finish;

$dbh->disconnect();

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




