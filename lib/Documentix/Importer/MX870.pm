#!/usr/bin/perl
#copyright Thilo Jeremias
package Documentix::Importer::MX870;

use Data::Dumper;
use strict;
use warnings;
my $debug=1;

my $srv=$Documentix::config->{scanner_MX870};
push @Documentix::Importer::importer,\&getFiles
	if  $srv;


use File::Basename;
use Date::Parse;

sub getFiles {
	my $dir="CANON_SC/DOCUMENT/0001";

	my $dst="/var/tmp/Scanner_card";

	my @new;
	mkdir $dst unless -d $dst;


	my @onserver = qx{smbclient -N $$srv[0] -D $dir  -c  dir 2>/dev/null };
	foreach ( @onserver )
	{
	    print STDERR  "$_" if $debug ||/error/i;
	# file....      DH        0  Thu Dec 17 13:11:48 2020
	    next unless /^\s*(.*?)\s+(\S+)\s+(\d+)\s+((\S+)\s+(\S+)\s+(\d+)\s+([0-9:]+)\s+(\d+))$/;
	    next if $2 eq "D" or $1 eq "DH";
	    my $f="$dst/$1";
	    my $s= $3;
	    my $t = str2time($4);
	    my ( $sf, $tf ) ;

	    my $o=undef;
	    next if -d $f; 
	    # Check if same file is already known (size & date & name)
	    next if  -f $f
	      && (( $sf, $tf ) = ( stat($f) )[ 7, 9 ] )
	      && $sf == $s
	      && $tf == $t ;

	    unlink($f) if -f $f; # this is ONLY a folder that shows! what is on the card
	    # The new files will be duplicated into the hashed list

	    #Get
	    system("smbget -a 'smb:$$srv[0]/$dir/$1' -o '$f'");
	    utime($t,$t,$f);

	    push @new,$f;
	    print STDERR "Downloaded -> $f\n";
	}

	if (@new) {

		print STDERR "Updating...\n";
		print STDERR Dumper(@new);
	}
	return @new;
}
1;
