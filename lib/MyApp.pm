package MyApp;
use Mojo::Base 'Mojolicious';
use Minion::Command::minion::worker;

$MyApp::config=undef;

# This method will run once at server start
sub startup {
  my $self = shift;

$self->hook(before_dispatch => sub {
  my $c=shift;
  $c->req->url->base->path('/documentix/') if
   $c->req->headers->header('X-Forwarded-Host');
});

  # Load configuration from hash returned by config file
  our $config;
  $config = $self->plugin ( Config => {file => $ENV{"PWD"}.'/my_app.conf'});

  # Configure the application
  $self->secrets($config->{secrets});

  # Job queue (requires a background worker process)
  #
  #   $ script/linkcheck minion worker
  #
  $self->plugin(Minion => {SQLite => $config->{cache_db}});
  $self->plugin('Minion::Admin'); #  => {route => $self->routes->any('/testing')});
  $self->plugin('MyApp::Task::Processor');

  #my $worker = Minion::Command::minion::worker->new;
  #$worker->run;

  # Router
  my $r = $self->routes;
  $self->max_request_size(300*2**20);

  # Normal route to controller
  $r->get('/')->to(cb => sub {  my $c = shift;  $c->reply->static('index.html')   });
  $r->get('/docs/:type/:hash/#doc')->to('docs#senddoc');
  $r->post('/upload')->to('docs#upload');
  $r->get('/ldres')->to('docs#search');
  $r->get('/reocr')->to('docs#reocr');
 

}

1;
