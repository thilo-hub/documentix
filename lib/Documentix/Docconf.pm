package Docconf;

use Mojolicious::Plugin::Config;
$Docconf::config = Mojolicious::Plugin::Config->load ( $ENV{"PWD"}.'/documentix.conf');

sub getset {
 die "Not anymore supported";
}
#get_config();
die "No config ??"
	unless $Docconf::config;

sub get_config {
 die "Not anymore supported";
}

1;
