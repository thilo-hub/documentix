package Docconf;
use JSON;
use Encode;
use Data::Dumper;
use URI::Escape;


# Comments are OK
# Valid perl-code
# These are defaults
# The actual config might come from Docconfjs
# and will overwrite the defaults
#
my $config_file = $ENV{"DOCUMENTIX_CONF"} ||  "Docconf.js";
$Docconf::config = $Documentix::config;

sub getset {
    my $args         = shift;
    my $conf_changed = 0;
    #die "Upsi here" .Dumper(\@_);
    my $json_text = $args->{"set"};

    print STDERR "getset... " . Dumper($args)
      if $Docconf::config->{"debug"} > 0;
    my $json = JSON->new->utf8;
    if ($json_text) {

        $json_text = uri_unescape($json_text);

        my $perl_scalar = $json->decode($json_text);
        foreach ( keys %$config ) {
            next unless defined( my $v = $perl_scalar->{$_} );

            $conf_changed++ if $config->{$_} ne $v;
            $config->{$_} = $v;
        }
    }
    if ( $conf_changed && $args->{"save"} ) {
        open( my $fh, ">", $config_file );
        print $fh $json->pretty->encode($config);
        close($fh);
        local $SIG{"WINCH"} = "IGNORE";
        print STDERR "Try restarting ... -$$\n";
        kill "WINCH", -getpgrp($$);

        # snazzy writing of: kill("HUP", -$$)
    }
    $json = $json->canonical(1);
    my $rv = $json->encode($config);
    return $rv;
}
get_config();

sub get_config {
    if ( -r $config_file ) {
        open( my $fh, $config_file );
        local $/;
        my $js;
        $js->{"set"} = <$fh>;
        close($fh);

        # getset will set it again
        $Docconf::config->{"debug"} =0;
        getset($js);
    }
}

1;
