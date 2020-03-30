package pdfidx;
use XMLRPC::Lite;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
use parent Docconf;

use parent DBI;
use DBI qw(:sql_types);
use Sys::Hostname;
use File::Temp qw/tempfile tmpnam tempdir/;
use File::Basename;
use Cwd 'abs_path';
use Data::Dumper;
use doclib::datelib;
# $File::Temp::KEEP_ALL = 1;
#my $debug  = $Docconf::config->{debug};

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

    my $dbn    = $Docconf::config->{database_provider};
    my $d_name = $Docconf::config->{database};
    my $user   = $Docconf::config->{database_user};
    my $pass   = $Docconf::config->{database_pass};

    my $dh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass )
      || die "Err database connection $!";
    print STDERR "New pdf conn: $dh\n" if $debug > 0;
    my $self = bless { dh => $dh, dbname => $d_name }, $class;
    $self->set_debug(undef);
    $self->{"setup_db"} = \&setup_db;
    $self->{"dh1"}      = $dh;
    trace_db($dh) if  $Docconf::config->{debug} > 3;
    setup_db($self) unless $chldno;
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
  $debug = shift @_  || Docconf::config->{"debug"};
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

    $dh->sqlite_busy_timeout(60000);
    my @slist = (
q{begin exclusive transaction},
q{create table if not exists hash ( idx integer primary key autoincrement, md5 text unique )},
q{create table if not exists data ( idx integer primary key , thumb text, ico text, html text) },
        q{create table if not exists ocr ( idx integer, text text)},
q{create table if not exists metadata ( idx integer, tag text, value text, unique ( idx,tag) )},

      # q{CREATE VIRTUAL TABLE if not exists text USING fts4(tokenize=porter);},
q{CREATE TABLE if not exists mtime ( idx integer primary key, mtime integer)},
        q{CREATE INDEX if not exists mtime_i on mtime(mtime)},
q{CREATE TABLE if not exists class ( idx integer primary key, class text )},
        q{CREATE INDEX if not exists class_i on class(class)},

        q{CREATE TRIGGER if not exists del2 before delete on hash begin
					delete from file where file.md5 = old.md5;
					delete from data where data.idx = old.idx;
					delete from metadata where metadata.idx=old.idx;
					delete from text where docid=old.idx;
					delete from mtime where mtime.idx=old.idx;
					delete from class where class.idx=old.idx;
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
		print Dumper(\%childs);
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

sub ocrpdf_offline
{
	my $self=shift;
	my $idx=shift;
my $odb=$self->set_debug($debug+5);
	$self->{"idx"}=$idx;
        $t = $self->ocrpdf(@_);
        if ($t) {
            $t =~ s/[ \t]+/ /g;
	    $self->del_meta($idx,"Text");
            $self->ins_e( $idx, "Text", $t );

            # short version
            $t =~ m/^\s*(([^\n]*\n){24}).*/s;
            my $c = $1 || "";
	    $self->del_meta($idx,"Content");
            $self->ins_e( $idx, "Content", $c );
	    $self->{"fixup_cache"}($self,$idx) if $self->{"fixup_cache"};
        }
$self->set_debug($odb);
}
sub ocrpdf {
    my $self = shift;
    my ( $inpdf, $outpdf, $ascii, $md5 ) = @_;
    my $maxcpu = $Docconf::config->{number_ocr_threads};
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
print STDERR Dumper(\$self,\$qr) if $debug > 1;
    if ($qr && $self->{"idx"} ) {
	$self->ins_e($self->{"idx"},"QR",$qr);
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
	    $self->del_meta($self->{"idx"},"pdfinfo");
	    $self->ins_e($self->{"idx"},"pdfinfo", $self->pdf_info($outpdf));
	    $txt = do_pdftotext($outpdf);
	}
	unlink(@outpages) unless $debug > 2;
    }
    unlink ("$outpdf.wip");
    $txt .= "\n$qr" if $qr;
    return $txt;
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
    $sel_qr =$dh->prepare($sel_qr);
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

sub index_pdf {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my $fn   = shift;
    my $wdir = shift;
    my $class= shift;
    print STDERR "index_pdf $fn\n" if $debug > 1;

    # make sure we skip already ocred docs
    my $fn_orig=$fn;
    $fn =~ s/\.ocr\.pdf$/\.pdf/;

    my $md5_f = file_md5_hex($fn);

    # Hack?
    # if a source document is not in a writable directory,
    # we should create a folder in "incoming/{md5}" and have a symbolic link
    # pointing to the source document.
    # the incoming, can then hold the OCR and whatever other stuff we need
    # HACK: I don't see a better way right now
    if ( $Docconf::config->{link_local}
        && !( $fn =~ /$Docconf::config->{local_storage}/ ) )
    {
        my $f_dir = dirname($fn);
        my $new   = $self->get_store( $md5_f,0);
        mkdir $new
          unless -d $new;
        $new .= "/" . basename($fn);
        symlink $fn, $new
          or die "Cannot link document... $!";
        $fn = $new;
        print STDERR "Doc linked -> $fn\n";
    }

    my ($idx) =
      $dh->selectrow_array( "select idx from hash where md5=?", undef, $md5_f );

    return $self->get_metas($md5_f) if $idx;   # already indexed -- TODO:potentially check timestamp

    $dh->do("begin exclusive transaction");
    $dh->prepare("insert or ignore into file (md5,file,host) values(?,?,?)")
      ->execute( $md5_f, $fn, hostname() );

    # $idx = $dh->last_insert_id( "", "", "", "" );
    ($idx) =
      $dh->selectrow_array( "select idx from hash where md5=?", undef, $md5_f );
    print STDERR "Loading: ($idx) $fn\n";
    $dh->do("commit");

    my %meta;
    $meta{"Docname"} = $fn;
    $meta{"Docname"} =~ s/^.*\///s;
    $self->{"file"} = $fn;
    $self->{"file_o"} = $fn_orig;
    $self->{"idx"} = $idx;
    chomp( my $type =
          qexec(qw{file --dereference --brief  --mime-type}, $fn ));
    print STDERR "Type: $type\n";
    $meta{"Mime"} = $type;
    my %mime_handler = (
        "application/x-gzip" => \&tp_gzip,
        "application/pdf"    => \&tp_pdf,
        "application/msword" => \&tp_any,
        "image/png"         => \&tp_jpg,
        "image/jpeg"         => \&tp_jpg,
        "image/jpg"         => \&tp_jpg,
	"text/plain"	     => \&tp_ascii,
"application/vnd.openxmlformats-officedocument.presentationml.presentation"
          => \&tp_any,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" =>
          \&tp_any,
"application/vnd.openxmlformats-officedocument.wordprocessingml.document"
          => \&tp_any,
        "application/epub+zip"          => \&tp_ebook,
        "application/vnd.ms-powerpoint" => \&tp_any
    );

    $meta{"size"} = ( stat($fn) )[7];
    $meta{"mtime"} = ( stat($fn) )[9];
    $meta{"hash"}  = $md5_f;
    $type =~ s/;.*//;
    $type = $mime_handler{$type}( $self, \%meta ) while $mime_handler{$type};

    print STDERR " -> $type\n";

    $meta{"Image"} = '<img src="?type=thumb&send=#hash#">';
    ( $meta{"PopFile"}, $meta{"Class"} ) =
      ( $self->pdf_class_file( $fn, \$meta{"Text"}, $meta{"hash"}, $class ) );

    $meta{"keys"} = join( ' ', keys(%meta) );

    foreach ( keys %meta ) {
        $self->ins_e( $idx, $_, $meta{$_} );
    }

    if ($type eq "FAILED")
    {
	# roll back new data
	$dh->prepare(q{delete from file where file=?})->execute($fn);
	$idx=$type;
    }
    datelib::fixup_dates($dh);

    return $idx, \%meta;

    sub tp_any {
        my $self = shift;
        my $meta = shift;
        return "FAILED" unless $Docconf::config->{unoconv_enabled};
        my $i = $self->{"file"};

        # Output will generally be created in the local_storage (and kept)
        my $of = $self->get_store( $meta->{"hash"},0);
        $self->{"file"} = $of . "/" . basename($i) . ".pdf";
        do_unopdf( $i, $self->{file} )
		unless -r $self->{file};
        my $type = do_file( $self->{file} );
        return $type;
    }
    sub tp_jpg {
        my $self = shift;
        my $meta = shift;
        my $i = $self->{"file"};

        # Output will generally be created in the local_storage (and kept)
        my $of = $self->get_store( $meta->{"hash"},0);
        $self->{"file"} = $of . "/" . basename($i) . ".pdf";
        do_convert_pdf( $i, $self->{file} );
        my $type = do_file( $self->{file} );
        return $type;
    }

    sub tp_ascii {
        my $self = shift;
        my $meta = shift;
        my $i = $self->{"file"};

        # Output will generally be created in the local_storage (and kept)
        my $of = $self->get_store( $meta->{"hash"},0);
        $self->{"file"} = $of . "/" . basename($i) . ".pdf";
        do_ascii2pdf( $i, $self->{file} );
        my $type = do_file( $self->{file} );
        return $type;
    }

    sub tp_ebook {
        my $self = shift;
        my $meta = shift;
        return "FAILED" unless $Docconf::config->{ebook_convert_enabled};
        my $i = $self->{"file"};

        # Output will generally be created in the local_storage (and kept)
        my $of = $self->get_store( $meta->{"hash"},0);
        $self->{"file"} = $of . "/" . basename($i) . ".pdf";
        do_calibrepdf( $i, $self->{file} );
        my $type = do_file( $self->{file} );
        return $type;
    }

    sub tp_gzip {
        my $self = shift;
        my $i    = $self->{"file"};
        $self->{"fh"} = File::Temp->new( SUFFIX => '.pdf' );
        $self->{"file"} = $self->{"fh"}->filename;
        do_ungzip( $i, $self->{file} );

        my $type = do_file( $self->{file} );
        return $type;
    }

    sub tp_pdf {
        my $self = shift;
        my $meta = shift;
        my $t    = $self->pdf_text( $self->{"file"}, $meta->{"hash"} );
        if ($t) {
            $t =~ s/[ \t]+/ /g;

            # short version
            $t =~ m/^\s*(([^\n]*\n){1,24}).*/s;
            my $c = $1 || "";
            $meta->{"Text"}    = $t;
            $meta->{"Content"} = $c;
            my $fn=$self->{"file"};
            $meta->{"pdfinfo"} = $self->pdf_info($self->{"file_o"});
        }
        my $l = length($t) || "-FAILURE-";
        return "FINISH ($l)";
    }

}

sub del_meta {
    my ( $self, $idx, $t, ) = @_;
    $self->{"del_meta"} = $self->{"dh"}->prepare(
        "delete from metadata where idx=? and tag=?"
    ) unless $self->{"del_meta"};
    $self->{"del_meta"}->execute($idx,$t);
}
sub ins_e {
    my ( $self, $idx, $t, $c, $bin ) = @_;
    $bin = SQL_BLOB if defined $bin;
    $self->{"new_e"} = $self->{"dh"}->prepare(
        "insert or ignore into metadata (idx,tag,value)
			 values (?,?,?)"
    ) unless $self->{"new_e"};
    $self->{"new_e"}->bind_param( 1, $idx, SQL_INTEGER );
    $self->{"new_e"}->bind_param( 2, $t );
    $self->{"new_e"}->bind_param( 3, $c,   $bin );
    die "DBerror :$? $idx:$t:$c: " . $self->{"new_e"}->errstr
      unless $self->{"new_e"}->execute;
print STDERR "ins_e: $idx: $t (".length($c).")\n" if $debug > 1;
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

    my $lcl_store_dir = $self->get_store( $md5,0);
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
    my $md5   = shift;
    print STDERR " pdf_totext $fn\n" if $debug > 1;
    my $f_path = dirname(abs_path($fn))."/";
    my $f_base = basename($fn,(".pdf",".ocr.pdf"));

    my $lcl_store_dir = $self->get_store( $md5,0);
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
    return $txt if ( $fn =~ /.ocr.pdf$/);

print STDERR "XXXXXX> $lcl_store_dir \n" if $debug > 1;
    # do the ocr conversion
    mkdir($lcl_store_dir) unless -d $lcl_store_dir;
    return $self->ocrpdf_async( $fn, $lcl_store .".ocr.pdf",undef,$md5 );
}

sub pdf_text {
    my $self = shift;
    my $fn   = shift;
    my $md5  = shift;
    my $txt;

    my $ofn = $fn;

    my $dh = $self->{"dh"};

    $txt = $dh->selectrow_array(
q{select value from hash natural join metadata where md5=? and tag="Text"},
        undef, $md5
    );
    return $txt if $txt;

    return $self->pdf_totext( $fn, $md5 );
}

sub pdf_thumb {
    my $self = shift;
    my $fn   = shift;
    my $pn   = ( shift || 1 ) - 1;
    $fn .= ".pdf" if ( -f $fn . ".pdf" );
    my $png = do_convert_thumb( $fn, $pn );
    return undef unless length($png);
    return ( "image/png", $png );
}

sub pdf_icon {
    my $self = shift;
    my $fn   = shift;
    my $pn   = ( shift || 1 ) - 1;
    my $rot  = shift;
    my $tmp  = tmpnam();

    $fn .= ".pdf" if ( -f $fn . ".pdf" );
    my $png = do_convert_icon( $fn, $pn );
    return undef unless length($png);
    return ( "image/png", $png );

# return sprintf "Content-Type: image/png\nContent-Length: %d\n\n%s", length($png), $png;
}
################# popfile interfaces
# classify unclassified

sub class_unk {
    my $self = shift;
    my $all_t =
q{select idx,md5,file,substr(value,1,10000) txt    from metadata natural join hash natural join file where tag="Text" and idx not in (select idx from tags) group by md5};

    my $all_s = $self->{"dh"}->prepare($all_t);
    $all_s->execute;
    while ( my $r = $all_s->fetchrow_hashref() ) {
        $rv = $self->pdf_class_file( $r->{"file"}, \$r->{"txt"}, $r->{"md5"},
            undef );
        $l = length( $r->{"txt"} );
        print STDERR "Tx: $r->{idx} $r->{md5} ($l)  -> $rv\n" if $debug > 1;
    }

}

sub get_class {
    my $self = shift;
    my $all_t =
q{select idx,count(*) cnt, group_concat(tagname) lst,value    from tags natural join tagname natural join metadata where tag="Text"  group by idx  order by idx };

    my $all_s = $self->{"dh"}->prepare($all_t);
    $all_s->execute;
    while ( my $r = $all_s->fetchrow_hashref() ) {
        my ( $fh, $tmp_doc ) = tempfile(
            'popfileinXXXXXXX',
            SUFFIX => ".msg",
            UNLINK => 1,
            DIR    => $temp_dir
        );
        print $fh $r->{"value"};
        close($fh);
        my $rv = $self->pop_call( 'classify', $tmp_doc );
        unlink $tmp_doc;
        next if ( $r->{lst} eq $rv );

        print STDERR "Tx: $r->{idx} $r->{lst}   -> $rv\n" if $debug > 1;
    }
}

sub set_classes {
    my $self = shift;
    my $all_t =
q{select tagname,group_concat(substr(value,1,10000)) txt  from tagname natural join tags natural join metadata where tag="Text"  group by tagname};

    # delete all buckets first ....
    my $rv = $self->pop_call('get_buckets');
    print STDERR "cln: $tg -> $rv\n" if $debug > 1;

    foreach (@$rv) {
        $rv = $self->pop_call( 'delete_bucket', $_ );
        print STDERR "Del: $_ ->$rv\n" if $debug > 1;
    }
    my $all_s = $self->{"dh"}->prepare($all_t);
    $all_s->execute;
    while ( my $r = $all_s->fetchrow_hashref() ) {
        my @res =
          $self->set_class_content( lc( $r->{"tagname"} ), \$r->{"txt"} );
    }
}

sub set_class_content {
    my $self = shift;
    my ( $tg, $rtxt ) = @_;
    $rv = $self->pop_call( 'create_bucket', to_bucketname($tg) );
    print STDERR "TG: $tg -> $rv\n" if $debug > 1;
    my ( $fh, $tmp_doc ) = tempfile(
        'popfileinXXXXXXX',
        SUFFIX => ".msg",
        UNLINK => 1,
        DIR    => $temp_dir
    );
    print $fh $$rtxt;
    close($fh);
    print STDERR " Add: $tg ($ln) -> " if $debug > 1;
    $rv =
      $self->pop_call( 'add_message_to_bucket', to_bucketname($tg), $tmp_doc );
    my $ln = length($$rtxt);
    print STDERR "$rv\n" if $debug > 1;
    unlink($tmp_doc);
}

{
    my $pop_xml="http://localhost:".$Docconf::config->{xmlrpc_port}."/RPC2";

    my $pop_cnt = 0;

    sub pop_call {
        my $self = shift;
        my $op   = shift;
        my $sk   = $self->pop_session();
        my $r =
          XMLRPC::Lite->proxy($pop_xml)->call( "POPFile/API.$op", $sk, @_ );
        return $r->result;
    }

    sub pop_session {
        my $self = shift;
        return $self->{"sk"} if $self->{"sk"};
        $self->{"sk"} =
          XMLRPC::Lite->proxy($pop_xml)
          ->call( 'POPFile/API.get_session_key', 'admin', '' )->result;
        print STDERR "POP Session: $self->{sk}\n";

     # Check buckets in popfile
     # ensure that at least a single bucket other than unclassified is available
        my $bucket_list = $self->pop_call('get_buckets');
        $self->pop_call( 'create_bucket', 'default' )
          unless ( scalar(@$bucket_list) );
        return $self->{"sk"};
    }

    sub to_bucketname {
        my $bn = lc(shift);
        $bn =~ s/[^a-z0-9\-_]/_/g;
        return $bn;
    }

    sub pop_release {
        return;

        # return if $pop_cnt>0;
        # $pop_cnt--;
        # XMLRPC::Lite->proxy($pop_xml)
        #   ->call( 'POPfile/API.release_session_key', $popsession )
        #   if $popsession;
        # undef $popsession;
    }

    END {
        # $self->pop_release();
    }
}

sub get_popfile_r {
    my ( $fn, $md5, $rtxt ) = @_;

    # and a temporary file, with the full path specified
    my ( $fh, $tmp_doc ) = tempfile(
        'popfileinXXXXXXX',
        SUFFIX => ".msg",
        UNLINK => 1,
        DIR    => $temp_dir
    );

    my $f = $fn;
    $f =~ s/^.*\///;
    print $fh "Subject:  $f\n";
    print $fh "From:  Docusys\n";
    print $fh "To:  Filesystem\n";
    print $fh "File:  $fn\n";
    print $fh "Message-ID: $md5\n";
    print $fh "\n";

    # print $fh "$xinfo";

    # print $fh "$p\n";
    my $tx = substr( $$rtxt, 0, 100000 );
    $tx =~ s/[^a-zA-Z_0-9]+/ /g;
    print $fh $tx;

    print "T:$md5, $tx" if ( $debug > 2 );
    close($fh);
    return $tmp_doc;
}

sub db_prep {
    my ( $self, $name, $sql ) = @_;
    $self->{$name} = $self->{"dh"}->prepare($sql)
      unless $self->{$name};
    return $self->{$name};
}

sub pdf_class_md5 {
    my $self  = shift;
    my $md5   = shift;
    my $class = shift;    # undef returns class else set class
    my $gt_info = $self->db_prep( "get_info",
q{ select file,substr(value,1,10000) txt from hash natural join file natural join metadata where md5=? and tag="Text"}
    );

    my $r = $self->{"dh"}->selectrow_hashref( $gt_info, undef, $md5 );
    return $self->pdf_class_file( $r->{"file"}, \$r->{"txt"}, $md5, $class );

}

sub pdf_class_file {
    my $self  = shift;
    my $fn    = shift;    #optional file-name
    my $rtxt  = shift;    # text to classify
    my $md5   = shift;
    my $class = shift;    # undef returns class else set class a '-' as the first char removes the class

    print STDERR "Add tag: $class\n" if $debug > 0;
    if ( $class =~ m|^(-?)(.*/.*)| ) {
        # allow multiple tags at once
	my $r="";
	foreach( split(m|/|,$2)) {
		$r.=$self->pdf_class_file($fn,$rtxt,$md5,$1.$_);
	}
	return $r;
    }
    my $rv;
    my $ln;

    my $tmp_doc = get_popfile_r( $fn, $md5, $rtxt );
    my $op      = "handle_message";
    my $dbop    = "insert or ignore into tags (idx,tagid)
		       select idx,tagid from hash,tagname where md5=? and tagname =?";
    my $db_op = $self->db_prep( "add_tag", $dbop );

    if ( $class && $class =~ s/^-// ) {
	# remove tags and message from bucket
        my $dbop =
          "delete from tags where idx=(select idx from hash where md5=?) and
				 tagid = (select tagid from tagname where tagname = ?)";
        $db_op = $self->db_prep( "rm_tag", $dbop );
	$rv = $self->pop_call( "remove_message_from_bucket", $class, $tmp_doc );
    }
    elsif ($class) {
        # Set&create  specific class and add tag

        my $dbop = "insert or ignore into tagname (tagname) values(?)";
	my $b = to_bucketname($class);
	$rv = $self->pop_call( "create_bucket", $b );
	$rv = $self->pop_call( "add_message_to_bucket", $b, $tmp_doc );
	$self->db_prep( "add_class", $dbop )->execute($class);
	$rv = $class if $rv;

    }
    else {
        # ask for class
        my ( $fh_out, $tmp_out ) = tempfile(
            'popfileinXXXXXXX',
            SUFFIX => ".out",
            UNLINK => 1,
            DIR    => $temp_dir
        );
        $rv = $self->pop_call( 'handle_message', $tmp_doc, $tmp_out );
        $class = $rv;
        die "Ups: $class" unless $class;
        while (<$fh_out>) {
            ( $ln = $1, last ) if m/X-POPFile-Link:\s*(.*?)\s*$/;
        }

        print STDERR "$r\nLink: $ln\n" if $debug > 1;
        close($rh_out);
        unlink($tmp_out);

        my $dbop = "insert or ignore into tagname (tagname) values(?)";
	$self->db_prep( "add_class", $dbop )->execute($class);

    }
    close($fh_out);
    $db_op->execute( $md5, $class );
    unlink($tmp_doc);
    printf STDERR "Class: $rv\n" if $debug > 1;

    return ( $ln, $rv );
}

####################################################
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

sub do_convert_pdf {
    my ( $in, $out ) = @_;
    $in  = abs_path($in);
    $out = abs_path($out);
    print STDERR "convert: $in $out\n" if $debug > 1;
    $in  =~ s/"/\\"/g;
    $out =~ s/"/\\"/g;
    qexec("convert", $in, $out);
    die "failed: convert: $in $out" unless -f $out;
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

sub do_convert_thumb {
    my ( $fn, $pn ) = @_;
    $fn .= "[$pn]";
    my @cmd = ( $convert, $fn, qw{-trim -normalize -thumbnail 400 png:-} );
    print STDERR "X:" . join( " ", @cmd ) . "\n" if $debug>2;
    my $png = qexec(@cmd);
    return $png;
}

sub do_convert_icon {
    my ( $fn, $pn ) = @_;

    my @cmd = (
        $pdftocairo, "-scale-to", $Docconf::config->{icon_size}, "-png", "-singlefile","-f",
        $pn, "-l", $pn, $fn, "-"
    );

    print STDERR "X:" . join( " ", @cmd ) . "\n" if $debug > 1;
    my $png = qexec(@cmd);
    print STDERR "L:" . length($png) . "\n" if $main::debug > 1;
    return $png;
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
    qexec("touch","-r",$orig,$outpdf1) if $orig && !$fail;
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
    # pdftotext has issues with spaces in the name
    my $tmp=tmpnam().".pdf";
    symlink(abs_path($pdfin),$tmp);
    @cmd = ( $pdftotext, $tmp, "-" );

    my $txt = qexec( @cmd );
    unlink $tmp;
    return $txt;
}

sub do_calibrepdf {
    my ( $in, $out ) = @_;
    $in  = abs_path($in);
    $out = abs_path($out);
    print STDERR "convert: $in\n" if $debug > 1;
    main::lock();
    qexec("ebook-convert", $in ,$out);
    main::unlock();
    die "failed: calibre: ebook-convert $in $out" unless -f $out;
    return;
}

sub do_ascii2pdf {
    my ( $in, $out ) = @_;
    $in  = abs_path($in);
    $out = abs_path($out);
    print STDERR "ascii 2 pdf: $in\n" if $debug > 1;
    qx{a2ps -o - "$in" | ps2pdf - "$out"};
    die "failed: -o $out $in" unless -f $out;
    return;
}

sub do_unopdf {
    my ( $in, $out ) = @_;
    $in  = abs_path($in);
    $out = abs_path($out);
    print STDERR "convert: $in\n" if $debug > 1;
    main::lock();
    qexec(qw{unoconv -o}, $out,$in);
    main::unlock();
    die "failed: -o $out $in" unless -f $out;
    return;
}

sub do_file {
    my ($in) = @_;
    chomp( my $type = qexec(qw{file -b --mime-type}, $in));
    return $type;
}

sub do_ungzip {
    my ( $in, $out ) = @_;
    qx|gzip -dc $i > "$out"|;
    return;
}
sub get_store {
    my $self = shift;
    my $digest=shift;
    my $md = shift || 0;
    my $wdir = $Docconf::config->{local_storage};
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
