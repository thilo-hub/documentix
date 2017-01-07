#!/usr/bin/perl
#copyright Thilo Jeremias

use strict;
use warnings;

use Docconf;

use CGI qw/ :standard /;
use URI::Escape;
use Data::Dumper;
use HTTP::Daemon;
# -- not easy to install.... 
# Disabled for the time being use HTTP::Daemon::SSL;
use HTTP::Response;
use HTTP::Status;
use POSIX qw/ WNOHANG /;
use ld_r;
use feed;
use tags;
use Fcntl qw(:flock SEEK_END);
use doclib::pdfidx;
my $nthreads=$Docconf::config->{number_server_threads};

use constant HOSTNAME => qx{hostname};

$main::debug = $Docconf::config->{debug};

open( my $fhx, ">",$Docconf::config->{lockfile} ) || die "No Open";

sub lock {
    flock( $fhx, LOCK_EX ) or die "Cannot lock mailbox - $!\n";
}

sub unlock {
    flock( $fhx, LOCK_UN ) or die "Cannot unlock mailbox - $!\n";
}

my ( $i, $p ) = split( /:/, $ARGV[0] || $Docconf::config->{server_listen_if} );

my %O = (

    'listen-host' => $i,

    # 'listen-host'              => '127.0.0.1',
    'listen-port' => $p,


    'listen-max-req-per-child' => 100,
);
     $O{'listen-clients'}=  $ENV{"THREADS"} || $nthreads
	unless $ENV{"NOTHREADS"};

my $d = HTTP::Daemon->new(
# my $d = HTTP::Daemon::SSL->new(
    LocalAddr => $O{'listen-host'},
    LocalPort => $O{'listen-port'},
    SSL_cert_file => 'server-cert.pem',
    SSL_key_file => 'server-key.pem',

    Reuse     => 1,
) or die "Can't start http listener at $O{'listen-host'}:$O{'listen-port'}";

print "Started HTTP listener at " . $d->url . "\n";

if ( $Docconf::config->{browser_start} ) {
	system("firefox http://$O{'listen-host'}:$O{'listen-port'}/ &")
	  if ( $^O =~ /linux/ && $ENV{"DISPLAY"});
	system("open http://$O{'listen-host'}:$O{'listen-port'}/")
	  if ( $^O =~ /darwin/ );
}
my %chld;

if ( $O{'listen-clients'} ) {
    $SIG{CHLD} = sub {

        # checkout finished children
        while ( ( my $kid = waitpid( -1, WNOHANG ) ) > 0 ) {
            delete $chld{$kid};
        }
    };
}
$SIG{WINCH}= sub { 
            print STDERR "Update configuration\n" if $Docconf::config->{debug} > 0;
	    Docconf::get_config();
};

while (1) {
    if ( $O{'listen-clients'} ) {

        # prefork all at once
        for ( scalar( keys %chld ) .. $O{'listen-clients'} - 1 ) {
	    Docconf::get_config();
            my $pid = fork;

            if ( !defined $pid ) {    # error
                die "Can't fork for http child $_: $!";
            }
            if ($pid) {               # parent
                $chld{$pid} = 1;
		print STDERR "Forked server PID:$pid\n";
            }
            else {                    # child
                $_ = 'DEFAULT' for @SIG{qw/ INT TERM CHLD /};
                http_child($d);
                exit;
            }
        }

        sleep 1;
    }
    else {
        http_child($d);
    }

}

sub http_child {
    my $d      = shift;
    my $ld_r   = ld_r->new();
    my $feed   = feed->new();
    my $tags   = tags->new();
    my $pdfidx = pdfidx->new();
    my @pages  = (
        { p => '/upload(/.*)?',          cb => \&do_upload },
        { p => '/docs/([^/]+)/([^/]+)/(.*)', cb => \&do_feed },
        { p => '/ldres',                 cb => \&do_ldres },
        { p => '/tags',                  cb => \&do_tags, },
        { p => '/config',                  cb => \&do_conf, },
        { p => '/',                          cb => \&do_index },
        { p => '/+(.*)',                     cb => \&do_anycgi },
    );

    my $i;
    while ( ++$i < $O{'listen-max-req-per-child'} ) {
        my $c = $d->accept        or last;
        my $r = $c->get_request() or last;
        $c->autoflush(1);

        my $kk = $c->sockname;
        my ( $port, $myaddr ) = sockaddr_in($kk);
        my $host = scalar gethostbyaddr( $myaddr, AF_INET );

        $ENV{"SERVER_ADDR"} = "http://$host:$port";
        print sprintf( "[%s] %s %s\n",
            $c->peerhost, $r->method, $r->uri->as_string );

        my $matches = 0;

        # Get args POST/GET -- I assume all ARGS are SHORT
        my $arg;
        foreach ( split( /&/, $r->content ) ) {
            my ( $k, $v ) = split( /=/, $_, 2 );
            next unless $k;
	    $v = uri_unescape($v);
            $arg->{$k} = $v;
        }
        if ( $r->uri->as_iri =~ /\?(.*)/ ) {
            foreach ( split( /&/, $1 ) ) {
                my ( $k, $v ) = split( /=/, $_, 2 );
		next unless $k;
	        $v = uri_unescape($v);
                $arg->{$k} = $v;
            }
        }
        my $ro;
        $ro->{"request"} = $r;
        $ro->{"args"}    = $arg;
        $ro->{"q"}       = $r->uri->as_iri . "&" . $r->content;
        foreach my $g (@pages) {
            if ( $r->uri->path =~ /^$g->{p}$/ ) {
                $ENV{'PATH_INFO'} = $1;
                $ro->{"g"}        = $g;
                $ro->{"c"}        = $c;
                my $rv = $g->{"cb"}($ro);
                _http_response( $c,
                    { content_type => 'text/html', charset => 'utf-8' }, $rv )
                  if $rv;
                $matches++;
                last;
            }
        }
        $c->send_error(RC_FORBIDDEN)
          unless $matches;

        $c->close();
        undef $c;
    }

    sub _http_error {
        my ( $c, $code, $msg ) = @_;

        $c->send_error( $code, $msg );
    }

    sub _http_response {
        my $c       = shift;
        my $options = shift;

        $c->send_response(
            HTTP::Response->new(
                RC_OK, undef,
                [
                    'Content-Type' => $options->{content_type}
                      . " charset=utf-8",
                    'charset' => 'utf-8',
                    'Cache-Control' =>
'no-store, no-cache, must-revalidate, post-check=0, pre-check=0',
                    'Pragma'  => 'no-cache',
                    'Expires' => 'Thu, 01 Dec 1994 16:00:00 GMT',
                     'Access-Control-Allow-Origin' => "*",
                ],
                join( "\n", @_ ),
            )
        );
    }

    sub do_conf {
        my $c = shift;
        my $r = shift;
        my $a = $c->{"args"};

        my $m = Docconf::getset( $c->{"args"} );

        return $m;
    }


    sub do_tags {
        my $c = shift;
        my $r = shift;
        my $a = $c->{"args"};

        lock();
        my $m = $tags->add_tag( $c->{"args"} );
        unlock();

        return $m;
    }

    sub do_anycgi {
        my $c = shift;

        #print  Dumper($c);
        my $f = "." . $c->{request}->uri->path;
        return HTTP::Message->parse(qx{$f})->content()
          if ( $f =~ /\.cgi$/ && -x $f );
        return "Failed $f" unless ( -f $f );
        $c->{"c"}->send_file_response($f);
        return undef;
    }

    sub do_ldres {
        my $c = shift;
        my $r = shift;
        my $a = $c->{"args"};

        lock();
        my $m =
          $ld_r->ldres( $a->{"class"}, $a->{"idx"}, $a->{"ppages"},
            $a->{"search"} );
        unlock();
        return $m;
    }

    sub do_feed {
        my $c = shift;
        print "feed $1\n" if $main::debug > 0;

        lock();
        my $r = HTTP::Message->new( $feed->feed_m( $2, $1, $3 ) );
        unlock();
        my $rp = HTTP::Response->new( RC_OK, undef, $r->headers, $r->content );
        $c->{"c"}->send_response($rp);
        return undef;
    }

    sub do_index {
        my $c = shift;
        $c->{"c"}->send_file_response("index.html");
        return undef;
    }

    sub do_upload {
        my $c = shift;
        my $r = $c->{request};

        #print Dumper($c);
        use Digest::MD5;
        my $ctx = Digest::MD5->new();
        $ctx->add( $r->content() );
        my $digest = $ctx->hexdigest;
        my $n      = $r->header("x-file-name");
        $n =~ s/[^a-zA-Z0-9._\-]/_/g;

        my $nfh = $pdfidx->get_file($digest);
        if ($nfh) {
            print STDERR "File known\n";
            if ( -r $nfh ) {
                print STDERR "File available ($nfh)\n";
                return "duplicate";
            }
        }

        my $fn = $Docconf::config->{local_storage}; 
        mkdir $fn or die "No dir: $fn" unless -d $fn;
        $fn .= "/$digest";
        my $wdir = $fn;
        mkdir $fn or die "No dir: $fn" unless -d $fn;
        $fn .= "/$n";

        open( my $f, ">", $fn ) or die "No open $fn";
        print $f $r->content();
        close($f);
        print "File: " . $r->header("x-file-name") . "\n";
        my $txt = $pdfidx->index_pdf( $fn, $wdir );
        $ld_r->update_caches();

        lock();
        my $m =
          $ld_r->get_rbox_item($digest);
        unlock();
        return $m;
        return "OK";
    }
}
