package MyApp;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config');

  # Configure the application
  $self->secrets($config->{secrets});

  # Job queue (requires a background worker process)
  #
  #   $ script/linkcheck minion worker
  #
  $self->plugin(Minion => {SQLite => $config->{cache_db}});
  $self->plugin('Minion::Admin');
  $self->plugin('MyApp::Task::Processor');


  # Router
  my $r = $self->routes;
  $self->max_request_size(100*2**20);

  # Normal route to controller
  $r->get('/')->to('example#welcome');
  $r->get('/docs/:type/:hash/#doc')->to('docs#senddoc');
  $r->post('/upload')->to('docs#upload');
  $r->get('/ldres')->to('docs#search');
 

}

1;
