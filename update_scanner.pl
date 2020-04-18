#!/usr/bin/perl
#copyright Thilo Jeremias
use lib ".";
use strict;
use warnings;
#use old smb version;

# $ENV{"LD_LIBRARY_PATH"}="/tmp/samba/private:/freenas-build/_BE/objs/world/usr/local/lib";
# $ENV{"PATH"} =~ s|^|/tmp/samba:|;



use File::Basename;
use Date::Parse;
use Docconf;
use doclib::pdfidx;
use ld_r;
use Ocr;




my $dir="CANON_SC/DOCUMENT/0001";
my $srv="//192.168.0.64/canon_memory";
my $dst=$Docconf::config->{local_storage}."/Scanner";

my @new;
mkdir $dst unless -d $dst;

my $debug = $Docconf::config->{debug};


my @onserver = qx{smbclient -N $srv -D $dir  -c  dir 2>/dev/null };
foreach ( @onserver )
{
    print STDERR  "$_" if /error/i;
    next unless /^\s+(\S+)\s+\S+\s+(\d+)\s+(.*?)\s*$/;
    my $f="$dst/$1";
    my $s= $2;
    my $t = str2time($3);
    my ( $sf, $tf ) ;

    my $o=undef;
    next if -d $f; 
    # Check if same file is already known (size & date & name)
    next if  -f $f
      && (( $sf, $tf ) = ( stat($f) )[ 7, 9 ] )
      && $sf == $s
      && $tf == $t ;

    if ( -f $f ) {
	my $o="$f";
        while ( -f $o ) 
	{ 
		$o =~ s/(\.([0-9]+))?(\.pdf)/my $r=($2||"00"); $r++;  ".$r$3"/e;
	}
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
	Ocr::start_ocrservice();
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
	   my $wdir=$pdfidx->get_store($digest,1);
	   # Link (try hard) file to store location

           my $on = $wdir."/". basename($_);

	   link ($_,$on) or die "Cannot create link to: $on ($!)"
		unless -f $on;


	    my $txt = $pdfidx->index_pdf( $on );
	    my $c = substr( $txt->{"Content"}, 0, 150 );
	    $c =~ s/[\r\n]+/\n     #/g;
	    print "R: $txt->{Docname} : $txt->{Mime} : $c ...\n";
	}
	print "Update caches\n";
	my $ld_r    = ld_r->new();
	$ld_r->update_caches();
	print "Finished processing\n";
	Ocr::stop_ocrservice();
}
wait;

