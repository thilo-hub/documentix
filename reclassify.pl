#!/usr/bin/perl -It2
use strict;
use warnings;
use Data::Dumper;
use pdfidx;
my $pdfidx=pdfidx->new();

my $maxcnt=$ARGV[0] || 999999;
classify($pdfidx,$maxcnt);


sub classify {
    my $self = shift;
    my $count = shift;
    my $dh   = $self->{"dh"};
    $dh->sqlite_busy_timeout( 60000 );


    my $sh=$dh->prepare(q{select idx,md5,value,file from hash natural join metadata natural join file where tag ="Text" group by md5});
    my $upd=$dh->prepare(q{insert or replace into metadata (idx,tag,value) values(?,?,?)});
    $sh->execute();
    while (my $r = $sh->fetchrow_hashref) 
    {
	last if $count-- == 0;
	$dh->do("begin transaction");
	    my ($ln,$class)=$self->pdf_class($r->{"file"},$r->{"value"},$r->{"md5"},0);
	    #my $class="X";
	    print "$class\t$r->{file}\n";
	    # $upd->execute($r->{"idx"},$class);
	    print spell($r->{"value"})."\n";
	    $upd->execute($r->{"idx"},"Class",$class);
	    $upd->execute($r->{"idx"},"PopFile",$ln) if $ln;
    $dh->do("commit");
    }
    die "$sh->err" if $sh->err;
    # make sure we skip already ocred docs

}
sub spell
{
	my $tx=shift;
	use IPC::Open3;
	my $pid=open3(my $in,my $out,\*ERR,qw{hunspell -G -H -i utf-8 -d},"de_DE,en_EN");
	if ( fork() == 0 )
	{
		close $out;
		close ERR;
		print $in $tx;
		close($in);
		exit(0);
	}
	if ( fork() == 0 )
	{
		close $out;
		close $in;
		while(<ERR>)
		{ };
		close(ERR);
		exit(0);
	}

	close($in);
	close(ERR);
	my $good=0;
	my $idx;
	while(<$out>)
	{
		next if /^..?.?.?$/;
		chomp;
		$idx->{length($_)}->{$_}++;
	}
	close($out);
	while ( wait > 0){}
	#waitpid $pid, 0;
	my @l=sort { $b <=> $a } keys %$idx;
	$out=length($tx);
	while(@l && length($out)<60 )
	{
		my $i=shift(@l);
		$out .= " ".join(" ",keys %{$idx->{$i}} );
	}
	$out =~ s/(.{1-40})\s.*/$1/;
	return $out;
}

