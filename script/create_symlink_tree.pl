#!/usr/local/bin/perl

# Run this to convert all image.png (screen-copy & paste)  into more meaningfull names...
use lib "/documentix/lib";
use lib "../documentix/lib";
use File::Path qw(make_path);
use File::Basename;


BEGIN {
    $Documentix::config = require "./documentix.conf";
}
use Data::Dumper;
use Documentix::dbaccess;
use File::Basename;
$Data::Dumper::Sortkeys=1;

my @tags = @ARGV;




$dst = "Docs/uploads/tags";
use File::Path qw(make_path);

$dh = dbaccess->new();

$dh->{dh}->do(qq{CREATE VIEW if not exists idxfile(idx,md5,file) as select idx,md5,file from hash natural join file});

$dh->{dh}->do(qq{
	CREATE VIEW if not exists taglist as
	with tglist as (
	select count(*) rank,tagid,tagname  from tags natural join tagname  group by tagid order by rank desc)
	select idx,group_concat(tagname,'/') tags from tags natural join tglist  group by idx
	});

$q = $dh->{dh}->prepare(qq{select * from idxfile natural join taglist});
$q->execute();
my $destroot = "Docs/Tagged";
while ( my $r = $q->fetchrow_hashref() ) {
    print Dumper($r);
    $DB::single=1;
    my $dst = join("/",$destroot,$r->{tags},basename($r->{file}));
    make_path(join("/",$destroot,$r->{tags}));
    symlink($r->{file},$dst);
    my $ocr = "Docs/uploads/$1/$r->{md5}/".basename($r->{file},".pdf").".ocr.pdf"
    	if $r->{md5} =~ m/^(..)/;
    symlink($ocr,$dst.".ocr.pdf")
    	if -r $ocr;

}



