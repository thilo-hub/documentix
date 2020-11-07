package Documentix::Task::Processor;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Mojo::Asset::File;
use doclib::pdfidx;
use Documentix::dbaccess;;
#use File::MimeInfo::Magic;
# use File::Path qw(make_path );
use Documentix::scantree;

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
sub _refresh {
    my ($job,$top) = @_;
    return $job->finish('Previous job is still active')
	    unless my $guard = $minion->guard('load_directories', 7200);
    Documentix::scantree::scantree($top);
    }
1;
