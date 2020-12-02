package pdfidx;

use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);

use Documentix::db;
use Documentix::Classifier;
use Sys::Hostname;
use File::Temp qw/tempfile tmpnam tempdir/;
use File::Basename;
use Cwd 'abs_path';
use Data::Dumper;
use DBI qw(:sql_types);
use doclib::datelib;
use Encode qw{encode decode};
# $File::Temp::KEEP_ALL = 1;
my $debug=5;

my $tools = "/usr/pkg/bin";
$tools = "/home/thilo/documentix/tools" unless -d $tools;

$tools = "/usr/bin"       unless -d $tools;
$tools = "/usr/local/bin" unless -d $tools;

#$ENV{"PATH"}.= ":tools";

my $temp_dir = "/var/tmp";

# Used tools
my $convert    = "convert";
my $lynx       = "lynx";
my $pdfimages  = "pdfimages";
my $pdfinfo    = "pdfinfo";
my $pdfopt     = "pdfopt";
my $pdftoppm   = "pdftoppm";
my $pdftotext  = "pdftotext";
my $pdftocairo = "pdftocairo";
my $zbarimg    = "zbarimg";

# use threads;
# use threads::shared;

my $cleanup = 0;


sub new {
    my $class  = shift;
    my $chldno = shift;
    my $config = shift;

    my $dh = Documentix::db::dh();

    my $self = bless { dh => $dh, dbname => $d_name, config => $config }, $class;
    $self->set_debug($config->{"debug"});
    $self->{"setup_db"} = \&setup_db;
    $self->{"dh1"}      = $dh;
    trace_db($dh) if  $config->{debug} > 3;
    return $self;
}

# Enable temporal debug:
#
# my $odb=$self->set_debug($debug+3);
# $self->set_debug($odb);
#
sub set_debug {
  my $self=shift;
  my $odebug=$debug;
  $debug = shift @_;
  return $debug;
}

sub dbname {
    my $self = shift;
    return $self->{"dbname"};
}

sub trace_db {
    my $dh = shift;

    sub trace_it {
        my $r = shift;

        print STDERR "DB: $r\n";
    }

    $dh->sqlite_trace( \&trace_it );
}

sub setup_db {
    my $self = shift;
    my $dh   = $self->{"dh"};

    $dh->sqlite_busy_timeout(10000);
    my @slist = (
q{begin exclusive transaction},
q{create table if not exists hash ( idx integer primary key autoincrement, md5 text unique )},
q{create table if not exists data ( idx integer primary key , thumb text, ico text, html text) },
        q{create table if not exists ocr ( idx integer, text text)},
q{create table if not exists metadata ( idx integer, tag text, value text, unique ( idx,tag) )},

      # q{CREATE VIRTUAL TABLE if not exists text USING fts4(tokenize=porter);},
q{CREATE TABLE if not exists mtime ( idx integer primary key, mtime integer)},
        q{CREATE INDEX if not exists mtime_i on mtime(mtime)},

        q{CREATE TRIGGER if not exists del2 before delete on hash begin
					delete from file where file.md5 = old.md5;
					delete from data where data.idx = old.idx;
					delete from metadata where metadata.idx=old.idx;
					delete from text where docid=old.idx;
					delete from mtime where mtime.idx=old.idx;
				 end;},
q{commit}
    );
    foreach (@slist) {

        #print STDERR "DO: $_\n";
        $dh->do($_) or print STDERR "Err: $_";
    }

}

sub tfun {
    my $self = shift;
    my $md5  = shift;
    my $dh   = $self->{"dh"};
    my $meta;

    $meta->{"IDS"} = $dh->selectcol_arrayref(
q{select md5 from metadata natural join hash where tag="mtime" and value > ?},
        undef,
        time() - 4 * 24 * 3600
    );

    $meta->{"list"} = "Hello {Docname}\n";
    my $tpl = slurp("-");

    my %ref;
    my $idx = "0000";
    while ( $tpl =~ s/\{\*([A-Z0-9a-z]+)\}(.*?)\{\*\}/RPT>$2</s ) {
        $ref{"XX_$1"} = $2;
    }

# while( $tpl =~ s/{([A-Z0-9_a-z]*)([^{}]*)}/$n="${idx}_$1"; $ref{$n}=$2;$idx++; "#$n#"/gse ) {}
    $ref{"tpl"} = $tpl;
    return \%ref;

    $meta->{"out"} = expand_templ( $dh, $tpl, \$meta, $md5 );
    return $meta;
}

sub get_file {
    my $self  = shift;
    my $dh    = $self->{"dh"};
    my ($md5) = @_;
    return $md5 unless $md5 =~ m/^[0-9a-f]{32}$/;

    my $q = "select file from file where md5=?";

    # print STDERR "$q : $md5\n";
    # $dh->do("begin exclusive transaction");
    my $fn = $dh->selectcol_arrayref( $q, undef, $md5 );
    # $dh->do("commit");
    foreach (@$fn) {

        # return the first readable
        return $_ if -r $_;
    }
    return $$fn[0];
}

sub get_metas {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ($md5) = @_;
    my $res  = $dh->selectall_hashref(
        "select tag,value from hash natural join metadata where md5=?",
        "tag", undef, $md5 );
    foreach ( keys %$res ) {
	    $res->{$_}=$res->{$_}->{"value"};
    }
    return $res;
}

sub get_meta {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ( $typ, $fn ) = @_;
    # $dh->do("begin exclusive transaction");
    my $idx = $dh->selectrow_array(
        "select value from hash natural join metadata where md5=? and tag = ?",
        undef, $fn, $typ
    );
    # $dh->do("commit");
    return $idx;
}

sub pdf_info($$) {
    my $self = shift;
    my $fn   = shift;
    my $res  = qexec($pdfinfo ,$fn);
    $res =~ s/\0//g;
    $res =~ s|:\s|</td><td>|mg;
    $res =~ s|\n|</td></tr>\n<tr><td>|gs;
    $res =~ s|^(.*)$|<table><tr><td>$1</td></tr></table>|s;
    return $res;
}

sub expand_templ {
    my $dh   = shift;
    my $tpl  = shift;
    my $meta = shift;
    my $md5  = shift;

    sub get_content {
        my $db  = shift;
        my $var = shift;
        my $md5 = shift;
        print STDERR "Expand: $var / $md5\n" if $debug > 1;

        if ( $md5 && !$$db->{$md5} ) {
            print STDERR "Fetch: $md5\n" if $debug > 1;
            my $res = $dh->selectall_hashref(
                q{select idx,tag,value from file
				natural join hash natural join metadata
				    where md5=?}, "tag", undef, $md5
            );
            $$db->{$md5}->{$_} = $res->{$_}->{"value"} foreach ( keys %$res );
            $$db->{$md5}->{"KEYS"} =
              join( ' ', keys( %{ $$db->{$md5} } ) );
        }
        warn "R:$res: M:$md5:" . ref($res);
        my $res = $$db->{$md5};
        if ( ref($res) eq "ARRAY" ) {
            my $out = "";
            my $exp = $$db->{$var};
            warn "$exp";
            foreach (@$res) {
                my $t = $exp;
                $t =~ s/{(.*?)}/{$1_$_}/g;
                $out .= $t;
            }
            $res = $out;
            return $res;
        }
        if ( ref($res) == "HASH" ) {
            $res = $res->{$var};
        }
        return $res unless ref($res);
        die "R:$res:" . ref($res);
        $res = $$db->{$var} unless $res;
        return "{ $var }";
    }
    while ( $tpl =~
        s/{([a-zA-Z0-9]+)(_([a-zA-Z0-9]+))?}/get_content($meta,$1,$3)/ges )
    {
    }
    return $tpl;
}
my %childs;

sub w_load {
    my $l   = shift;
    my $err = 0;
    my $pid;
    $l++ unless $l; # ensure a load==0 is handled ok
    while ( ( my $pn = scalar( keys(%childs) ) ) >= $l ) {
        print STDERR "($pn) ";
	my $pid=wait;
        if ( $pid > 0 && $childs{$pid} ) {
		delete $childs{$pid};
		$err++ if $? != 0;
	}
	if ( $pid < 0 ) {
		print STDERR "Failed .. no more childs\n";
		print STDERR Dumper(\%childs);
		return 0;
	}
    }
    return $err;
}

sub ocrpdf_async {
	my $self=shift;
	my ( $inpdf, $outpdf, $ascii, $md5 ) = @_;
	# Otherwise the directory would be deleted
	open (FH,">$outpdf.wip");
	print FH "WIP\n";
	close(FH);
	return Ocr::push_job($self->{"idx"},@_);
}

sub ocrpdf_sync {
	my $self=shift;
	my ( $inpdf, $outpdf, $ascii, $meta) = @_;
       my ($idx) =
            $self->{dh}->selectrow_array( "select idx from hash where md5=?", undef, $meta->{hash} );
	$self->{"idx"} = $idx;
	print STDERR "ocrpdf_sync: ".Dumper(\@_);
	# Otherwise the directory would be deleted
	open (FH,">$outpdf.wip");
	print FH "WIP\n";
	close(FH);
	my $res = $self->ocrpdf_offline($self->{"idx"},@_);
	return $res;
}

# do OCR of pdf and fix metadata
#
# ARGS:  $self, $idx, $inpdf, $outpdf, $ascii, $md5
# RET:   $text
sub ocrpdf_offline
{
	my $self=shift;
	my $idx = shift;
	my ( $inpdf, $outpdf, $ascii, $meta ) = @_;
	$self->{"idx"}=$idx;
	$DB::single=1;
        my ($pdfinfo,$t) = $self->do_ocrpdf(@_);

	# new pdfinfo only if non existant before
	$self->ins_e( $idx, "pdfinfo", $pdfinfo )
	    if (defined($pdfinfo) &&  !defined($meta->{pdfinfo}));

        if ($t) {
            $t =~ s/[ \t]+/ /g;
            $self->ins_e( $idx, "Text", $t );

            # short version
	    my $c = summary(\$t);
            $self->ins_e( $idx, "Content", $c );
	    $self->{dh}->do(qq{delete from tags where idx=? and tagid=(select tagid from tagname where tagname = 'empty') },undef,$idx);
	    my ($popfile,$class) = ( pdf_class_file( $fn, \$t, $meta->{hash},  join("/",@{$meta->{"_taglist"}})  ) );
        }
	return count_text($t);
}
# Return text sizes
sub count_text {
	my $t = shift;
	$t =~ s/[^\s]+/X/gs;
	my $w = $t;
	$w =~ s/[^X]//g;
	$w = length($w);
	my $p = $t;
	$p =~ s/[^\f]//gs;
	$p = length($p);
	return "Pages: $p Words: $w";
}
# Create summary of text -- can be imporved
sub summary {
    my $t = shift;
    $t =$$t;
    $$t =~ s/^\s*(([^\n]*\n){24}).*/$1/s;
    return  $t;
}
# ARGS:  $inpdf, $outpdf, $ascii, $md5
# RET:   $text
sub do_ocrpdf {
    my $self = shift;
    my ( $inpdf, $outpdf, $ascii, $md5 ) = @_;
    my $pdfinfo= undef;
    my $maxcpu = $self->{config}->{number_ocr_threads};
    my @outpages;
    print STDERR "ocrpdf $inpdf $outpdf\n" if $debug > 1;
    $inpdf  = abs_path($inpdf);
    $outpdf = abs_path($outpdf);

    my $fail = 0;
    my $pg = 1;

    my $tmpdir = File::Temp->newdir("/var/tmp/ocrpdf__XXXXXX");
    $fail += do_pdftocairo( $inpdf, "$tmpdir/page" );
    my @inpages = glob( $tmpdir->dirname . "/page*" );

    print STDERR "Convert ".scalar(@inpages)." pages\n" if $debug > 1;
    my @qr;
    foreach $in (@inpages) {
        my $outim   = $in . ".jpg";

        my $inx=$in.".png";
        qexec("convert",$in,"-resize","800",$inx);
        my $qrc=qexec($zbarimg,"-q", $inx);
	if ( $qrc ) {
		print STDERR "$pg:$qrc" if $debug>0;
		chomp($qrc);
		foreach (split(/\n/,$qrc)) {
			push @qr,"$pg:$_";
		}
        }
        my $outpage = $tmpdir->dirname . "/o-page-" . $pg++;
        if ( $maxcpu<=1 || ( $pid = fork() ) == 0 ) {
            print STDERR "Conv $in\n" if $debug > 1;
            $fail += do_convert_ocr( $in, $outim );
            $fail += do_tesseract( $outim, $outpage );
            unlink( $in, $outim ) unless $debug > 2;
            exit($fail) if $maxcpu>1;
            $errs += $fail;
        }
        $childs{$pid}++;
        $errs += w_load($maxcpu);
        $outpage .= ".pdf";
        push @outpages, $outpage;
    }
    print STDERR "Wait..\n";
    $errs += w_load(0) if $maxcpu>1;
    print STDERR "Done Errs:$errs\n";
print STDERR Dumper(\$self,\@qr) if $debug > 1;
    if (@qr && $self->{"idx"} ) {
	$self->ins_e($self->{"idx"},"QR",join("\n",@qr));
    }

    my $txt = undef;
    if (@outpages) {

	my @cpages;
	foreach (@outpages) {
	    push @cpages, $_ if -f $_;
	}
	if ( @cpages ) {
	    $fail += do_pdfunite( $outpdf, @cpages );
	    my $cmt=$md5;
	    $cmt .= ",SCAN:".join(",SCAN:",@qr) if @qr;
	    #if ( $qr && $qr =~ /(\d+):QR-Code:(Front|Back) Page/ ) {
		# $cmt .= $self->try_merge_pages($2,$1,$outpdf,$md5);
		#$qr =~ s/\n/,/gs;
		#$cmt .= "Q:$qr";
		#}
	    $fail += do_pdfstamp( $outpdf, $cmt,$inpdf );
	    $pdfinfo =  $self->pdf_info($outpdf);
	    $self->ins_e($self->{"idx"},"pdfinfo", $self->pdf_info($outpdf));

	    $txt = do_pdftotext($outpdf);
	}
	unlink(@outpages) unless $debug > 2;
    }
    unlink ("$outpdf.wip");
    $txt .= "\n$qr" if $qr;
    return ($pdfinfo,$txt);
}

# if an other file can be found that contains the other qr code,
# join both files and store the output
# remove db entries to both old files
# create new file with name suffix _combined
#
sub try_merge_pages
{
my ($self,$this_page_code,$this_page_qr,$this_file,$this_file_md5)=@_;
    my $cmt="";

    my $other_page_code = "Front"; $other_page_code =  "Back" if $this_page_code eq $other_page_code;
    my $dh   = $self->{"dh"};
    my $mt = $self->get_metas($this_file_md5);
    my $mtime = $mt->{"mtime"};
    my $npages = $& if ( $mt->{"pdfinfo"} =~ m|^<tr><td>Pages</td><td>.*|m);

print STDERR "Check if merge for $this_page_qr:$this_page_code possible\n" if $debug > 1;
    $sel_qr = q{select b.idx,b.value,md5,file
		      from metadata a join metadata b  using (idx) join metadata c  using (idx)  natural join hash natural join file
		      where a.tag="pdfinfo" and a.value like ?
			     and b.tag = "QR" and b.value like ?
			     and c.tag="mtime" and cast(c.value as int)  between (?-600) and (?+600)
		};
    $sel_qr =$dh->prepare_cached($sel_qr);
    die "DBerror :$? $idx:$t:$c: " . $sel_qr->errstr unless
	$sel_qr->execute("%$npages%","%QR-Code:$other_page_code Page%",$mtime,$mtime);
    my $doc->{"out"}=$this_file;
    $doc->{"out"} =~ s/\.pdf/_combined.pdf/;
    while ( my $r = $sel_qr->fetchrow_hashref() ) {
	    print STDERR "merge is possible\n" if $debug > 1;
	    print STDERR "Merging documents: $r->{md5} + $this_file_md5\n";
	    my $opage=$1 if $r->{"value"} =~ /(\d+):QR-Code:$other_page_code Page/;
	    $r->{"file"} = $self->pdf_filename($r->{"md5"});
	    if ( $this_page_code eq "Back" ) {
		    $doc->{"even"} = $this_file;
		    $doc->{"even_skip"}=$this_page_qr;
		    $doc->{"odd"}  = $r->{"file"};
		    $doc->{"odd_skip"}= $opage;
	    } else {
		    $doc->{"odd"} = $this_file;
		    $doc->{"odd_skip"}=$this_page_qr;
		    $doc->{"even"}  = $r->{"file"};
		    $doc->{"even_skip"}= $opage;
	    }
	    print STDERR ">>($opage):".Dumper($r,$doc) if $debug > 1;
	    $self->join_pdf($doc);
	    unlink($this_file);
	    rename($doc->{"out"},$this_file);
	    print STDERR "remove merged file $r->{md5}\n" if $debug > 2;
	    # Remove from DB the merged other file
	    die "DBerror :$? $r->{md5} " . $dh->errstr unless
		$dh->do(q{delete from hash where md5=?},undef,$r->{"md5"});
	    die "DBerror :$? $r->{md5} $this_file " . $dh->errstr unless
		$dh->do(q{update file set file=? where md5=?},undef,$this_file,$this_file_md5);
	    $cmt .= " Merged($r->{md5})";
    }
return $cmt;
}



sub join_pdf
{
    my $self=shift;
    $doc=shift;
    print STDERR "Join $doc->{odd} $doc->{even} -> $doc->{out}\n" if $debug>0;
    warn "Output $doc->{out} already exists" if -f $doc->{"out"};
    return  if -f $doc->{"out"};

    my $tmp = File::Temp->newdir("/var/tmp/joining__XXXXXX");
    qexec("pdfseparate",  $doc->{"even"},  "$tmp/page-%03d.pdf");

    my @l=sort {$b cmp $a}  glob("$tmp/page*.pdf");  # reverse order
    my $p="001";
    foreach(@l){
	$s=$_;
	s/-\d+/-$p-b/;
	$p++;
	rename( $s,$_);
    }
    qexec("pdfseparate",  $doc->{"odd"}  ,"$tmp/page-%03d-a.pdf");
    my @o=sort {$a cmp $b}  glob("$tmp/page*.pdf");
    print STDERR "Joining ".(scalar(@o)-scalar(@l))." front pages and ".scalar(@l)." back pages to $doc->{out}\n" if $debug > 1;
    my @out;
    splice(@o,($doc->{"odd_skip"}-1)*2,2);
    if (0 ) {
    foreach my $tf (@o) {
	    my $qb=qexec("zbarimg","-q",$tf);
	    push (@out,$tf )unless $qb =~ /QR-Code:(Front|Back) Page/;
	    print "$tf: $qb";
	    # undef $tf;
	    # unshift @out;
    }
    }
    qexec("pdfunite",@out,$doc->{"out"});
    unlink @o or die "failed remove @o";
}


# Read input pdf and join the given html file

# Converter
# "recursive"
# Input: to-type , curren_file_info
#
use Documentix::Magic qw{magic};
{

sub fail_file
{
	my ($self)=shift;
	my ($hint,$meta)=@_;
	my $dh=$self->{dh};
	print STDERR "Failed file: $hint ($meta->{hash})\n";
	my ($idx) =
	$dh->selectrow_array( "select idx from hash where md5=?", undef, $meta->{hash} );
	pdf_class_file(undef,undef,$meta->{hash},"failed");
        $self->ins_e( $idx, "Content", "Failed=$hint" );
	$self->ins_e( $idx, "pdfinfo", "unknown" );
	return ($idx,undef) unless  $idx; #Error
}
# use to check if we will process the file
our $mime_handler = {
	    "application/zip" => \&xtp_unzip,
	    "application/x-gzip" => \&xtp_gzip,
	    "application/x-tar" => \&xtp_tar,
	    "application/gzip" => \&xtp_gzip,
	    "application/pdf"    => \&xtp_pdf,
	    "application/msword" => \&xtp_any,
	    "image/png"         => \&xtp_jpg,
	    "image/jpeg"         => \&xtp_jpg,
	    "image/jpg"         => \&xtp_jpg,
	    "text/plain"	     => \&xtp_ascii,
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
	      => \&xtp_any,
	    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" =>
	      \&xtp_any,
	      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
	      => \&xtp_any,
	    "application/epub+zip"          => \&xtp_ebook,
	    "application/vnd.ms-powerpoint" => \&xtp_any
	};
sub load_file
{
	my ($self)=shift;
	my ($totype,$meta)=@_;
	my $dh=$self->{dh};

	my $fn = $meta->{file} or die "Bad call";
	delete $meta->{file};
	$meta->{_file}=$fn;
	$meta->{hash} = file_md5_hex($fn) unless $meta->{hash};
	# If we dont know the file already, we can just return
	my ($idx) =
	  $dh->selectrow_array( "select idx from hash where md5=?", undef, $meta->{hash} );
	return ($idx,undef) unless  $idx; #Error
	$meta->{"Docname"} = basename($fn);
	$meta->{"Content"} = "ProCcesIng";
	my @fstat=stat($fn);
	$meta->{"size"} = $fstat[7];
	$meta->{"mtime"} = $fstat[9];
	my $type =
	$meta->{"Mime"} = magic($fn);
	print STDERR "Type: $type\n";

	$meta->{_lcl_store} = $self->get_store( $meta->{"hash"},1);


	# $type =~ s/;.*//;

	# The handler return their output type if not correct 
	# or a message if processing should end
	$type = $mime_handler->{$type}( $self, $totype, $meta ) while $mime_handler->{$type};

	my $Class=join("/",@{$meta->{"_taglist"}});
	$Class =~ s|^/*(.*?)/*$|$1/-failed|;
	( $meta->{"PopFile"}, $meta->{"_Class"} ) =
	  ( pdf_class_file( $fn, \$meta->{"Text"}, $meta->{"hash"},$Class ) );
        $meta->{"Class"} = $Class;

	#$meta->{"keys"} = join( ' ', keys(%$meta) );

	# All metadata not prefixed by '_' is put into db
	#
	foreach ( keys %$meta ) {
	    next if /^_/;
	    $self->ins_e( $idx, $_, $meta->{$_} );
	}
	# make summary for caller
	$meta->{"Text"} = count_text($meta->{"Text"}) if $meta->{"Text"};
	
	if ($type eq "FAILED")
	{
	    # roll back new data
	    $dh->prepare_cached(q{delete from file where file=?})->execute($fn);
	    $idx=$type;
	}
	datelib::fixup_dates($dh);
    return $idx, $meta;
}

## Converter

# "application/vnd.openxmlformats-officedocument.presentationml.presentation"
# "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" 
# "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
# "application/msword" 
# "application/vnd.ms-powerpoint" 

sub xtp_any {
	my ($self,$totype,$pmeta) = @_;
        return "FAILED" unless $self->{config}->{unoconv_enabled};
        my $i = $pmeta->{"_file"};
	$pmeta->{_file_o}=$i;

        # Output will generally be created in the local_storage (and kept)
        my $of = $pmeta->{_lcl_store};
        $pmeta->{"_file"} = $of . "/" . basename($i) . ".pdf";
        do_unopdf( $i, $pmeta->{_file} )
		unless -r $pmeta->{_file};

        my $type = magic( $pmeta->{_file} );
        return $type;
    }

# "image/png"         => \&xtp_jpg,
# "image/jpeg"         => \&xtp_jpg,
# "image/jpg"         => \&xtp_jpg,
    sub xtp_jpg {
	my ($self,$totype,$pmeta) = @_;
	die "Cannot do: $totype"
		unless $totype eq "application/pdf";
        my $i = $pmeta->{"_file"};
	$pmeta->{__file}=$i;

        # Output will generally be created in the local_storage (and kept)
        my $of = $pmeta->{_lcl_store};
        $pmeta->{"_file"} = $of . "/" . basename($i).".ocr.pdf";;
	do_convert_pdf($i,$pmeta->{_file});
	$self->del_meta($self->{"idx"},"pdfinfo");
        my $type = magic( $pmeta->{_file} );
        return $type;
    }

# "text/plain"

    sub xtp_ascii {
	my ($self,$totype,$pmeta) = @_;
	die "Cannot do: $totype"
		unless $totype eq "application/pdf";
        my $i = $pmeta->{"_file"};
	$pmeta->{__file}=$i;

        # Output will generally be created in the local_storage (and kept)
        my $of = $pmeta->{_lcl_store};
        $pmeta->{"_file"} = $of . "/" . basename($i) . ".pdf";
        do_ascii2pdf( $i, $pmeta->{_file} );
        my $type = magic( $pmeta->{_file} );
        return $type;
    }
    
# "application/zip" 
    sub xtp_unzip {
	my ($self,$totype,$pmeta) = @_;
        my $i = $pmeta->{"_file"};
	$pmeta->{__file}=$i;

        my $of = $pmeta->{_lcl_store};

	my @archive=();
	my $err="";
	foreach( qx{echo A | unzip -d "$of" "$i"} ) {
		$err .= $_;
		next unless /(?:inflating|extracting):\s+(.*?)\s*$/;
		die "$err\nunzip problem? >$1<" unless -r $1;
		print STDERR "Do: $1\n" if $debug > 1;
		push @archive,$1;
	}
	my @md5_archive=();
	foreach ( @archive ) {
		my $hash = file_md5_hex($_);
		my $t0=$_;
		$t0 =~ s/$of(\/\.\/)?\/?//;
		my @tags=split("/+",$t0);
		pop @tags; 
		# remove file unles it will be processed
		unlink unless
			dbaccess::insert_file($self,$hash,$_,\@tags);
		push @md5_archive,$hash;
	}
	$pmeta->{"archive"}=join(",",@md5_archive);
	push @{$pmeta->{_taglist}},"deleted";
	$type = "Unizped (".scalar(@md5_archive).") files";

        return $type;
    }


# "application/epub+zip"
    sub xtp_ebook {
	my ($self,$totype,$pmeta) = @_;
        return "FAILED" unless $self->{config}->{ebook_convert_enabled};
        my $i = $pmeta->{"_file"};

        # Output will generally be created in the local_storage (and kept)
        my $of = $self->get_store( $pmeta->{"hash"},0);
        $pmeta->{"_file"} = $of . "/" . basename($i) . ".pdf";
        do_calibrepdf( $i, $pmeta->{_file} );
        my $type = magic( $pmeta->{_file} );
        return $type;
    }

# "application/x-gzip" 
    sub xtp_tar {
	my ($self,$totype,$pmeta) = @_;
        my $i = $pmeta->{"_file"};
	#$pmeta->{__file}=$i;

        my $of = $pmeta->{_lcl_store};

	my @archive=();
	foreach( qx{tar xvf  '$i' -C '$of' 2>&1} ) {
		next unless /^(x\s+)?(.*)\/?\s*\n$/;
		my $f=$of."/".$2;
		next if -d $f;
		die "untar problem? >$2<" unless -r $f;
		print STDERR "Do: $f\n" if $debug > 1;
		push @archive,$f;
	}
	delete $pmeta->{_file};
	# unlink $i if $pmeta->{_tempremove}; delete $pmeta->{_tempremove};

	my @md5_archive=();
	foreach ( @archive ) {
		my $hash = file_md5_hex($_);
		my $t0=$_;
		$t0 =~ s/$of(\/\.\/)?\/*//;
		my @tags=split("/+",$t0);
		pop @tags; 
		# remove file unles it will be processed
		unlink unless
			dbaccess::insert_file($self,$hash,$_,\@tags);
		push @md5_archive,$hash;
	}
	$pmeta->{"archive"}=join(",",@md5_archive);
	$type = "Unizped (".scalar(@md5_archive).") files";
	push @{$pmeta->{_taglist}},"deleted";

        return $type;
    }

# "application/x-gzip" 
    sub xtp_gzip {
	my ($self,$totype,$pmeta) = @_;
        my $i    = $pmeta->{"_file"};
        $self->{"_fh"} = File::Temp->new( SUFFIX => '.unzipped' );
        $pmeta->{"_file"} = $self->{"_fh"}->filename;
        do_ungzip( $i, $pmeta->{_file} );
	# $pmeta->{_tempremove}=1;  # Flag that this can be removed after usage

	push @{$pmeta->{_taglist}},"deleted";
        my $type = magic( $pmeta->{_file} );
        return $type;
    }

# "application/pdf"
    sub xtp_pdf {
	my ($self,$totype,$pmeta) = @_;
        my $t    = $self->pdf_text( $pmeta->{"_file"}, $pmeta  );
        if ($t) {
	    print STDERR "Found text ".length($t)." bytes\n";
            $t =~ s/[ \t]+/ /g;

            # short version
            $t =~ m/^\s*(([^\n]*\n){1,24}).*/s;
            my $c = $1 || "";
            $pmeta->{"Text"}    = $t;
            $pmeta->{"Content"} = $c;
        }
	my $fn=$pmeta->{"_file"};
	$pmeta->{"pdfinfo"} = $self->pdf_info($fn)
		unless $pmeta->{pdfinfo};

        my $l = length($t) || "-FAILURE-";
        return "FINISH ($l)";
    }
}


sub del_meta {
    my ( $self, $idx, $t, ) = @_;
    my $del_meta = $self->{"dh"}->prepare_cached(
        "delete from metadata where idx=? and tag=?"
    );
    $del_meta->execute($idx,$t);
}
sub ins_e {
    my ( $self, $idx, $t, $c, $bin ) = @_;
    $bin = SQL_BLOB if !defined $bin;
    my $ins_sql = $self->{dh}->prepare_cached(
        "insert or replace into metadata (idx,tag,value)
			 values (?,?,?)"
	);
    die "WOha ?  @_   " unless $idx > 0;
    $ins_sql->bind_param( 1, $idx, SQL_INTEGER );
    $ins_sql->bind_param( 2, $t );
    $ins_sql->bind_param( 3, encode("UTF-8",$c),   $bin );
    die "DBerror :$? $idx:$t:$c: " . $ins_sql->errstr
      unless $ins_sql->execute;
print STDERR "ins_e: $idx: $t (".length($c).")\n" if $debug > 2;
}

#
# try to get text from document
#  in order local_storage...ocr.pdf orig...ocr.pdf   orig.pdf
sub pdf_filename {
    my $self = shift;
    my $md5   = shift;
    my $fn=$self->get_file ($md5);
    my $f_path = dirname(abs_path($fn))."/";
    my $f_base = basename($fn,(".pdf",".ocr.pdf"));

    my $lcl_store_dir = $self->get_store( $md5,1);
    my $lcl_store = $lcl_store_dir . "/$f_base";
    die "No read: $fn" unless ( -r $fn || -r $ocrpdf );
    my @locs=( $lcl_store.".ocr.pdf", $f_path .$f_base.".ocr.pdf", $fn );
    foreach (@locs) {
        $fn=$_;
	last if -r $fn;
    }
    # Should not happen....
    die "Cannot read: $fn" unless -r $fn;

    return $fn;
}

# try to get text from document
#  in order local_storage...ocr.pdf orig...ocr.pdf   orig.pdf
sub pdf_totext {
    my $self = shift;
    my $fn   = shift;
    my $meta   = shift;
    print STDERR " pdf_totext $fn\n" if $debug > 1;
    my $f_path = dirname(abs_path($fn))."/";
    my $f_base = basename($fn,(".pdf",".ocr.pdf"));

    my $lcl_store_dir = $self->get_store( $meta->{hash},1);
    my $lcl_store = $lcl_store_dir . "/$f_base";
    die "No read: $fn" unless ( -r $fn || -r $ocrpdf );
    my @locs=( $lcl_store.".ocr.pdf", $f_path .$f_base.".ocr.pdf", $fn );
    foreach (@locs) {
        $fn=$_;
	last if -r $fn;
    }
    # Should not happen....
    die "Cannot read: $fn" unless -r $fn;

    # extract text-stream from pdf
    $txt = do_pdftotext($fn);
    # return if some text is found
    return $txt if length($txt) > 300;
    # give up if we already use an ocr version
    print STDERR "XXXXXX:  text: $txt<<<\n";
    return $txt if ( $fn =~ /.ocr.pdf$/);

print STDERR "XXXXXX> $lcl_store_dir \n" if $debug > 1;
    # do the ocr conversion
    mkdir($lcl_store_dir) unless -d $lcl_store_dir;

    $meta->{Content} = "ProCessIng";
    Documentix::Task::Processor::schedule_ocr($fn, $lcl_store .".ocr.pdf",undef,$meta);
    return undef;
}

sub pdf_text {
    my $self = shift;
    my $fn   = shift;
    my $meta = shift;
    my $txt;

    my $ofn = $fn;

    my $dh = $self->{"dh"};

    $txt = $dh->selectrow_array(
q{select value from hash natural join metadata where md5=? and tag="Text"},
        undef, $meta->{hash}
    );
    return $txt if $txt;

    return $self->pdf_totext( $fn, $meta);
}
sub slurp {
    local $/;
    open( my $fh, "<" . shift )
      or return "File ?";
    return <$fh>;
}

my $tesseract = "tesseract";

#image pre-process to enhance later ocr
sub do_convert_ocr {
    my ( $in, $outim ) = @_;
    @cmd = (
        qw{convert -density 300 },
        $in, qw {-trim -quality 70 -flatten -sharpen 0x1.0 -deskew 40% -set option:deskew:auto-crop 10},
        $outim
    );
    $msg .= "CMD: " . join( " ", @cmd, "\n" );
    $fail += ( system(@cmd) ? 1 : 0 );
    return $fail;
}

#Convert anything(images)  to pdf
sub do_convert_pdf {
    my ( $in, $out ) = @_;
    $in  = abs_path($in);
    $out = abs_path($out);
    print STDERR "convert: $in $out\n" if $debug > 1;
    $in  =~ s/"/\\"/g;
    $out =~ s/"/\\"/g;
    $out =~ s/\.pdf$//;
    my @cmd = ( $tesseract, $in, $out, qw{ -l deu+eng --psm 1 --oem 1 pdf} );
    qexec(@cmd);
    $out .= ".pdf";
	#qexec("convert", $in, $out);
    die "failed: convert: $in $out" unless -f $out;
    utime ((stat($in))[8..9],$out);
    return;
}
sub qexec
{
  local $/;
  print STDERR ">".join(":",@_)."<\n" if $debug > 3;
  open(my $f,"-|",@_);
  my $r=<$f>;
  close($f);
  return $r;
}

#convert single pdf-page to ocr-pdfpage
sub do_tesseract {
    my ( $image, $outpage ) = @_;
    my $msg;
    my @ckori = ( $tesseract, qw{ --psm 0},$image,"-" );

    my $r=qx{@ckori};

    if ($r =~ /Orientation in degrees: 180/) {
        print STDERR "Rotate...\n" if $debug > 1;
	my $oi=$image;
        $oi =~ s/(\.[^\.]*)$/_rot$1/;
	my @rot= ( $convert , $image,qw{-rotate 180},$oi);
	$msg .= "CMD: " . join( " ", @rot, "\n" ) if $debug > 3;
	system(@rot);
	$image=$oi;
    }
    my @cmd = ( $tesseract, $image, $outpage, qw{ -l deu+eng --psm 1 pdf} );
    my @cmd1 = ( $tesseract, $image, $outpage, qw{ -l deu+eng --psm 1 --oem 1 pdf} );


    $msg .= "CMD: " . join( " ", @cmd, "\n" ) if $debug > 3;
    print STDERR "$msg" if $debug > 3;
    $outpage .= ".pdf";
    $fail += ( system(@cmd) && system(@cmd1) ? 1 : 0 ) unless -f $outpage;
    print STDERR "Done $outpage\n";
    return $fail;
}

#split pdf into separate jpgs ($page) prefix
sub do_pdftocairo {
    my ( $inpdf, $pages ) = @_;

    my $tmpdir = File::Temp->newdir("/var/tmp/ocrpdf__XXXXXX");
    symlink( $inpdf, "$tmpdir/in.pdf" );
    my @cmd = ( qw{pdftocairo -r 300 -jpeg}, "$tmpdir/in.pdf", $pages );
    print STDERR "CMD: " . join( " ", @cmd, "\n" ) if $debug > 3;
    my $fail += ( system(@cmd) ? 1 : 0 );
    unlink("$tmpdir/in.pdf");
    rmdir($tmpdir) or die "DIr: $!";
    return $fail;
}

sub do_pdfstamp {
    my ( $outpdf,$cmt,$orig ) = @_;
    my $outpdf1=$outpdf.".pdf";
    my $creator;
    my $fail=0;
    open(my $ver,"version.txt");
    chomp($creator=<$ver>);
    close($ver);
    print STDERR "Stamp: $cmt\n" if  $debug > 3;
    my @tg;
    push @tg,"-tagsFromFile=$orig" if -r $orig;
    push @tg,"-Producer=$creator";
    push @tg,"-Keywords=$cmt" if $cmt;
    push @tg,"-overwrite_original_in_place";
    qexec("exiftool",@tg,$outpdf);
    qexec("qpdf","--linearize",$outpdf,$outpdf1);

    $fail++ unless  -r $outpdf1;
    utime ((stat($orig))[8..9],$outpdf1) if $orig && !$fail;
    rename $outpdf1,$outpdf unless $fail;
    return $fail;
}
sub do_pdfunite {
    my ( $outpdf, @cpages ) = @_;
    @cmd = ( qw{ pdfunite }, @cpages, $outpdf );

    #pdfunite croaks if only a single page is united
    @cmd = ( qw{ cp }, @cpages, $outpdf )
      if ( scalar(@cpages) == 1 );
    print STDERR "CMD: " . join( " ", @cmd, "\n" ) if $debug > 3;
    $fail += ( system(@cmd) ? 1 : 0 ) unless -f $outpdf;

    print STDERR "Unite into: $outpdf\n" if $debug>1;
    # die "Failure generating $outpdf" unless -f $outpdf;
    return $fail;
}

sub do_pdftotext {
    my ($pdfin) = @_;
    #Obsolete??# pdftotext has issues with spaces in the name
    #my $tmp=tmpnam().".pdf";
    #symlink(abs_path($pdfin),$tmp);
    @cmd = ( $pdftotext,qw{-enc UTF-8 -layout}, $pdfin, "-" );

    my $txt = qexec( @cmd );
    unlink $tmp;
    return decode('UTF-8',$txt);
}

sub do_calibrepdf {
    my ( $in, $out ) = @_;
    $in  = abs_path($in);
    $out = abs_path($out);
    print STDERR "convert: $in\n" if $debug > 1;
    qexec("ebook-convert", $in ,$out);
    die "failed: calibre: ebook-convert $in $out" unless -f $out;
    utime ((stat($in))[8..9],$out);
    return;
}

sub do_ascii2pdf {
    my ( $in, $out ) = @_;
    $in  = abs_path($in);
    $out = abs_path($out);
    print STDERR "ascii 2 pdf: $in\n" if $debug > 1;
    #handle non ascii as well
    my $ttl = $in;
    $ttl =~ s,^.*/,,;
    my @c = (qx{ file --mime "$in"} =~ m/charset=(\S+)/);
    qx{iconv -f "$c[0]" -t  ISO-8859-1//TRANSLIT  "$in" | a2ps  --stdin="$ttl" -X ISO-8859-1 -o - | ps2pdf - "$out"};
    die "failed: -o $out $in" unless -f $out;
    utime ((stat($in))[8..9],$out);
    return;
}

sub do_unopdf {
    my ( $in, $out ) = @_;
    $in  = abs_path($in);
    $out = abs_path($out);
    #print STDERR "convert: $in\n" if $debug > 1;
    qexec(qw{unoconv -o}, $out,$in);
    die "failed: -o $out $in" unless -f $out;
    utime ((stat($in))[8..9],$out);
    return;
}

sub do_ungzip {
    my ( $in, $out ) = @_;
    qx|gzip -dc $in > "$out"|;
    return;
}
sub get_store {
    my $self = shift;
    my $digest=shift;
    my $md = shift || 0;
    my $wdir = $self->{config}->{local_storage};
    mkdir $wdir or die "No dir: $wdir" if $md && ! -d $wdir;
    $wdir  = abs_path($wdir);
    $digest =~ m/^(..)/;
    $wdir .= "/$1";
    mkdir $wdir or die "No dir: $wdir" if $md && ! -d $wdir;

    $wdir .= "/$digest";
    mkdir $wdir or die "No dir: $wdir" if $md && ! -d $wdir;
    return $wdir;
}



1;
