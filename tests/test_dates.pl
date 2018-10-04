#!/usr/bin/perl -w
use lib ".";

use doclib::pdfidx;
use doclib::datelib;


#Add missing databas information

# update date match infos into database.

my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }
datelib::fixup_dates($pdfidx->{"dh"});

exit(0);
