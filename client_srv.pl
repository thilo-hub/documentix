#!/usr/bin/perl
#copyright Thilo Jeremias

use strict;
use warnings;

use Docconf;
my $auth={"update"=>0};;

use CGI qw/ :standard /;
use URI::Escape;
use Data::Dumper;
use HTTP::Daemon;
use Date::Parse;
use HTTP::Cookies;

# Disabled for the time being  seems hard to compile
#use HTTP::Daemon::SSL;
use HTTP::Response;
use HTTP::Status;
use JSON::PP;
use POSIX qw/ WNOHANG /;
use ld_r;
use feed;
use tags;
use dirlist;
use Fcntl qw(:flock SEEK_END);
use doclib::pdfidx;
use Digest::MD5;
my $session="/tmp/doc.sessions";
my $session_time=24*3600; # seconds valid
my $login_timeout=60; # seconds valid
my $nthreads = $Docconf::config->{number_server_threads};
my $doc_re="html|css|js|png|jpeg|jpg|gif";
my $cgi_re="sh|pm|pl|cgi";
my $pwfile=".htpasswd";

my $ids= {
	"Thilo" => "XXX"
};

use constant HOSTNAME => qx{hostname};

$main::debug = $Docconf::config->{debug};
my $last_check = 0;

open( my $fhx, ">", $Docconf::config->{lockfile} ) || die "No Open";

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
$O{'listen-clients'} = $ENV{"THREADS"} || $nthreads
  unless $ENV{"NOTHREADS"};

my $d = HTTP::Daemon->new(

    # my $d = HTTP::Daemon::SSL->new(
    LocalAddr     => $O{'listen-host'},
    LocalPort     => $O{'listen-port'},
    SSL_cert_file => 'server-cert.pem',
    SSL_key_file  => 'server-key.pem',

    Reuse => 1,
) or die "Can't start http listener at $O{'listen-host'}:$O{'listen-port'}";

print "Started HTTP listener at " . $d->url . "\n";

if ( $Docconf::config->{browser_start} ) {
    system("firefox http://$O{'listen-host'}:$O{'listen-port'}/ &")
      if ( $^O =~ /linux/ && $ENV{"DISPLAY"} );
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
$SIG{WINCH} = sub {
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

{
    my $ld_r;
    my $feed;
    my $tags;
    my $dirlist;
    my $pdfidx;
sub http_child {
    my $d       = shift;
    $ld_r    = ld_r->new();
    $feed    = feed->new();
    $tags    = tags->new();
    $dirlist = dirlist->new();
    $pdfidx  = pdfidx->new();
    my @pages   = (
        { p => '/upload(/.*)?',              cb => \&do_upload },
        { p => '/docs/([^/]+)/([^/]+)/(.*)', cb => \&do_feed },
        { p => '/ldres',                     cb => \&do_ldres },
        { p => '/tags',                      cb => \&do_tags, },
        { p => '/config',                    cb => \&do_conf, },
        { p => '/auth.*',                    cb => \&do_auth, },
        { p => '/dir',                       cb => \&do_fbrowser, },
        { p => '/import(/.*)?',              cb => \&do_import, },
        { p => '/importtree(.*)?',           cb => \&do_importtree },
        { p => '/',                          cb => \&do_index },
        { p => '/([^\?]+)',                  cb => \&do_anycgi },
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
	my $uid=guid(16);
	my $cookie  = ($r->header("cookie") or "WE=$uid");
	$ro->{"ID"}      = $1 if ( $cookie =~ m|WE=([0-9A-Za-z+/]+)| );
        $ro->{"request"} = $r;
        $ro->{"cookie"} = $cookie;
        $ro->{"args"}    = $arg;
        $ro->{"q"}       = $r->uri->as_iri . "&" . $r->content;
        foreach my $g (@pages) {
            if ( $r->uri->path =~ /^$g->{p}$/ ) {
                $ENV{'PATH_INFO'} = $1;
                $ro->{"g"}        = $g;
                $ro->{"c"}        = $c;
		my $ct=$r->header('content-type');
		if ($ct && $ct =~ m|multipart/form-data|) {
			my @p=$r->parts;
			die "Can only handle single multi parts"
				if ( scalar(@p) > 1);
			$ro->{"part"}=$p[0];
		}

		# Only do auth unless session is known
		my $srvr = auth_check($ro->{"ID"}) ? $g : { cb => \&do_auth };

                my $rv = $srvr->{"cb"}($ro);
                _http_response( $c,
                    { content_type => 'text/html', charset => 'utf-8', cookie => $cookie , ID=>$ro->{"ID"} }, $rv)
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
        my $co = $options->{cookie};
	$co .= ";Expires=".HTTP::Date::time2isoz(auth_check($options->{"ID"})+ $login_timeout)."\n";
	my $res =
            HTTP::Response->new(
                RC_OK, undef,
                [
                    'Content-Type' => $options->{content_type},
                    'charset' => 'utf-8',
                    'Cache-Control' => 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0',
                    'Pragma'  => 'no-cache',
                    'Expires' => 'Thu, 01 Dec 1994 16:00:00 GMT',
                    'Access-Control-Allow-Origin' => "*",

                ],
                join( "\n", @_ ),
            );
	$res->header( "Set-Cookie" => $co )
		if $co;
	# $co->add_cookie_header($res) if (0 && $co);
        $c->send_response($res);
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

        lock();
        my $m = $tags->add_tag( $c->{"args"} );
        unlock();

        return $m;
    }

    sub do_anycgi {
        my $c = shift;
        my $f = "." . $c->{request}->uri->path;

        # TODO:  make files more secure
        # Restrict files to certain paths
        # Make file an absolute path,
        # return readable files from eq www
        # executables only from eq cgi

        if ( $f =~ /\.($doc_re)$/ && -r $f )
        {    # Standard files that can be returned
            $c->{"c"}->send_file_response($f);
	    print STDERR " + ";
        }
        elsif ( $f =~ /\.($cgi_re)$/ && -x $f ) {
            if ( $Docconf::config->{"cgi_enabled"} ) {

                #print  Dumper($c);
                my $json = JSON::PP->new->utf8;
                my $rv = $json->encode( { "args" => $c->{"args"} } );
                $ENV{"ARGS"} = $rv;
	       print STDERR " + ";
                return HTTP::Message->parse(scalar(qx{$f}))->content();
            }
            return "Failed: cgi scripts are disabled";
        }
        print STDERR " - ";
        return "Failed $f";
    }

    sub do_ldres {
        my $c = shift;
        my $r = shift;
        my $a = $c->{"args"};

        # lock();
        my $m =
          $ld_r->ldres( $a->{"class"}, $a->{"idx"}, $a->{"ppages"},
            $a->{"search"} );
        # unlock();
        return $m;
    }

    sub do_feed {
        my $c = shift;
        print "feed $1\n" if $Docconf::config->{debug} > 0;

        # lock();
        my $r = HTTP::Message->new( $feed->feed_m( $2, $1, $3 ) );
        # unlock();
        my $rp = HTTP::Response->new( RC_OK, undef, $r->headers, $r->content );
        $c->{"c"}->send_response($rp);
        return undef;
    }

    sub do_index {
        my $c = shift;
        $c->{"c"}->send_file_response( $Docconf::config->{"index_html"} );
        return undef;
    }
    sub do_auth {
        my $c = shift;
	my $resp = "auth.html";
	my $a=$c->{"args"};

	return ($c->{"c"}->send_redirect("auth",RC_TEMPORARY_REDIRECT), undef)
		unless $c->{"g"}->{"p"} =~ m|/auth|;

	if ( $a && (my $u=$a->{"user"}) && (my $p=$a->{"pass"}) ) {
		print "User: $u\nPass: $p\n";
		if ( auth_check($c->{ID},$u,$p) ) {
			return $c->{"g"}->{"cb"}($c)
				unless ( $c->{"g"}->{"cb"} == \&do_auth);
			$c->{"c"}->send_redirect("");
			return undef;
		}
	}
	{
		local $/;
		open(my $f,"<",$resp);
		my $r=<$f>;
		close($f);
		return $r;
	}
        $c->{"c"}->send_file_response( $resp);
        return undef;
     }


    sub load_file {
	my ($rv,$f)=@_;
	print STDERR " Read: $f\n" if $Docconf::config->{"debug"} >0;
	if ( $f && -f $f && open (my $fh,"<",$f) ){
		my $ctx = Digest::MD5->new();
		$ctx->addfile($fh);
		close($fh);
		my $digest = $ctx->hexdigest;
		$$rv->{"md5"}= $digest;
		print STDERR "OK\n" if $Docconf::config->{"debug"} >0;
		my $nfh = $pdfidx->get_file($digest);
		unless ($nfh) {
			my $wdir=get_store($digest);

			my ($otxt,$txt);
			eval { ($otxt,$txt) = $pdfidx->index_pdf( $f, $wdir )};
			$ld_r->update_caches();
			rmdir $wdir;  # if is is not empty the rmdir will fail - which is intended
		}
		# lock();
		$$rv = $ld_r->get_rbox_item($digest);
		# unlock();
		$$rv-> {"status"} = "OK";
	}
	print STDERR Dumper($rv) if $Docconf::config->{"debug"} >2;
	return $rv;
    }

    sub do_import {
        my $c = shift;
        my $r = $c->{request};
	my $rv={status => "Failed"};
	my $f=$Docconf::config->{"root_dir"}.$c->{"args"}->{"file"};
	load_file(\$rv,$f);
	my $json = JSON::PP->new->utf8;
	$rv = $json->encode( $rv );
	return $rv;
    }
    sub do_importtree {
        my $c = shift;
	my $otxt;
	my $txt;

	my $f=$Docconf::config->{"root_dir"}.$c->{"args"}->{"dir"};
	$f =~ s|/\.|/|g;
	print STDERR Dumper($c->{"args"});
	return "Empty directory" unless $c->{"args"}->{"dir"};

# die ">>> $f" .Dumper($c);
	return "Failed" unless -d $f;
	open(FD,"find $f -name '*.pdf'|");
	my $i=0;

	my $out = slurp("data");

	my $rn=HTTP::Response -> new ( RC_OK,
		{ content_type => 'text/html', charset => 'utf-8'},undef,
		    sub {
			    # get next file to process
			    my $f = <FD>;
			    $i++;
			    print STDERR "File: $i : " . ( $f ? $f : "END\n");
			    #sleep 10;
			    return undef unless $f;

			    chomp($f);
			    my $m= "-- Bad: $f --";
			    my $rv={ status => "Error" };
			    load_file( \$rv,$f);
			    my $json = JSON::PP->new->utf8;
			    $rv = $json->encode( $rv );
			    $rv =~ s/\|/-/g;

			    return $rv."|";
		    });

	$c->{c}->send_response($rn);
	return undef;


    };

    sub get_store {
	my $digest=shift;
	my $wdir = $Docconf::config->{local_storage};
	mkdir $wdir or die "No dir: $wdir" unless -d $wdir;
	$wdir .= "/$digest";
	mkdir $wdir or die "No dir: $wdir" unless -d $wdir;
	return $wdir;
    }
    sub slurp {
        local $/;
        open( my $fh, "<" . shift )
          or return "File ?";
        return <$fh>;
    };

    sub do_upload {
        my $c = shift;
        my $r = $c->{request};
	my $content = $c->{part} ? \$c->{part}->content : \$r->content;

        my $ctx = Digest::MD5->new();
        $ctx->add( $$content );
        my $digest = $ctx->hexdigest;
        my $n      = $r->header("x-file-name") || "Unknown";
        $n = uri_unescape($n);
        $n =~ s/[^a-zA-Z0-9. _\-]/_/g;


        my $nfh = $pdfidx->get_file($digest);
        if ($nfh) {
            print STDERR "File known\n";
            if ( -r $nfh ) {
                print STDERR "File available ($nfh)\n";
                #return '{"msg":"duplicate"}';
            }
        }
	else
	{
		my $wdir = get_store($digest);
		# Now store the file
		my $fn = "$wdir/$n";

		open( my $f, ">", $fn ) or die "No open $fn";
		print $f $$content;
		close($f);
		if ( my $file_time=$r->header("x-file-date") ) {
			# If the client sent the time, use it
			$file_time = str2time($file_time);
			# print STDERR "Time: ".localtime($file_time)."\n";

			utime ($file_time,$file_time,$f);
		}

		print "File: $n\n";
		my $txt = $pdfidx->index_pdf( $fn, $wdir );
		$ld_r->update_caches();
	}

        # lock();
        my $m = $ld_r->get_rbox_item($digest);
        # unlock();
	my $out = JSON::PP->new->pretty->encode($m);
	return $out;
    }

    sub do_fbrowser {
        my $c = shift;
        my $r = shift;
        my $a = $c->{"args"};

        my $m = $dirlist->list( $c->{"args"} );
        return $m;
    }
    sub guid {
      my $l=shift;
      my $o="";
      for my $i ( 0 ... $l  )
      {
	    $o.=chr(rand(64)+48)
      }
      $o =~  tr#:-@[-`#p-z+/#;
      return $o;
    }
}
}

# Check if ID is known
sub auth_check {
	my ($ID,$u,$p)=@_;
	return 1 if $Docconf::config->{auth_disable};
	if ( defined($u) && defined($p) ) {
		$u =~ s/[^a-zA-Z0-9_@.]//g;
		open(my $ph,"|-",qw{htpasswd -i -v},$pwfile,$u); print $ph "$p\n"; close($ph);
		unless ( $? ) {
			my $s= $auth->{$ID}=time()+ $session_time;
			$auth->{"update"}=time();
			#lock();
			open(FH,">/tmp/doc.sessions");
			print FH Dumper($auth);
			close(FH);
			#unlock();
			print STDERR "Updated session data\n";
			return $s;
		}
	}
	if ( my $s=$auth->{$ID} ) {
		return $s if $s > time();
		delete $auth->{$ID};
		return 0 unless ( $last_check < time() );
	}
	print STDERR "Check session\n";
	$last_check = time();
	my $mt=(stat("/tmp/doc.sessions"))[9] ||0;
	if ( $mt > $auth->{"update"} ) {
		print STDERR "Update session data\n";
		my $VAR1;
		#lock();
		$auth= do $session;
		#unlock();
		$auth->{"update"}=time();
		print STDERR Dumper($auth);
	}
	return $auth->{$ID} || 0;
}
