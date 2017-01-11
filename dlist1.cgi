#!/usr/bin/perl
# Basic template for this machine


use dirlist;
use Data::Dumper;
use JSON::PP;
use URI::Escape;
use Docconf;

my $json        = JSON::PP->new->utf8;
$json_text = uri_unescape($ENV{"ARGS"});
my $perl_scalar = $json->decode($json_text);

print STDERR ">>".Dumper($perl_scalar)."<<\n" if $Docconf::config->{"debug"} >2;
$d=$perl_scalar->{args}->{node};
# print STDERR ">>$d<<\n";
$root=".";  #TODO config
print STDERR "Dir: $d\n" if $Docconf::config->{"debug"} >2;
$data = dlist($d);
# $json = $json->canonical(1);
my $r= $json->encode($data);
print "\n$r";
exit(0);

#==================
sub dlist {
    my $dir = shift;

    my @out;

    my $fullDir = $Docconf::config->{"root_dir"} . $dir;

    exit if !-e $fullDir;

    opendir( BIN, $fullDir ) or die "Can't open $dir: $!";
    my (@fout);
    while ( defined( my $file = readdir BIN ) ) {
        next if $file eq '.' or $file eq '..';
        if ( -d "$fullDir/$file" ) {
	    push @out, { name => $file, id=>"$dir/$file", load_on_demand=>1, is_dir=>1};
        }
        else {
	    push @fout, { name => $file, id=>"$dir/$file", load_on_demand=>0, is_dir=>0};
        }
    }
    closedir(BIN);
    push @out,@fout;

    return \@out;
}
