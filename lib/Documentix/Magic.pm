package Documentix::Magic;
use Exporter 'import'; 
our @EXPORT = qw{magic};

use File::LibMagic;
my $magic_h  = File::LibMagic->new;

sub magic
{
  my $f=shift;
  my $info = $magic_h->info_from_filename($f);
  return $info->{mime_type};
}
 


