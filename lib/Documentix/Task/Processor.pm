package Documentix::Task::Processor;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Mojo::Asset::File;
use doclib::pdfidx;
use Documentix::dbaccess;;
use Documentix::db qw{dbmaintenance};
# use File::Path qw(make_path );
use Documentix::scantree;

our $minion;
sub register {
  my ($self, $app) = @_;
  $minion=$app->minion;
  $minion->add_task(ocr => \&_ocr);
  $minion->add_task(loader => \&_loader);
  $minion->add_task(refreshDirectories => \&_refreshDirectories);
  $minion->add_task(refreshIndexes => \&_refreshIndexes);
  #  schedule_maintenance();
}

#############################
sub  schedule_ocr
{
        $minion->enqueue(ocr=> [@_]=>{priority=>1} );
}

sub _ocr {
  my ($job, @args)=@_;
  my $pdfidx  = pdfidx->new(0,$Documentix::config);
  $job->on( finish => &schedule_maintenance );
  $job->finish( $pdfidx->ocrpdf_sync(@args));
}

#############################
sub schedule_loader
{
	my $id = $minion->enqueue(loader=>[@_]=>{priority=>2});
        $minion->result_p($id);
	print STDERR "YYYYYYYYYYYYYYYYYYYY OK\n";

}
sub _loader {
  my ($job, $dgst,$fn,$tags) = @_;
  my $class = undef;

  my $pdfidx  = pdfidx->new(0,$Documentix::config);
  my @results=@_;
  say 'Process';
  # sleep 1;
  my $txt;
  eval { 
$DB::single=1;
	$txt = $pdfidx->load_file(  "application/pdf",{file=>$fn,hash=>$dgst,_taglist=>$tags});
  };
  if ( $@ ) {
	# $Documentix::db::dh->disconnect();
	$pdfidx->fail_file($job->id,{hash=>$dgst});
	die $@;
  }
  say 'done';
  $results[5] = {summary=>$txt,url=>"/docs/pdf/$dgst/result.pdf"};
  $job->finish(\@results);
  schedule_maintenance();
}

#############################
use Data::Dumper;
my $mainenance_task;
sub schedule_maintenance
{

	my $jobs = $minion->jobs({tasks => ['refreshIndexes']});
	
	# while (my $info = $jobs->next) { print Dumper($info); }
	$jobs = $minion->jobs({tasks => ['refreshIndexes']});
	while (my $info = $jobs->next) {
		print STDERR "Here\n";
		$minion->broadcast('retry',[$info->{id}]) if $info->{state} eq "finished";
		print STDERR "restart\n";
		return
	}
        $minion->enqueue(refreshIndexes=> [@_]=>{priority=>0, delay=>5} );
}
sub _refreshIndexes {
	my ($job, @args)=@_;
	print STDERR "refresh\n";
       return $job->finish('Previous job is still active')
	                    unless my $guard = $minion->guard('maintenance', 600);

	my $res=dbmaintenance(@args);
	# Cleanup empty upload dirs
	system("find '$Documentix::config->{local_storage}' -depth -type d -empty -exec rmdir {} \\;");
	$job->finish(\$res);
}

sub schedule_refresh 
{
	$minion->enqueue(refreshDirectories=>[@_]=>{priority=>0});
}
sub _refreshDirectories {
    my ($job,$top) = @_;
    return $job->finish('Previous job is still active')
	    unless my $guard = $minion->guard('load_directories', 7200);
    Documentix::scantree::scantree($top);
    }
1;
