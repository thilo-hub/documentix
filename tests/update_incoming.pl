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
	q{update file set file=? where md5=?});

my $sel=$pdfidx->{"dh"}->prepare(
	q{select md5,file  from file});

$sel->execute();
 while ( my $r = $sel->fetchrow_hashref ) {
	next unless -d "$wdir/$r->{md5}";
	my $od=$r->{"md5"};
	$od =~ s|^(..)|$1/$1|;
	mkdir "$wdir/$1" unless -d "$wdir/$1";
	rename $r->{"file"}, "$wdir/$od";
	$upd->execute("$wdir/$od",$r->{"md5"});
        print ">> ".Dumper($r);
    }
  
