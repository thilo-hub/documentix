#!/usr/bin/perl
use doclib::pdfidx;
use Data::Dumper;
use Docconf;


#Add missing databas information

# list files in database but not in file-system

# 1)  Add size tag to metadata

my $pdfidx = pdfidx->new();
sub lock   { }
sub unlock { }

sub get_store{ }

my $wdir = $Docconf::config->{local_storage};
my $upd=$pdfidx->{"dh"}->prepare(
	q{update file set file=? where rowid=?});

my $sel=$pdfidx->{"dh"}->prepare(
	q{select md5,file,rowid  from file});

$pdfidx->{"dh"}->do("begin transaction");
$sel->execute();
 while ( my $r = $sel->fetchrow_hashref ) {
	next unless -d "$wdir/$r->{md5}";
	next unless $r->{"file"} =~ m|$wdir/$r->{md5}/.*|;
	my $od=$r->{"md5"};
	$od =~ s|^(..)|$1/$1|;
	my $pf=$1;
	mkdir "$wdir/$pf" or die "mkdir $!"  unless -d "$wdir/$pf";
	rename "$wdir/$r->{md5}", "$wdir/$od" or die "rename $!" ;
	my $fn=$r->{"file"};
	$fn =~ s|$r->{md5}|$pf/$r->{md5}|;
	die "Failed: $fn" unless -f $fn;
	$upd->execute($fn,$r->{"rowid"});
        print ">> ".Dumper($r);
    }
  
$pdfidx->{"dh"}->do("commit");
