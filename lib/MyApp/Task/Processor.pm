package MyApp::Task::Processor;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(loader => \&_loader);
}

sub _loader {
  my ($job, $url) = @_;

  my @results=@_;
  say 'Here';
  sleep 1;
  say 'done';
#  my $ua  = $job->app->ua;
#  my $res = $ua->get($url)->result;
#  push @results, [$url, $res->code];
#
#  for my $link ($res->dom->find('a[href]')->map(attr => 'href')->each) {
#    my $abs = Mojo::URL->new($link)->to_abs(Mojo::URL->new($url));
#    $res = $ua->head($abs)->result;
#    push @results, [$link, $res->code];
#  }
#
  $job->finish(\@results);
}

1;
