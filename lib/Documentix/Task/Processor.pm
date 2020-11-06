package Documentix::Task::Processor;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use doclib::pdfidx;
use Documentix::dbaccess;;
use File::MimeInfo::Magic;
use Mojo::File qw{curfile path };
use Mojo::Asset::File;
use File::Path qw(make_path );
use File::Find qw{find};
use Data::Dumper;

our $minion;
sub register {
  my ($self, $app) = @_;
  $minion=$app->minion;
  $minion->add_task(loader => \&_loader);
  $minion->add_task(ocr => \&_ocr);
  $minion->add_task(refreshDirectories => \&_refresh);
  $minion->add_task(refreshIndexes => \&_indexes);
}
sub schedule_refresh 
{
	$minion->enqueue(refreshDirectories=>[@_]=>{priority=>0});
}

sub schedule_loader
{
	$minion->enqueue(loader=>[@_]=>{priority=>2});
}
sub  schedule_ocr
{
        $minion->enqueue(ocr=> [@_]=>{priority=>1} );
}

sub schedule_maintenance
{
        $minion->enqueue(refreshIndexes=> [@_]=>{priority=>0} );
}
sub _ocr {
  my ($job, @args)=@_;
  my $pdfidx  = pdfidx->new(0,$Documentix::config);
  $DB::single = 1;
  $job->finish( $pdfidx->ocrpdf_sync(@args));
  schedule_maintenance();
}

sub _loader {
  my ($job, $dgst,$fn,$tags) = @_;
  my $class = undef;

  my $pdfidx  = pdfidx->new(0,$Documentix::config);
  my @results=@_;
  say 'Process';
  # sleep 1;
  $DB::single = 1;
  my $txt = $pdfidx->load_file(  "application/pdf",{file=>$fn,taglist=>$tags});
  say 'done';
  $results[5] = {summary=>$txt,url=>"/docs/pdf/$dgst/result.pdf"};
  $job->finish(\@results);
  schedule_maintenance();
}
sub _indexes {
	my ($job, @args)=@_;
       return $job->finish('Previous job is still active')
	                    unless my $guard = $minion->guard('maintenance', 7200);

  $DB::single = 1;
	my $pdfidx  = pdfidx->new(0,$Documentix::config);
	my $res=$pdfidx->dbmaintenance(@args);
	$job->finish(\$res);
}
my %mime_supported = (
    "application/zip" => 1,
    "application/x-gzip" => 1,
    "application/pdf"    => 1,
    "application/msword" => 1,
    "image/png"         => 1,
    "image/jpeg"         => 1,
    "image/jpg"         => 1,
    "text/plain"	     => 1,
"application/vnd.openxmlformats-officedocument.presentationml.presentation" => 1,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => 1,
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => 1,
    "application/epub+zip"          => 1,
    "application/vnd.ms-powerpoint" => 1
);

sub _refresh {
    my ($job,$top) = @_;
    return $job->finish('Previous job is still active')
	    unless my $guard = $minion->guard('load_directories', 7200);
    my $pdfidx  = pdfidx->new(0,$Documentix::config);
    my $dba = dbaccess->new();
    my $check = $pdfidx->{dh}->prepare_cached(q{select md5,file from file where file not like ? and file like ?});

    $top = Mojo::File->new($top);
    my $skip= Mojo::File->new($Documentix::config->{local_storage})->to_abs;
    $check->execute( $Documentix::config->{local_storage}."%",$Documentix::config->{root_dir}."%" );
    my $md5 = Digest::MD5->new;
    my $ignore={};
    my @flist=();
    my $update_file = sub
    {
	print STDERR "File changed @_\n";
    };
    my $remove_file = sub
    {
	print STDERR "File removed @_\n";
    };
    my $add_file = sub
    {
	my $f = shift;
	print STDERR "File added @_\n";
	    my $type = mimetype($f);
	    if ( $mime_supported{$type}) {
		push @flist,$f;
		return;
	    }
	    die "Type: $type";
    };

    my  $process = sub  {
	    return unless -f $_;
	    my $f = $File::Find::name;
	    return if $ignore->{$f};
	    return if $f =~ /^$skip/;
	    $f =~ s|^$top|$Documentix::config->{root_dir}|;

	    $add_file->($f);

    };

    # Check local files in db
    while ( my $r = $check->fetchrow_hashref) 
    {
	print STDERR Dumper ($r);
	$remove_file->($r) unless -r $r->{file};
	my $asset = Mojo::Asset::File->new(path => $r->{file});
	my $dgst = $md5->add($asset->slurp)->hexdigest;
	$update_file->($r) unless $r->{md5} eq $dgst;
	$ignore->{ Mojo::File->new($r->{file})->to_abs }++;
    }
    # check filesystem

    find( { wanted => $process }, $top );

    my $as=Mojo::Asset::File->new();
    foreach( @flist ) {
	$dba->load_file("??APP??",$as,$_);
    }



}

1;
