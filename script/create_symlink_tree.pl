#!/usr/bin/perl

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

}



