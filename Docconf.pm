package Docconf;

# Comments are OK
# Valid perl-code
# These are defaults
# The actual config might come from Docconfjs
# and will overwrite the defaults
#
$config = {
	database_provider => "SQLite",
	database          => "db/doc_db.db",
	database_user     => "",
	database_pass     => "",
	cache_db_provider => "SQLite",
	cache_db          => "/tmp/doc_cache.db",
	cache_db_user     => "",
	cache_db_pass     => "",
	lockfile          => "db/db.lock",
	debug             => 0,
	results_per_page  => 10,
	number_server_threads => 16,
        number_ocr_threads => 16,
	browser_start      => 1,
	local_storage       => "incomming",
	link_local         => 0,  # symlink files into local_storage

	server_listen_if => "127.0.0.1:8080",
};

use JSON::PP;
use Encode;
use Data::Dumper;
use URI::Escape;
sub getset {
  my $args=shift;
  #die "Upsi here" .Dumper(\@_);
  my $json_text  = $args->{"set"};;

  my $json        = JSON::PP->new->utf8;
  if ( $json_text) {


    $json_text = uri_unescape($json_text);

 print STDERR Dumper($json_text);
    my $perl_scalar = $json->decode($json_text);
  foreach (keys %$config) {
        next unless my $v=$perl_scalar->{$_};

	$config->{$_} = $v;
  }
  }
  if ( $args->{"save"} ) {
	open(my $fh,">Docconf.js");
	print $fh $json->pretty->encode( $config );
	close( $fh);
  }
  my $rv= $json->encode($config);
  return $rv;
}
if ( -r "Docconf.js" ) {
   open(my $fh,"<Docconf.js");
   local $/;
   my $js;
   $js->{"set"}=<$fh>;
   close($fh);
   getset($js);
}

1;
