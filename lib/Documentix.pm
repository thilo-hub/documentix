package Documentix;
use Mojo::Base 'Mojolicious';
use Minion::Command::minion::worker;


$Documentix::config=undef;

# This method will run once at server start
sub startup {
  my $self = shift;

$self->hook(before_dispatch => sub {
  my $c=shift;
 return unless $c->req->headers->header('X-Forwarded-Host');
 # root-dir on proxy i.e. '/documentix/'
 my $base = $ENV{PROXY_ROOT};
 return unless $base;
 $c->req->url->base->path($base);
});

  # Load configuration from hash returned by config file
  our $config;
  $config = $self->plugin ( Config => {file => $ENV{"PWD"}.'/documentix.conf'});
  our ($icon_zip,$icon_noresult,$icon_lock,$error_pdf);

  $icon_zip = $self->static->file("icon/zip.png");
  $icon_noresult = $self->static->file("icon/zip.png");
  $icon_lock = $self->static->file("icon/Keys-icon.png");
  $error_pdf = $self->static->file("Error.pdf");

  # Configure the application
  $self->secrets($config->{secrets});

  # Job queue (requires a background worker process)
  #
  #   $ script/linkcheck minion worker
  #
  $self->plugin(Minion => {SQLite => $config->{cache_db}});
  $self->plugin('Minion::Admin' =>  {return_to => '/'});
  $self->plugin('Documentix::Task::Processor');

  #my $worker = Minion::Command::minion::worker->new;
  #$worker->run;
  # Not good on fresh db...
  #Documentix::Task::Processor::schedule_maintenance();

  # Router
  my $r = $self->routes;
  $self->max_request_size(900*2**20);

  # Normal route to controller
  $r->get('/')->to(cb => sub {  my $c = shift;  $c->redirect_to($config->{index_html} )   });
  $r->get('/docs/:type/:hash/#doc')->to('docs#senddoc');
  $r->post('/upload')->to('docs#upload');
  $r->get('/ldres')->to('docs#search');
  $r->get('/status/:md5')->to('docs#status');
  $r->get('/reocr')->to('docs#reocr');
  $r->post('/tags')->to('docs#tags');
  $r->get('/refresh')->to('docs#refresh');
  $r->get('/import')->to('docs#importer');
  $r->get('/export/<:tag>.zip')->to('docs#exportfiles');
  $r->get('/lkup')->to('docs#lkup');
  $r->get('/lkup/*DXID')->to('docs#lkup');
  $r->get('/fixsearchdb')->to('docs#fixsearchdb');
  $r->get('/config')->to('docs#config');
 

}

1;
