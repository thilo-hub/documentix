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

sub _ocr {
  my ($job, @args)=@_;
  my $pdfidx  = pdfidx->new(0,$Documentix::config);
  $job->finish( $pdfidx->ocrpdf_sync(@args));
}

sub _loader {
  my ($job, $dgst,$fn,$type,$wdir) = @_;
  my $class = undef;

  my $pdfidx  = pdfidx->new(0,$Documentix::config);
  my @results=@_;
  say 'Process';
  # sleep 1;
  $DB::single = 1;
  my $txt = $pdfidx->index_pdf_raw( $fn, $wdir,$class,$dgst ,$type);
  # $ld_r->update_caches();
  say 'done';
  $results[5] = {summary=>$txt,url=>"/docs/pdf/$dgst/result.pdf"};
  $job->finish(\@results);
}

sub _indexes {
	my ($job, @args)=@_;
  $DB::single = 1;
	my $pdfidx  = pdfidx->new(0,$Documentix::config);
	my $res=$pdfidx->dbmaintenance(@args);
	$job->finish(\$res);
}

sub  schedule_ocr
{
        $minion->enqueue(ocr=> [@_]=>{priority=>1} );

}

sub schedule_maintenance
{
        $minion->enqueue(refreshIndexes=> [@_]=>{priority=>0} );
}
1;
