#!/usr/bin/perl

use Docconf;
my $r = $Docconf::config->{ $ARGV[0] };
$e->{"set"} = qq{{"$ARGV[0]" : "$ARGV[1]"}} if ( scalar(@ARGV) > 1 );
$e->{"save"} = 1;
Docconf::getset($e);
print "$r";
