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
  $minion->add_task(importer => \&_importer);
  $minion->add_task(merger => \&_merger);
  $minion->add_task(dbmaintenance => \&_dbmaintenance);
  #schedule_maintenance();
}

#############################
sub  schedule_ocr
{
        $minion->enqueue(ocr=> [@_]=>{priority=>1} );
	return "Ocr...";
}

sub _ocr {
  my ($job, @args)=@_;
  return $job->retry({delay => 30})
	unless my $guard = $minion->guard('ocring',60, {limit => 3});
  my $pdfidx  = pdfidx->new(0,$Documentix::config);
  $job->on( finish => &schedule_maintenance );
  my $r = $pdfidx->ocrpdf_sync(@args);
  $minion->enqueue('merger');
  $job->finish( $r);
}

#############################
sub _importer {
  my ($job) = @_;
  use Documentix::Importer;
  my $imports =Documentix::Importer::update();
  $job->finish( $imports);
}

sub schedule_loader
{
	my $id = $minion->enqueue(loader=>[@_]=>{priority=>2});
        $minion->result_p($id);
	return "Reading...";
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
my $mainenance_task;
sub schedule_maintenance
{

	my $jobs = $minion->jobs({tasks => ['refreshIndexes']});
	
	$jobs = $minion->jobs({tasks => ['refreshIndexes']});
	while (my $info = $jobs->next) {
		$minion->broadcast('retry',[$info->{id}]) if $info->{state} eq "finished";
		return
	}
        $minion->enqueue(refreshIndexes=> [@_]=>{priority=>0, delay=>5} );
}
sub _refreshIndexes {
	my ($job, @args)=@_;
	print STDERR "refresh\n";
       return $job->finish('Previous job is still active')
	                    unless my $guard = $minion->guard('maintenance', 600);

	print STDERR "Starting\n";
    $DB::single=1;

	dbaccess::new();
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
	    unless my $guard = $minion->guard('load_directories', 72);
    Documentix::scantree::scantree($top);
    }

sub _merger {
  my ($job) = @_;
  my @results=@_;
  use Documentix::Merger;
  my $res=Documentix::Merger::merge();
  $job->finish($res);
}

#############################
sub schedule_dbfix
{
	$minion->enqueue('dbmaintenance');
	return "Fixing db..."
}
sub _dbmaintenance 
{
  my ($job) = @_;
	my $dba=dbaccess::new();
	my $res= dbaccess::dbmaintenance1($dba);
        $job->finish($res);
}

1;
