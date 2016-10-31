#!/usr/bin/perl

use strict;
use warnings;
$ENV{"DISABLE_AUTH"} = 1;

use CGI qw/ :standard /;
use Data::Dumper;
use HTTP::Daemon;
use HTTP::Response;
use HTTP::Status;
use POSIX qw/ WNOHANG /;
use constant HOSTNAME => qx{hostname};

my %O = (

    # 'listen-host' => '192.168.0.11',
    'listen-host'              => '127.0.0.1',
    'listen-port'              => 8080,
    'listen-clients'           => 30,
    'listen-max-req-per-child' => 100,
);

my $d = HTTP::Daemon->new(
    LocalAddr => $O{'listen-host'},
    LocalPort => $O{'listen-port'},
    Reuse     => 1,
) or die "Can't start http listener at $O{'listen-host'}:$O{'listen-port'}";

print "Started HTTP listener at " . $d->url . "\n";

system("open http://$O{'listen-host'}:$O{'listen-port'}/");
my %chld;

if ( $O{'listen-clients'} ) {
    $SIG{CHLD} = sub {

        # checkout finished children
        while ( ( my $kid = waitpid( -1, WNOHANG ) ) > 0 ) {
            delete $chld{$kid};
        }
    };
}

my @pages = get_pg();
while (1) {
    if ( $O{'listen-clients'} ) {

        # prefork all at once
        for ( scalar( keys %chld ) .. $O{'listen-clients'} - 1 ) {
            my $pid = fork;

            if ( !defined $pid ) {    # error
                die "Can't fork for http child $_: $!";
            }
            if ($pid) {               # parent
                $chld{$pid} = 1;
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
    my $d = shift;

    use ld_r;
    use feed;

    my $i;
    my $css = <<CSS;
        form { display: inline; }
CSS

    while ( ++$i < $O{'listen-max-req-per-child'} ) {
        my $c = $d->accept        or last;
        my $r = $c->get_request() or last;
        $c->autoflush(1);

        # ($port, $myaddr) = sockaddr_in($mysockaddr);
        # printf "Connect to %s [%s]\n",
        # scalar gethostbyaddr($myaddr, AF_INET),
        # inet_ntoa($myaddr);
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
            $arg->{$k} = $v;
        }
        if ( $r->uri->as_iri =~ /\?(.*)/ ) {
            foreach ( split( /&/, $1 ) ) {
                my ( $k, $v ) = split( /=/, $_, 2 );
                $arg->{$k} = $v;
            }
        }
        my $ro;
        $ro->{"request"} = $r;
        $ro->{"args"}    = $arg;
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
                'Content-Type' => $options->{content_type} . " charset=utf-8",
                'charset'      => 'utf-8',
                'Cache-Control' =>
'no-store, no-cache, must-revalidate, post-check=0, pre-check=0',
                'Pragma'  => 'no-cache',
                'Expires' => 'Thu, 01 Dec 1994 16:00:00 GMT',
            ],
            join( "\n", @_ ),
        )
    );
}

sub get_pg {
    return (
        {
            p  => '/p0',
            cb => sub { return "HiHo" }
        },
        {
            p  => '/',
            cb => sub {
                my $c = shift;
                $c->{"c"}->send_file_response("index.html");
                return undef;
            }
        },
        {
            p  => '/docs(/.*)',
            cb => sub {
                my $c = shift;
                print "feed.cgi $1\n";

                # my $r0=qx{perl feed.cgi "$1"};
                #my $r=HTTP::Message->parse( $r0 );
                my $r = HTTP::Message->new( feed_m( undef, undef, $1 ) );
                print "L:" . length( $r->content ) . "\n";
                my $rp =
                  HTTP::Response->new( RC_OK, undef, $r->headers, $r->content );
                $c->{"c"}->send_response($rp);
                return undef;
            }
        },
        {
            p  => '/ldres.cgi',
            cb => sub {
                my $c = shift;
                my $r = shift;
                my $a = $c->{"args"};

                # print Dumper($c); # ->get_request(1));
                return ldres(
                    $a->{"class"},  $a->{"idx"},
                    $a->{"ppages"}, $a->{"search"}
                );
                return qx(perl ldres.cgi);
                return undef;
            }
        },
        {
            p  => '/(.*)',
            cb => sub {
                my $c = shift;
                return "Failed" unless ( -f $1 );
                $c->{"c"}->send_file_response($1);
                return undef;
            }
        }

    );
}
