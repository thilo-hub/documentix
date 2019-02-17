#!/usr/bin/perl
# Basic template for this machine

use strict;
use warnings;
use lib ".";



use dirlist;
use Data::Dumper;
use JSON::PP;
use URI::Escape;

my $json        = JSON::PP->new->utf8;
my $json_text = uri_unescape($ENV{"ARGS"});
my $perl_scalar = $json->decode($json_text);

# Call whatever
my $dl=dirlist->new();
print $dl->list($perl_scalar->{"args"});



