#!/usr/bin/perl 
use DBI qw(:sql_types);

use strict;
use warnings;
use doclib::pdfidx;
use Cwd 'abs_path';
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
use Sys::Hostname;
# use Data::Dumper;

my $pdfidx = pdfidx->new();

my $use_popfile=1;

my $only_listed=1;

if($use_popfile){
    my $popf=eval {$pdfidx->pop_session()};
    unless ($popf)
    {
	 print STDERR "Start popfile....\n";
	 system('perl ./start_pop.pl $PWD');
	 $popf=$pdfidx->pop_session();
    }
    die "No popfile running"
	    unless $popf;

    $pdfidx->pop_release;

}

#
#
my $dh = $pdfidx->{"dh"};
my $get_f =
  $dh->prepare("select idx,md5 from file natural join hash  where file=?");
my $new_f = $dh->prepare("insert or replace into file (md5,file,host) values(?,?,?)");

$dh->do("begin transaction");
$dh->do("create temporary table pfiles (idx,md5,file)")
	if $only_listed;

# read all files into index
#foreach (@ARGV)

my $ins_p1=$dh->prepare("insert into pfiles (idx,md5,file) select idx,md5,? from hash where idx=?");
my $ins_p2=$dh->prepare("insert into pfiles (idx,md5,file) select idx,md5,? from hash where md5=?");
while (<>) {
    s/\s*$//;
    next if /\.ocr.pdf$/;
    next unless -f $_;
    my $inpdf = abs_path($_);
    next unless -r $inpdf;
    my ($idx) = $dh->selectrow_array( $get_f, undef, $inpdf );

    #print "GOT: $inpdf\n" if $idx;
    print STDERR "." if $idx;
    $ins_p1->execute($inpdf,$idx)
	if $idx && $only_listed;
    next if $idx;
    flushdb($dh);
    my $md5_f = file_md5_hex($inpdf);

    $new_f->execute( $md5_f, $inpdf,hostname() );
    $ins_p2->execute($inpdf,$md5_f)
	if $only_listed;
    # print "NEW: $inpdf\n";
    print STDERR "+";
}
my $it_idx = $dh->prepare(
   ($only_listed ? 
	    q{select idx,md5,file from pfiles order by idx desc}
    :
	    q{select idx,md5,file from hash natural join file order by idx desc}
    )
    );
my $gt_md = $dh->prepare(q{select tag,value from metadata where idx=?});
$it_idx->execute();
my @list;
while ( my $r = $it_idx->fetchrow_hashref ) {
#	next unless -f $r->{"file"};
	next if($r->{"file"} =~  m|pdf.js/test/pdfs/|); # ignore test-files
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
    unless ( $dt->{"hash"} ) {
	print STDERR "$m" ; $m="";
        print STDERR "Hash\n";
        $pdfidx->ins_e( $idx, "hash", $md5_f );
        $dt->{"hash"}->{"value"} = $md5_f;
    }
    unless ( $dt->{"mtime"} ) {
	print STDERR "$m" ; $m="";
        print STDERR "mtime\n";
        my $mt = ( stat( $r->{file} ) )[9];
        $pdfidx->ins_e( $r->{idx}, "mtime", $mt );
    }
    unless ( $dt->{"Docname"} ) {
	print STDERR "$m" ; $m="";
        print STDERR "Docname\n";
        my $fn = $r->{file};
        $fn =~ s|^.*/||;
        $pdfidx->ins_e( $r->{"idx"}, "Docname", $fn );
    }
    unless ( $dt->{"pdfinfo"} ) {
	print STDERR "$m" ; $m="";
        print STDERR "pdfinfo\n";
        my $info = $pdfidx->pdf_info( $r->{"file"} );
        $pdfidx->ins_e( $r->{"idx"}, "pdfinfo", $info )
          if $info;
    }
    unless ( $dt->{"Text"} ) {
	print STDERR "$m" ; $m="";
        print STDERR "Text";
        $dh->do("commit");
	chomp(my $type=qx|file -b --mime-type "$r->{file}"|);
	my %handler=(
		"application/x-gzip" => \&tp_gzip,
		"application/pdf"    => \&tp_pdf
		);

	$type = $handler{$type}($r,$dt)
		while $handler{$type};

        print STDERR " -> $type\n";
        $dh->do("begin transaction");
    }
    unless ( $dt->{"Class"} || !defined $dt->{"Text"} ) {
	print STDERR "$m" ; $m="";
        print STDERR "Class ";

        my ( $PopFile, $Class ) = (
            $pdfidx->pdf_class(
                $r->{"file"}, \$dt->{"Text"}->{"value"},
                $dt->{"hash"}->{"value"},0
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
    my ($th_typ,$thumb) = $pdfidx->pdf_thumb($fn);
    my ($ic_typ,$ico)   = $pdfidx->pdf_icon($fn);
die " Changed return to return type extra, but what is in the DB?";
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


sub tp_gzip
{
	my $r=shift;
	my $i=$r->{"file"};
	$r->{"file"} = "/tmp/tmp.pdf";
	qx|gzip -dc $i > "$r->{file}"|;
	chomp(my $type=qx|file -b --mime-type "$r->{file}"|);
	return $type;
}
sub tp_pdf
{
my $r=shift;
my $dt=shift;
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
  my $l=length($t) || "-FAILURE-";
  return "FINISH ($l)";
}

