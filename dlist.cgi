#!/usr/bin/perl
# Basic template for this machine


use dirlist;
use Data::Dumper;
use JSON::PP;
use URI::Escape;

my $json        = JSON::PP->new->utf8;
$json_text = uri_unescape($ENV{"ARGS"});
my $perl_scalar = $json->decode($json_text);

# Call whatever
my $dl=dirlist->new();
print $dl->list($perl_scalar->{"args"});



