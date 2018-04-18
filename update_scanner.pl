#!/usr/bin/perl
#copyright Thilo Jeremias
use strict;
use warnings;


use Date::Parse;
use Docconf;
use doclib::pdfidx;
use ld_r;



my $dir="CANON_SC/DOCUMENT/0001";
my $srv="//serenity/canon_memory";
my $dst=$Docconf::config->{local_storage}."/Scanner";

my @new;
mkdir $dst unless -d $dst;

my $debug = $Docconf::config->{debug};


my @onserver = qx{smbclient -N $srv -D $dir  -c  dir 2>/dev/null };
foreach ( @onserver )
{
    next unless /^\s+(\S+)\s+\S+\s+(\d+)\s+(.*?)\s*$/;
    my $f="$dst/$1";
    my $s= $2;
    my $t = str2time($3);
    my ( $sf, $tf ) ;

    my $o=undef;
    next if -d $f;
    next if  -f $f
      && (( $sf, $tf ) = ( stat($f) )[ 7, 9 ] )
      && $sf == $s
      && $tf == $t ;

    if ( -f $f ) {
	my $idx="01";
 	$idx++ while ( -f "$f.$idx" ) ;
    	$o="$f.$idx";
	rename $f,$o;
    }
    die "File exists: $1" if -f $f;
    #Get
    system("smbget -a 'smb:$srv/$dir/$1' -o '$f'");
    push @new,$f;
    if ($o && !qx{/usr/bin/cmp '$f' '$o'} )
    {
	unlink($o);
	pop @new;
    }
    utime($t,$t,$f);
    print "Downloaded -> $f\n";
}

if (@new) {
	my $pdfidx = pdfidx->new();
	sub lock   { }
	sub unlock { }
	foreach(@new)
	{
           open (my $fh, '<', $_) or die "Can't open '$_': $!";
           binmode ($fh);

           my $ctx = Digest::MD5->new();
           $ctx->addfile($fh);
           close($fh);
           my $digest = $ctx->hexdigest;
	   my $wdir=get_store($digest,true);


	    my $txt = $pdfidx->index_pdf( $_, $wdir );
	    my $c = substr( $txt->{"Content"}, 0, 150 );
	    $c =~ s/[\r\n]+/\n     #/g;
	    print "R: $txt->{Docname} : $txt->{Mime} : $c ...\n";
	}
	print "Update caches\n";
	my $ld_r    = ld_r->new();
	$ld_r->update_caches();
	print "Finished processing\n";
}
    sub get_store {
	my $digest=shift;
	my $md = shift || false;
	my $wdir = $Docconf::config->{local_storage};
	mkdir $wdir or die "No dir: $wdir" unless $md && -d $wdir;
	$digest =~ m/^(..)/;
	$wdir .= "/$1";
	mkdir $wdir or die "No dir: $wdir" unless $md && -d $wdir;
	
	$wdir .= "/$digest";
	mkdir $wdir or die "No dir: $wdir" unless $md && -d $wdir;
	return $wdir;
    }

