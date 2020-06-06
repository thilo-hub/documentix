package MyApp::Task::Processor;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use doclib::pdfidx;
my $pdfidx  = pdfidx->new(0);

my $minion;
sub register {
  my ($self, $app) = @_;
  $minion=$app->minion;
  $minion->add_task(loader => \&_loader);
  $minion->add_task(ocr => \&_ocr);
}

sub _ocr {
  my ($job, @args)=@_;
  $job->finish( $pdfidx->ocrpdf_sync(@args));
}

sub _loader {
  my ($job, $dgst,$fn,$type,$wdir) = @_;
  my $class = undef;

  my @results=@_;
  say 'Process';
  # sleep 1;
  $DB::single = 1;
  my $txt = $pdfidx->index_pdf_raw( $fn, $wdir,$class,$dgst ,$type,$minion);
  # $ld_r->update_caches();
  say 'done';
  $results[5] = $txt;
  $job->finish(\@results);
}

1;
