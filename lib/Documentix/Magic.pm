package Documentix::Magic;
use Exporter 'import'; 
our @EXPORT = qw{magic magic_data};

use File::LibMagic;
my $magic_h  = File::LibMagic->new;

sub magic_data
{
  my $f=shift;
  my $info = $magic_h->info_from_string($f);
  return $info->{mime_type};
}
 


sub magic
{
  my $f=shift;
  my $info = $magic_h->info_from_filename($f);
  return $info->{mime_type};
}
 


