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

# system($popfile);
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
#
#
my $dh = $pdfidx->{"dh"};
my $get_f =
  $dh->prepare("select idx,md5 from file natural join hash  where file=?");
my $new_f = $dh->prepare("insert or replace into file (md5,file) values(?,?)");
my $new_m = $dh->prepare("insert or ignore into hash (md5) values(?)");

$dh->do("begin transaction");

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
    $new_m->execute($md5_f);

    # print "NEW: $inpdf\n";
    print STDERR "+";
}
my $it_idx = $dh->prepare(
    q{select idx,md5,file from hash natural join file order by idx desc});
my $gt_md = $dh->prepare(q{select tag,value from metadata where idx=?});
$it_idx->execute();
use Data::Dumper;
while ( my $r = $it_idx->fetchrow_hashref ) {
    my $idx   = $r->{"idx"};
    my $md5_f = $r->{"md5"};
    next unless -r $r->{"file"};
    print STDERR "Ck: $r->{idx} $r->{file}\n";
    flushdb($dh);

    $gt_md->execute( $r->{"idx"} );
    my $dt = $gt_md->fetchall_hashref("tag");
    unless ( $dt->{"hash"} ) {
        print STDERR "Hash\n";
        $pdfidx->ins_e( $idx, "hash", $md5_f );
        $dt->{"hash"}->{"value"} = $md5_f;
    }
    unless ( $dt->{"mtime"} ) {
        print STDERR "mtime\n";
        my $mt = ( stat( $r->{file} ) )[9];
        $pdfidx->ins_e( $r->{idx}, "mtime", $mt );
    }
    unless ( $dt->{"Docname"} ) {
        print STDERR "Docname\n";
        my $fn = $r->{file};
        $fn =~ s|^.*/||;
        $pdfidx->ins_e( $r->{"idx"}, "Docname", $fn );
    }
    unless ( $dt->{"pdfinfo"} ) {
        print STDERR "pdfinfo\n";
        my $info = $pdfidx->pdf_info( $r->{"file"} );
        $pdfidx->ins_e( $r->{"idx"}, "pdfinfo", $info )
          if $info;
    }
    unless ( $dt->{"Text"} ) {
        print STDERR "Text\n";
        my $t = $pdfidx->pdf_text( $r->{"file"}, $r->{"md5"} );
        if ($t) {
            $pdfidx->ins_e( $r->{"idx"}, "Text", $t );

            # short version
            $t =~ m/^\s*(([^\n]*\n){24}).*/s;
            my $c = $1 || "";
            $pdfidx->ins_e( $r->{"idx"}, "Content", $c );
            $dt->{"Text"}->{"value"}    = $t;
            $dt->{"Content"}->{"value"} = $c;
        }
    }
    unless ( $dt->{"Class"} || !defined $dt->{"Text"} ) {
        print STDERR "Class ";
        my ( $PopFile, $Class ) = (
            $pdfidx->pdf_class(
                $r->{"file"}, substr($dt->{"Text"}->{"value"},0,100000),
                $dt->{"hash"}->{"value"}
            )
        );
        $Class   = "----" unless $Class;
        $PopFile = "----" unless $PopFile;
        $pdfidx->ins_e( $r->{"idx"}, "Class",   $Class );
        $pdfidx->ins_e( $r->{"idx"}, "PopFile", $PopFile );
        print STDERR " $Class\n";
        $dh->do("commit");
        $dh->do("begin transaction");
    }
}
$dh->do("commit");

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
        $dh->do("begin transaction");
        print STDERR "Flushdb\n";
    }
}
