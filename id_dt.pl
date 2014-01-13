#!/usr/bin/perl -It2
use DBI qw(:sql_types);

use strict;
use warnings;
use pdfidx;
use Cwd 'abs_path';

my $pdfidx = pdfidx->new();

my $popfile = "/var/db/pdf/start_pop";

my $popf=$pdfidx->pop_session();
$pdfidx->pop_release;
die "No popfile running"
	unless $popf;
use datematch;

open(UNUSED,">unused.out");


# system($popfile);
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
#
#
my $dh = $pdfidx->{"dh"};
my $get_f =
  $dh->prepare("select idx,md5 from file natural join hash  where file=?");
my $new_f = $dh->prepare("insert or replace into file (md5,file) values(?,?)");

$dh->do("begin exclusive transaction");

# read all files into index
#foreach (@ARGV)
while (<>) {
    s/\s*$//;
    next if /\.ocr.pdf$/;
    next unless -f $_;
    my $inpdf = abs_path($_);
    next unless -r $inpdf;
    my ($idx) = $dh->selectrow_array( $get_f, undef, $inpdf );

    #print "GOT: $inpdf\n" if $idx;
    print STDERR "." if $idx;
    next if $idx;
    flushdb($dh);
    my $md5_f = file_md5_hex($inpdf);

    $new_f->execute( $md5_f, $inpdf );

    # print "NEW: $inpdf\n";
    print STDERR "+";
}
my $it_idx = $dh->prepare(
    q{select idx,md5,file from hash natural join file order by idx desc});
my $gt_md = $dh->prepare(q{select tag,value from metadata where idx=?});
$it_idx->execute();
$dh->do(q{ create table if not exists ldates ( idx integer, date text, string text,unique  (idx,date))});
my $ins=$dh->prepare(q{insert or replace into ldates  values(?,?,?)});
use Data::Dumper;
my @list;
while ( my $r = $it_idx->fetchrow_hashref ) {
	push @list,$r;
}
printf STDERR "Process: %d files\n",scalar(@list);
my $chk=0;
my %md5_;
while(@list)
{
    my $r=shift @list;
    my $idx   = $r->{"idx"};
    my $md5_f = $r->{"md5"};
    next if $md5_{$md5_f}++ >0;
    next unless -r $r->{"file"};
    my $m= "Ck: $r->{idx} $r->{file}\n";
    flushdb($dh);
    $chk++;

    $gt_md->execute( $r->{"idx"} );
    my $dt = $gt_md->fetchall_hashref("tag");
    next unless ( $dt->{"hash"} ) ;
    next unless ( $dt->{"mtime"} ) ;
    next unless ( $dt->{"Docname"} ) ;
    next unless ( $dt->{"pdfinfo"} ) ;
    next unless ( $dt->{"Text"} ) ;
    my $t=$dt->{"Text"}->{"value"};
    my $i=undef;
    do {
	my ($un,$tm,$m,$l)=datematch::extr_date($t);
	if($tm){
	    $ins->execute($idx,$tm,$m);
	    print "$tm\t$m\n";
	    $l =~ s/$m//gs;
	}
	$i .= $un;
	$t=$l;
    } while ($t);
    print UNUSED $i;
    next unless ( $dt->{"Class"} || !defined $dt->{"Text"} ) ;
}
$dh->do("commit");
printf STDERR "Checked: $chk files\n";

exit(0);
my $op = q{select idx from hash except select idx from metadata where tag=?};
$op = qq{ select idx,file,md5 from ($op) natural join hash natural join file};
my $get_idx = $dh->prepare($op);
my $ins_d =
  $dh->prepare("insert or replace into data (idx,thumb,ico) values(?,?,?)");
my $op2 =
  q{select idx from hash except select idx from data where thumb is not NULL};
$op2     = qq{select idx,file from ($op2) natural join hash natural join file};
$get_idx = $dh->prepare($op2);
$get_idx->execute();

while ( my $r = $get_idx->fetchrow_hashref ) {
    print "Ck: $r->{idx} $r->{file}\n";
    next unless -r $r->{"file"};
    my $fn    = $r->{"file"};
    my $idx   = $r->{"idx"};
    my $thumb = $pdfidx->pdf_thumb($fn);
    my $ico   = $pdfidx->pdf_icon($fn);
    $ins_d->bind_param( 1, $idx,   SQL_INTEGER );
    $ins_d->bind_param( 2, $thumb, SQL_BLOB );
    $ins_d->bind_param( 3, $ico,   SQL_BLOB );
    $ins_d->execute();

}
exit(0);

{
    my $t0 = time() + 60;

    sub flushdb {
        my $dh = shift;
        return unless ( defined($t0) && $t0 < time() );
        $t0 = time() + 60;
        $dh->do("commit");
        $dh->do("begin exclusive transaction");
        print STDERR "Flushdb\n";
    }
}
