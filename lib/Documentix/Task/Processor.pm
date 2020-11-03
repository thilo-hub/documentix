package Documentix::Task::Processor;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use doclib::pdfidx;
use Documentix::dbaccess;;

my $minion;
sub register {
  my ($self, $app) = @_;
  $minion=$app->minion;
  $minion->add_task(loader => \&_loader);
  $minion->add_task(ocr => \&_ocr);
  $minion->add_task(refreshIndexes => \&_indexes);
}
my $maintenance_queued =0;
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
	return if $maintenance_queued++;
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
  $DB::single = 1;
	$maintenance_queued=0;
	my $pdfidx  = pdfidx->new(0,$Documentix::config);
	my $res=$pdfidx->dbmaintenance(@args);
	$job->finish(\$res);
}

1;
