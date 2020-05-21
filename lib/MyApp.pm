package MyApp;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config');

  # Configure the application
  $self->secrets($config->{secrets});

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
  $r->get('/docs/:type/:hash/#doc')->to('docs#senddoc');
  $r->post('/upload')->to('docs#upload');
  $r->get('/ldres')->to('docs#search');
 

}

1;
