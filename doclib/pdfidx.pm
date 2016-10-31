package pdfidx;
use XMLRPC::Lite;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);

use parent DBI;
use DBI qw(:sql_types);
use File::Temp qw/tempfile tempdir/;
$File::Temp::KEEP_ALL = 1;
my $mth=1;
my $tools="/usr/pkg/bin";
$tools="/home/thilo/documentix/tools" unless -d $tools;

$tools="/usr/local/bin" unless -d $tools;

# Used tools
my $convert="$tools/convert";
my $lynx="$tools/lynx";
my $pdfimages="$tools/pdfimages";
my $pdfinfo="$tools/pdfinfo";
my $pdfopt="$tools/pdfopt";
my $pdftoppm="$tools/pdftoppm";
my $pdftotext="$tools/pdftotext";
my $tesseract="$tools/tesseract";
 
# use threads;
# use threads::shared;

my $cleanup = 0;

my $db_con;
sub new {
    my $dbn    = "SQLite";
    my $d_name = "db/doc_db.db";
    my $user   = "";
    my $pass   = "";
    my $class  = shift;
    return $db_con if $db_con;
    my $dh     = DBI->connect( "dbi:$dbn:$d_name", $user, $pass )
      || die "Err database connection $!";

    $dh->{"setup_db"} = \&setup_db;
    my $self = bless { dh => $dh,dbname => $d_name }, $class;
    setup_db($self);
    $db_con=$self;
    return $self;
}
sub dbname {
    my $self = shift;
    return $self->{"dbname"};
}

sub setup_db {
    my $self = shift;
    my $dh   = $self->{"dh"};

    $dh->sqlite_busy_timeout( 60000 );
   my @slist=(
	q{create table if not exists hash ( idx integer primary key autoincrement, md5 text unique )} ,
	q{create table if not exists file ( md5 text primary key, file text unique)} ,
	q{create table if not exists data ( idx integer primary key , thumb text, ico text, html text) } ,
	q{create table if not exists ocr ( idx integer, text text)},
	q{create table if not exists metadata ( idx integer, tag text, value text, unique ( idx,tag) )} ,
	q{create table if not exists cache (type text,item text,idx integer,data blob,date integer, unique (item,idx))},
	q{CREATE VIRTUAL TABLE if not exists text USING fts4(tokenize=porter);},
	q{CREATE TABLE if not exists mtime ( idx integer primary key, mtime integer)},
	q{CREATE INDEX if not exists mtime_i on mtime(mtime)},
	q{CREATE TABLE if not exists class ( idx integer primary key, class text )},
	q{CREATE INDEX if not exists class_i on class(class)},

	q{CREATE TRIGGER if not exists del2 before delete on hash begin 
					delete from file where file.md5 = old.md5; 
					delete from data where data.idx = old.idx; 
					delete from metadata where metadata.idx=old.idx; 
					delete from cache where cache.idx=old.idx; 
					delete from text where docid=old.idx; 
					delete from mtime where mtime.idx=old.idx; 
					delete from class where class.idx=old.idx; 
				 end;},
	q{CREATE TRIGGER if not exists inmtime after insert on metadata when 
	                    new.tag = "mtime" begin 
			    insert into mtime (idx,mtime) values (new.idx,new.value); 
		end;},
	q{CREATE TRIGGER if not exists inclass after insert on metadata when 
	                    new.tag = "Class" begin 
			    insert into class (idx,class) values (new.idx,new.value); 
		end;},
	q{CREATE TRIGGER if not exists intxt after insert on metadata when new.tag = "text" begin 
			insert into text (docid,content) values (new.idx,new.value); 
					end;},
	q{ CREATE INDEX if not exists mtags on metadata(tag)}

);
foreach(@slist)
{
	#print STDERR "DO: $_\n";
	$dh->do($_);
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
    while ( $tpl =~ s/{\*([A-Z0-9a-z]+)}(.*?){\*}/RPT>$2</s ) {
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
    my $q="select file from file where md5=?"; 
    print STDERR "$q : $md5\n";
    my $fn =
      $dh->selectcol_arrayref( $q, undef, $md5 );
    foreach(@$fn)
    {
	    # return the first readable
	    return $_ if -r $_;
    }
    return $$fn[0];
}

sub get_metas {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ( $fn ) = @_;
    my $res = $dh->selectall_hashref(
        "select tag,value from hash natural join metadata where md5=?",
        "tag", undef, $fn
    );
    return $res;
}

sub get_meta {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ( $typ, $fn ) = @_;
    my $idx = $dh->selectrow_array(
        "select value from hash natural join metadata where md5=? and tag = ?",
        undef, $fn, $typ
    );
    return $idx;
}

sub get_cont {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ( $typ, $fn ) = @_;
    my $idx =
      $dh->selectrow_array( "select idx from hash where md5=?", undef, $fn );
    return unless $idx;
    my $q = "select value from metadata where idx=? and tag=\"$typ\"";
    my $gt = $dh->prepare($q);
    my $res = $dh->selectrow_array( $gt, undef, $idx );

    return $res;

}

sub pdf_info($$) {
    my $self = shift;
    my $fn  = shift;
    my $res = qx{$pdfinfo \"$fn\"};
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
        print STDERR "Expand: $var / $md5\n";

        if ( $md5 && !$$db->{$md5} ) {
            print STDERR "Fetch: $md5\n";
            my $res = $dh->selectall_hashref(
                q{select idx,tag,value from file 
				natural join hash natural join metadata 
				    where md5=?}, "tag", undef, $md5
            );
            $$db->{$md5}->{$_} = $res->{$_}->{"value"} foreach ( keys %$res );
            $$db->{$md5}->{"KEYS"} =
              join( ' ', keys( %{$$db->{$md5}} ) );
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
use PDF::API2;
use XML::Parser::Expat;
my %childs;

sub w_load {
    my $l   = shift;
    my $err = 0;
    my $pid;
    while ( ( my $pn = scalar( keys(%childs) ) ) > $l ) {
        print STDERR "($pn) ";
        delete $childs{$pid} if ( ( ( $pid = wait ) ) > 0 );
        $err++ if $? != 0;
    }
    return $err;
}

sub pdftohtml {
    my $self = shift;
    my ( $inpdf, $tmpdir ) = @_;
    my $dh   = $self->{"dh"};

    # extract all pages first
    die "$inpdf" unless -r $inpdf;
    system( "$pdfimages", $inpdf, "-all", "$tmpdir/page" );
    return undef if $?;
    my @rot;
    foreach $p (qx{$pdfinfo -l 9999 "$inpdf"})
    {
	next unless $p =~ m/Page\s+(\d+)\s+rot:\s+(\d+)/;
	$rot[$1]=$2;
    }
    my $errs = 0;
    my @pages;
    my @images= glob("$tmpdir/page-*");
    if ( scalar(@images) == 0 || scalar(@images) > scalar(@rot) )
    {
	    # try conversion differently
	    # using pdftoppm
	    print STDERR "Using pdftoppm\n";
	    qx{$pdftoppm -r 300 '$inpdf' '$tmpdir/ppage'};
	    die "Ups: pdftoppm $? " if $?;
	    @images=glob("$tmpdir/ppage-*");
	    $_=0 
	    	foreach (@rot);
    }
    printf STDERR "Converting %d Pages\n",scalar(@images);
    foreach (@images)
    {
	m/(^.*page-(\d+)((-\d+)?))\.(.*)/;
	my $page=$2;
	my $base=$1;
	my $ext=$5;

        # push @pages, "$base.html";
        push @pages, "$base.hocr";

        my $pid=0;
	if ( !$mth ||  ( $pid = fork() ) == 0 ) 
	{
	    $dh->disconnect  if  $mth;
            print STDERR "Conv $_\n";
	    my $o="$base.prc.$ext";
	    my $o="$base.prc.tiff";
            my $fail = 0;
            unless ( -f "$base.html" ) {

		# $fail += (system("$convert", $_,"-trim","+repage", 
		# "-normalize", "-gamma", "2.0", $o) ? 1 : 0) unless -f $o;
		my @opt=qw{-normalize}; #  -gamma 2.0};
		push @opt,("-rotate", $rot[$page]) if $rot[$page] != 0;
		print STDERR join(" ",( "$convert", $_, @opt, $o,"\n" ));
                $fail += (
                    system( "$convert", $_, @opt, $o )
                    ? 1
                    : 0 )
                  unless -f $o;

# $fail += (system("$convert", $_, "-gravity","north","-background","red","-splice","0x1","-trim","-chop","0x1", "-normalize", "-gamma", "2.0", $o) ? 1 : 0) unless -f $o;
                unlink $_ if $cleanup;
                $fail += (
                    system(
                        "$tesseract",   $o,     $base, "-l",
                        "deu+eng+equ", "-psm", "1", "hocr"
                    ) ? 1 : 0
                );
                unlink $o if $cleanup;
            }
            print STDERR "$base - done($fail)\n";
	    exit($fail) if $mth;
	    $errs += $fail;
        }
	$childs{$pid}++;
        $errs += w_load(5);
    }
    print STDERR "Wait..\n";
    $errs += w_load(0) if $mth;
    print STDERR "Done Errs:$errs\n";
    return @pages;
}

sub ocrpdf {
    my $self = shift;
    my ( $inpdf, $outpdf, $ascii ) = @_;
    my $txt    = undef;
    my @htmls;
    my $tmpdir = File::Temp->newdir( "/var/tmp/ocrpdf__XXXXXX");
    my @htmls = $self->pdftohtml( $inpdf, $tmpdir );
# return unless scalar(@htmls);
    if ( scalar(@htmls) )
    {
	    $self->join_pdfhtml($tmpdir,$outpdf,$inpdf,@htmls);
	    print STDERR "Call lynx for: @htmls\n";
	    my $outhtml=$outpdf; $outhtml =~ s/\.pdf/.html/;
	    my $o;
	    foreach (@htmls) {
		$o .= slurp($_);
		$txt .= qx{$lynx -force_html -display_charset=utf-8  -dump "$_"};
		$txt .= '\f';
	    }
	    open HTM,">$outhtml";
	    print HTM $o;
	    close HTM;
	    if ($ascii) {
		open( FD, ">$ascii" );
		print FD $txt;
		close(FD);

		# print STDERR $txt;
	    }
	    print STDERR "Creating: $outpdf\n";
	    unlink @htmls if $cleanup;
    }
    # rmdir $tempdir if $cleanup;
    return $txt;

}
# Read input pdf and join the given html file
sub mk_pdf
{
    my $self = shift;
    my ($outpdf,$inpdf,$htm)=@_;
    my $tmpdir = tempdir( CLEANUP => 1,TEMPLATE=>"/tmp/mkpdf_XXXXXX");
    my $pn="00";
    my $h=slurp($htm);
    while( $h=~ s|^\s*<.*?</html>\s*||s )
    {
	my $p="$tmpdir/page-$pn.html";
	open (P,">$p"); print P $&; close P;
	push @html,$p;
	$pn++;
    }
    $outpdf=$tmpdir."/out.pdf" unless $outpdf;
    $self->join_pdfhtml($tmpdir,$outpdf,$inpdf,@html);
    if ( $outpdf =~ /^$tmpdir/ )
    {
	return slurp($outpdf);
    }
    return 1;
}
sub join_pdfhtml
{
    my $self=shift;
	my ($tmpdir,$outpdf,$inpdf,@htmls)=@_;

    my $pdf;
    eval { $pdf = PDF::API2->open($inpdf) };
    if (!$pdf && $@ =~ /not a PDF file version|cross-reference stream/)
    {
	warn "Converting....\n";
	system("$pdfopt '$inpdf' $tmpdir/x.pdf");
	$inpdf="$tmpdir/x.pdf";
        eval { $pdf = PDF::API2->open($inpdf) };
    }
    system("ls -l '$inpdf'");
    warn "Failed open <$inpdf> $@ $? @_" unless $pdf;
    return unless $pdf;
    my $pages = $pdf->pages();
    $font = $pdf->corefont('Helvetica');
    my $pn = 0;

    foreach $html (@htmls) {
	next unless -f $html;
	
	$pn++;
	$pn = $1 if $html =~ /-(\d+)-\d+\.html/;
	# print STDERR "Check: $html\n";
	$self->add_html( $pdf, $pn, $html );
    }
    $pdf->saveas($outpdf);
    return 1;

    sub add_qrcode {
	my $pdf         = shift;
	my $page_number = shift;
	my $html        = shift;

	my $page = $pdf->openpage($page_number);
	my ( $llx, $lly, $urx, $ury ) = $page->get_mediabox;
	my $gfx = $page->gfx();
	use GD::Image;
	use GD::Barcode;
	my $o = GD::Barcode->new( 'QRcode', $html,
	    { Ecc => 'M', Version => 2, ModuleSize => 2 } );
	my $gd = $o->plot( NoText => 1 );

	my $img = $pdf->image_gd($gd);
	$gfx->image( $img, $llx, $ury - 72, 72, 72 );

    }

    sub add_html {
	my $self        = shift;
	my $pdf         = shift;
	my $page_number = shift;
	my $html        = shift;

	my $page = $pdf->openpage($page_number);
	die "No page: $page_number" unless $page;
	my $text = $page->text();
	$text->render(3);

	my ( $llx, $lly, $urx, $ury ) = $page->get_mediabox;

	# print LOG "MB: $llx $lly $urx $ury\n";

	my $parser = XML::Parser::Expat->new;
	$parser->setHandlers( 'Start' => \&sh );
	$parser->{"my_text"} = $text;
	my $bbox;
	my ( $px0, $py0, $wx, $wy );
	$parser->parsefile($html);
	return;

	sub conv_xy {
	    my ( $x, $y ) = @_;

	    #MB: 0 0 595 842
	    #BBOX: 0 0 2479 3508
	    #CH (1765 122 1899 166):�<80><98>Keith
	    #CH (1925 125 1964 166):Et
	    #CH (1983 123 2106 177):Keep
	    $x = $x * $urx / $wx;
	    $y = ( $wy - $y ) * $ury / $wy;
	    return ( $x, $y );
	}

	sub sh {
	    my ( $p, $el, %atts ) = @_;
	    if ( $atts{'class'} eq 'ocr_page' ) {
		( $px0, $py0, $wx, $wy ) =
		  $atts{'title'} =~ m/bbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/;

		#print LOG "BBOX: $px0 $py0 $wx $wy\n";
		return;
	    }
	    return unless ( $el eq 'span' );
	    return unless $atts{'class'} eq 'ocrx_word'
		    ||  $atts{'class'} eq 'ocr_word';
	    $p->setHandlers( 'Char' => \&ch )
	      if ( $el eq 'span' );
	    $bbox = $atts{'title'};

	    # print "SH:$el\n";
	    # print Dumper(\%atts);
	}

	sub ch {
	    my ( $p, $el ) = @_;
	    return if $el =~ /^\s*$/;
	    $bbox =~ m/(\d+)\s(\d+)\s(\d+)\s(\d+)/;

	    #print LOG "BB $bbox\n";
	    # Add some text to the page
	    my ( $x1, $y1 ) = conv_xy( $1, $2 );
	    my ( $x2, $y2 ) = conv_xy( $3, $4 );
	    my $w    = $x2 - $x1;
	    my $h    = $y1 - $y2;
	    my $x    = $x1;
	    my $y    = $y2;
	    my $text = $p->{"my_text"};
	    die "ups" unless $text;
	    $text->font( $font, 10 );
	    my $fs = 10. * $w / $text->advancewidth($el);
	    $text->font( $font, $fs );
	    $y += 0.2 * $fs if ( $el =~ /[gjpqy,;]/ );
	    $text->translate( $x, $y );
	    $text->text($el);

	    # print STDERR "CH ($x $y $w $h):$el\n";

	    # print Dumper($p->context);
	}

    }
}

sub index_pdf {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my $fn   = shift;

    # make sure we skip already ocred docs
    $fn =~ s/\.ocr\.pdf$/\.pdf/;

    my $md5_f = file_md5_hex($fn);

    my ($idx) =
      $dh->selectrow_array( "select idx from hash where md5=?", undef, $md5_f );

    return $idx if $idx;   # already indexed -- TODO:potentially check timestamp



    # $dh->do("begin exclusive transaction");
    $dh->prepare("insert into file (md5,file) values(?,?)")
      ->execute( $md5_f, $fn );

    $idx = $dh->last_insert_id( "", "", "", "" );
    print STDERR "Loading: ($idx) $fn\n";
    # my ($idx) = $dh->selectrow_array( "select idx from hash where md5=?", undef, $md5_f );

    my $thumb = $self->pdf_thumb($fn);
    my $ico   = $self->pdf_icon($fn);
if(0){
    my $ins_d = $dh->prepare("insert into data (idx,thumb,ico) values(?,?,?)");
    $ins_d->bind_param( 1, $idx,   SQL_INTEGER );
    $ins_d->bind_param( 2, $thumb, SQL_BLOB );
    $ins_d->bind_param( 3, $ico,   SQL_BLOB );
    $ins_d->execute();
}
    my %meta;
    $meta{"Docname"} = $fn;
    $meta{"Docname"} =~ s/^.*\///s;
    $meta{"Text"} = $self->pdf_text( $fn, $md5_f );
    $meta{"Text"} =~ m/^\s*(([^\n]*\n){24}).*/s;
    $meta{"Content"} = $1;
    $meta{"mtime"}   = ( stat($fn) )[9];
    $meta{"hash"}    = $md5_f;
    $meta{"pdfinfo"} = $self->pdf_info($fn);
    $meta{"Image"}   = '<img src="?type=thumb&send=#hash#">';
    ($meta{"PopFile"},$meta{"Class"})   = ($self->pdf_class( $fn, \$meta{"Text"}, $meta{"hash"} ));

    $meta{"keys"} = join( ' ', keys(%meta) );
    foreach ( keys %meta ) {
	$self->ins_e($idx, $_, $meta{$_} );
    }
if(0){
    # load and fill file-template
    my $tpl = slurp("/home/thilo/public_html/fl/t2/templ_doc.html");

    #my $tpl=slurp("template_pdf.html");
    $tpl = expand_templ( $dh, $tpl, \%meta );
    #BADBAD $tpl = sprintf "Content-Type: text/html; charset=utf-8\nContent-Length: %d\n\n%s", length($tpl), $tpl;
    $dh->prepare(q{update data set html=? where idx=? })->execute( $tpl, $idx );
}
    # $dh->do("commit");
    $meta{"thumb"} = \$thumb;
    $meta{"ico"}   = \$ico;
    return $idx, \%meta;
}
sub ins_e
{
	my ($self,$idx,$t,$c,$bin)=@_;
	$bin = SQL_BLOB if defined $bin;
	$self->{"new_e"}= $self->{"dh"}->prepare("insert or ignore into metadata (idx,tag,value)
			 values (?,?,?)")
		unless $self->{"new_e"};
	$self->{"new_e"}->bind_param( 1, $idx,SQL_INTEGER);
	$self->{"new_e"}->bind_param( 2, $t);
	$self->{"new_e"}->bind_param( 3, $c, $bin );
	die "DBerror :$? $idx:$t:$c: ".$self->{"new_e"}->errstr unless
	$self->{"new_e"}->execute;
}

sub pdf_text {
    my $self = shift;
    my $fn   = shift;
    my $md5  = shift;
    my $txt;

    # return "--not--available--";
    # split pdf into page
    my $ofn = $fn;
    $ofn =~ s/\.pdf$/.txt/;
    # return slurp($ofn) if ( -f $ofn );

    my $dh=$self->{"dh"};

    $txt = $dh->selectrow_array( q{select value from hash natural join metadata where md5=? and tag="Text"},
	    undef, $md5 );
    return $txt if $txt;
    #$fn=~ s/\$/\\\$/g;
    # $txt = qx{pdftotext "$fn" -};
    $txt = qx{$pdfopt "$fn" /tmp/$$.pdf >/dev/null || cp "$fn" /tmp/$$.pdf; $pdftotext /tmp/$$.pdf -; rm /tmp/$$.pdf};
    undef $txt  if length($txt) < 100;
    return $txt if $txt;
    # next ressort to ocr 
    my $newpdf = $fn; $newpdf =~ s/\.pdf$/.ocr.pdf/;
    $txt = $self->ocrpdf( $fn, $newpdf );
    return $txt;
}

sub pdf_thumb {
    my $self=shift;
    my $fn = '"'.shift.'"';
    my $pn = (shift || 1) - 1;
    $fn .= "[$pn]";
    my @cmd =
      ( $convert, $fn, qw{-trim -normalize -thumbnail 400 png:-} );
    print STDERR "X:".join(" ",@cmd)."\n";
    my $png = qx{@cmd};
    return undef unless length($png);
    return ("image/png",$png);
    # return sprintf "Content-Type: image/png\nContent-Length: %d\n\n%s", length($png), $png;
}

sub pdf_icon {
    my $self=shift;
    my $fn = '"'.shift.'"';
    my $pn = (shift || 1) - 1;
    my $rot = shift;
    $fn .= "[$pn]";
    my @cmd = ( $convert, $fn, qw{-trim -normalize -thumbnail 100});
    push @cmd,"-rotate",$rot if $rot;
    push @cmd, "png:-";
{
    # HACK
    my $tmp="/tmp/$$.tmp";
    $cmd[1] = "\$(eval $tmp.*)";
    $fn =~ s/\[$pn\]$//;
    my @c1 = ( $pdfimages ,"-all","-f",$pn+1,"-l",$pn+1,$fn,$tmp);
    print STDERR "X1:".join(" ",@c1)."\n";
    #unshift @cmd,@c1,"&&";
    qx {@c1};
    my @l=glob("'${tmp}*'");
    print STDERR "  R:".join(":",@l,"\n");
    $cmd[1]=$l[0];
    #unlink glob("$tmp.*");
}
    print STDERR "X:".join(" ",@cmd)."\n";
    my $png = qx{@cmd};
    return undef unless length($png);
    return ("image/png",$png);
    # return sprintf "Content-Type: image/png\nContent-Length: %d\n\n%s", length($png), $png;
}
sub classify_all
{
    my $self = shift;
    my $all_t = qw{ select idx,md5,Tag,Value from hash natural join metadata where Tag =  "Text" };
    my $all_s=$self->{"dh"}->prepare($all_t);
    $all_s->execute;
    my $sk  = pop_session();
    while( my $r=fetch_hashref() )
    {
	my @res=$self->class_txt($fn,$txt,$md5,$sk);
    }
}
{
	my $popsession=undef;
	sub pop_session {
		$popsession  = XMLRPC::Lite->proxy('http://localhost:8081/RPC2')
		      ->call( 'POPFile/API.get_session_key', 'admin', '' )->result
		      unless $popsession;
		return $popsession;
	}
        sub pop_release
	{
		XMLRPC::Lite->proxy('http://localhost:8081/RPC2')
			->call( 'POPFile/API.release_session_key', $popsession )
			if $popsession;
		undef $popsession;
	}

	END{
	    pop_release();
	}
}

sub pdf_class2 {
    my $self  = shift;
    my $fn  = shift;
    my $txt = shift;
    my $md5 = shift;
    my $classify=0;
    # my $classify = shift || 0;
    my $sk;
    eval { $sk  = pop_session() };
    return undef unless $sk;
    my $temp_dir = "/var/tmp";
     
    # and a temporary file, with the full path specified
    my ($fh, $tmp_doc) 
	= tempfile('popfileinXXXXXXX', SUFFIX => ".msg", UNLINK => 1 , DIR => $temp_dir);
     
    my $f = $fn;
    $f =~ s/^.*\///;
    print $fh "Subject:  $f\n";
    print $fh "From:  Docusys\n";
    print $fh "To:  Filesystem\n";
    print $fh "File:  $fn\n";
    print $fh "Message-ID: $md5\n";
    print $fh "\n";
    print $fh $$txt;
    close($fh);
# system("head -40 $tmp_doc");

    my ($fh_out, $tmp_out) 
	= tempfile('popfileinXXXXXXX', SUFFIX => ".out", UNLINK => 1, DIR => $temp_dir);
    chmod( 0622,$tmp_out);
    chmod( 0644,$tmp_doc);
    my $typ='POPFile/API.handle_message';
    $typ='POPFile/API.classify' if $classify;
    my $resv = XMLRPC::Lite->proxy('http://localhost:8081/RPC2')
	    ->call( $typ, $sk, $tmp_doc,$tmp_out );
    unlink($tmp_doc);
    my $res=$resv ->result;
    use Data::Dumper;
    die "ups: $tmp_out" . Dumper($resv) unless $res;
    my $ln=undef;
    unless ($classify)
    {
	while(<$fh_out>) {
		($ln=$1, last) if m/X-POPFile-Link:\s*(.*?)\s*$/;
	}
    }
    close($fh_out);
    unlink($tmp_out);
    return ($ln,$res);
}
sub pdf_class {
    my $self  = shift;
    my $fn  = shift;
    my $txt = shift;
    my $md5 = shift;
    my $classify = shift || 0;
    my $sk;
    eval { $sk  = pop_session() };
    return undef unless $sk;
    my $temp_dir = "/var/tmp";
     
    # and a temporary file, with the full path specified
    my ($fh, $tmp_doc) 
	= tempfile('popfileinXXXXXXX', SUFFIX => ".msg", UNLINK => 1 , DIR => $temp_dir);
     
    my $f = $fn;
    $f =~ s/^.*\///;
    print $fh "Subject:  $f\n";
    print $fh "From:  Docusys\n";
    print $fh "To:  Filesystem\n";
    print $fh "File:  $fn\n";
    print $fh "Message-ID: $md5\n";
    print $fh "\n";
    print $fh "$xinfo";

    # print $fh "$p\n";
    my $tx= substr($$txt,0,100000);
    $tx =~ s/\s+/ /g;
    print $fh $tx;

    # print "T:$tf:$msg\n";
    close($fh);

    my ($fh_out, $tmp_out) 
	= tempfile('popfileinXXXXXXX', SUFFIX => ".out", UNLINK => 1, DIR => $temp_dir);
    chmod( 0622,$tmp_out);
    chmod( 0644,$tmp_doc);
    $sk  = XMLRPC::Lite->proxy('http://localhost:8081/RPC2') ->call( 'POPFile/API.get_session_key', 'admin', '' )->result;
    my $typ='POPFile/API.handle_message';
    $typ='POPFile/API.classify' if $classify;
    my $resv = XMLRPC::Lite->proxy('http://localhost:8081/RPC2')
	    ->call( $typ, $sk, $tmp_doc,$tmp_out );
	XMLRPC::Lite->proxy('http://localhost:8081/RPC2') ->call( 'POPFile/API.release_session_key', $sk );
    my $res=$resv
	    ->result;
    use Data::Dumper;
    die "ups: $tmp_out" . Dumper($resv) unless $res;
    my $ln=undef;
    unless ($classify)
    {
    while(<$fh_out>) {
	($ln=$1, last) if m/X-POPFile-Link:\s*(.*?)\s*$/;
    }
    # print STDERR "$r\nLink: $ln\n";
    }
    pop_release();
    close($fh_out);
    unlink($tmp_doc);
    unlink($tmp_out);
    return ($ln,$res);
}
sub slurp {
    local $/;
    open( my $fh, "<" . shift )
      or return "File ?";
    return <$fh>;
}

sub pdf_process {
    my $self = shift;
    my ( $fn, $op, $tmpdir, $outf ) = @_;
    my $ol = "";
    $spdf=PDF::API2->open($fn) || die "Failed open: $? *$fn*";
    $pdf=PDF::API2->new() || die "No new PDF $?";

    foreach ( split( /,/, $op ) ) {
	next if s/D$//;    # delete
	next unless s/^(\d+)([RUL]?)//;
	my $att=0;
	$att = "90"  if $2 eq "R";
	$att = "180" if $2 eq "U";
	$att = "270" if $2 eq "L";
	$pdf->importpage($spdf,$1,0);
	if ( $att ) {
		my $p=$pdf->openpage(0);
		$p->rotate($att);
	}
    }
    use Cwd 'abs_path';
    $pdf->saveas("$tmpdir/out.pdf");
}

sub get_cache {
    my ( $self, $item, $idx, $callback ) = @_;
    my $dh = $self->{"dh"};
    my $q  = $dh->selectrow_arrayref(
	"select data,date,type from cache where item=? and idx=?",
	undef, $item, $idx );

    my ($type,$data) = $callback->( $item, $idx, @$q[1] );
    return (@$q[2],@$q[0]) if @$q[0] && !$data;
    return ("text/text","ERROR") unless $data;

    my $ins_d = $dh->prepare(
	q{insert or replace into cache (date,item,idx,data,type) values(?,?,?,?,?)});
    my $date = time();
    $ins_d->bind_param( 1, $date, SQL_INTEGER );
    $ins_d->bind_param( 2, $item );
    $ins_d->bind_param( 3, $idx);
    $ins_d->bind_param( 4, $data, SQL_BLOB );
    $ins_d->bind_param( 5, $type);
    $ins_d->execute;
    return ($type,$data);
}

1;
