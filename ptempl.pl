#!/usr/bin/perl
use CGI;
my $_GET=CGI->new;
while (<>) { $in .= $_; }
$_ = $in;
s/^#!.*?\n/Content-type: text\/html; charset=utf-8\n\n/s;
s/\?>(.*?)<(\?php|\?=)/put_o($1)/gse;
s/^(.*)<(\?php|\?=)/put_o($1);/se;
s/\?>(.*)$/put_o($1)/es;
sub put_o
{
	my $s=shift;
	$s =~ s/{/&gt;/g;
	$s =~ s/}/&lt;/g;
	return ";\nprint q{$s};\n"; #q{$s};\n";
	return ";\nprint <<STRT;\n$s\nSTRT\n"; #q{$s};\n";
}
my $m=$_;
my $s=$m;
if($_GET->param('source'))
{
	print "Content-type: text/text\n\n$_\n";
}
else
{
	open(F,">/tmp/tmpl.pl");
	print F $_;
	close(F);
	eval($_) || print "ERR: $@\n";
}
