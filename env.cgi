#!/usr/bin/perl
use CGI;
use Data::Dumper;

my $q = CGI->new;
print $q->header(-charset=>'utf-8'),
$q->start_html(-title=>'env');
print "<PRE>\n";
print Dumper($q->Vars);
print Dumper(\%ENV);
print "</PRE>\n";
print end_html;
		 

