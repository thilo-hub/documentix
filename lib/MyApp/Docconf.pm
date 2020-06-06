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
$config = {
    database_provider     => "SQLite",
    database              => "db/doc_db.db",
    database_user         => "",
    database_pass         => "",
    cache_db_provider     => "SQLite",
    cache_db              => "db/doc_cache.db",
    cache_db_user         => "",
    cache_db_pass         => "",
    lockfile              => "db/db.lock",
    debug                 => 0,
    debug_js              => 1,
    results_per_page      => 10,
    number_server_threads => 4,
    number_ocr_threads    => 8,
    browser_start         => 1,
    local_storage         => "uploads",
    link_local            => 0,              # symlink files into local_storage
    ebook_convert_enabled => 1,
    unoconv_enabled       => 1,
    cgi_enabled           => 0,              # Security risk
    index_html            => "index6.html",
    icon_size             => 100,
    root_dir              => "Documents",
    auth_disable          => 1,   #   Not finalized 
    unclassified_folder   => "Unsorted|unclassified", # Regular case insensitive regex for folders ignored at classifications
    xmlrpc_port           => 18081,

    server_listen_if => "127.0.0.1:28080",
};

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
