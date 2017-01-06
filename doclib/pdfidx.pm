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
$File::Temp::KEEP_ALL = 1;
my $maxcpu= $Docconf::config->{number_ocr_threads};
my $mth   = $maxcpu > 1 ? 1 : 01;
my $debug=$Docconf::config->{debug};

my $tools = "/usr/pkg/bin";
$tools = "/home/thilo/documentix/tools" unless -d $tools;
    use Data::Dumper;

$tools = "/usr/bin" unless -d $tools;
$tools = "/usr/local/bin" unless -d $tools;
#$ENV{"PATH"}.= ":tools";

my $temp_dir="/var/tmp";
# Used tools
my $convert   = "convert";
my $lynx      = "lynx";
my $pdfimages = "pdfimages";
my $pdfinfo   = "pdfinfo";
my $pdfopt    = "pdfopt";
my $pdftoppm  = "pdftoppm";
my $pdftotext = "pdftotext";
my $pdftocairo = "pdftocairo";

# use threads;
# use threads::shared;

my $cleanup = 0;

my $db_con;

sub new {
    my $dbn    = $Docconf::config->{database_provider};
    my $d_name = $Docconf::config->{database};
    my $user   = $Docconf::config->{database_user};
    my $pass   = $Docconf::config->{database_pass};
    my $class  = shift;
    # return $db_con if $db_con;
    my $dh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass )
      || die "Err database connection $!";
    print STDERR "New pdf conn: $dh\n" if $main::debug>0;
    my $self = bless { dh => $dh, dbname => $d_name }, $class;
    $self->{"setup_db"} = \&setup_db;
    $self->{"dh1"} = $dh;
    setup_db($self);
    $db_con = $self;
    return $self;
}

sub dbname {
    my $self = shift;
    return $self->{"dbname"};
}
sub trace_db {
    my $dh=shift;
    open( TRC, ">>/tmp/db.trace" );

    sub trace_it {
        my $r = shift;

        print TRC "DB: $r\n";
    }

    $dh->sqlite_trace( \&trace_it );
}



sub setup_db {
    my $self = shift;
    my $dh   = $self->{"dh"};

    $dh->sqlite_busy_timeout(60000);
    my @slist = (
q{create table if not exists hash ( idx integer primary key autoincrement, md5 text unique )},
q{create table if not exists file ( md5 text primary key, file text unique)},
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

    my $q = "select file from file where md5=?";
    # print STDERR "$q : $md5\n";
    $dh->do("begin exclusive transaction");
    my $fn = $dh->selectcol_arrayref( $q, undef, $md5 );
    $dh->do("commit");
    foreach (@$fn) {
        # return the first readable
        return $_ if -r $_;
    }
    return $$fn[0];
}

sub get_metas {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ($fn) = @_;
    my $res  = $dh->selectall_hashref(
        "select tag,value from hash natural join metadata where md5=?",
        "tag", undef, $fn );
    return $res;
}

sub get_meta {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ( $typ, $fn ) = @_;
    $dh->do("begin exclusive transaction");
    my $idx = $dh->selectrow_array(
        "select value from hash natural join metadata where md5=? and tag = ?",
        undef, $fn, $typ
    );
    $dh->do("commit");
    return $idx;
}

sub pdf_info($$) {
    my $self = shift;
    my $fn   = shift;
    my $res  = qx{$pdfinfo \"$fn\"};
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
    while ( ( my $pn = scalar( keys(%childs) ) ) > $l ) {
        print STDERR "($pn) ";
        delete $childs{$pid} if ( ( ( $pid = wait ) ) > 0 );
        $err++ if $? != 0;
    }
    return $err;
}

sub ocrpdf {
    my $self = shift;
    my ( $inpdf, $outpdf, $ascii ) = @_;
    print STDERR "ocrpdf $inpdf $outpdf\n" if $debug >1;
    $inpdf=abs_path($inpdf);
    $outpdf=abs_path($outpdf);
    my $txt = undef;
    my $fail=0;

    my $tmpdir = File::Temp->newdir("/var/tmp/ocrpdf__XXXXXX");
    $fail += do_pdftocairo($inpdf,"$tmpdir/page");
    my @inpages=glob($tmpdir->dirname."/page*");

    foreach $in ( @inpages )
    {
	my $outpage=$tmpdir->dirname."/o-page-".$pg++;
	my $outim=$in.".jpg";
        if ( !$mth || ( $pid = fork() ) == 0 ) 
	{
            print STDERR "Conv $in\n";
	    $fail += do_convert_ocr($in,$outim);
	    $fail += do_tesseract($outim,$outpage);
	    unlink ($in,$outim) unless $debug>2;
            exit($fail) if $mth;
            $errs += $fail;
        }
        $childs{$pid}++;
        $errs += w_load($maxcpu);
	$outpage .= ".pdf";
	push @outpages,$outpage;
    }
    print STDERR "Wait..\n";
    $errs += w_load(0) if $mth;
    print STDERR "Done Errs:$errs\n";

    return undef unless @outpages;

    my @cpages;
    foreach(@outpages)
    {
	push @cpages,$_ if -f $_;
    }
    return undef unless @cpages;

    $fail += do_pdfunite($outpdf,@cpages);
    unlink(@outpages) unless $debug>2;

    my $tmp= "$tmpdir/out.pdf";
    symlink($outpdf,$tmp);
    my $txt=do_pdftotext("$tmp");
    unlink $tmp unless $debug >2;
    rmdir $tmpdir unless $debug>2;
    return $txt;
}


# Read input pdf and join the given html file

sub index_pdf {
    my $self = shift;
    my $dh   = $self->{"dh"};
    my $fn   = shift;
    my $wdir = shift;
    print STDERR "index_pdf $fn\n" if $debug >1;

    # make sure we skip already ocred docs
    $fn =~ s/\.ocr\.pdf$/\.pdf/;

    my $md5_f = file_md5_hex($fn);
    
    # Hack?
    # if a source document is not in a writable directory,
    # we should create a folder in "incomming/{md5}" and have a symbolic link
    # pointing to the source document.
    # the incomming, can then hold the OCR and whatever other stuff we need
    # HACK: I don't see a better way right now
    if ( $Docconf::config->{link_local} && !($fn =~ /$Docconf::config->{local_storage}/) )
    {
        my $f_dir=dirname($fn);
	my $new=$Docconf::config->{local_storage}."/".$md5_f;
	mkdir $new 
		unless -d $new;
	$new .= "/".basename($fn);
	symlink $fn,$new
		or die "Cannot link document... $!";
	$fn=$new;
	print STDERR "Doc linked -> $fn\n";
    }

    my ($idx) =
      $dh->selectrow_array( "select idx from hash where md5=?", undef, $md5_f );

    #return $idx if $idx;   # already indexed -- TODO:potentially check timestamp

    # $dh->do("begin exclusive transaction");
    $dh->prepare("insert or ignore into file (md5,file,host) values(?,?,?)")
      ->execute( $md5_f, $fn,hostname() );

    # $idx = $dh->last_insert_id( "", "", "", "" );
    my ($idx) = $dh->selectrow_array( "select idx from hash where md5=?", undef, $md5_f );
    print STDERR "Loading: ($idx) $fn\n";


    my %meta;
    $meta{"Docname"} = $fn;
    $meta{"Docname"} =~ s/^.*\///s;
    $self->{"file"}=$fn;
 die "Bad filename: $fn" if $fn =~ /'/;
    $self->{"idx"}=$idx;
    chomp(my $type=qx|file --dereference --brief  --mime-type  '$self->{file}'|);
    print STDERR "Type: $type\n";
    $meta{"Mime"} = $type;
    my %mime_handler=(
	    "application/x-gzip" => \&tp_gzip,
	    "application/pdf"    => \&tp_pdf,
	    "application/msword" => \&tp_any,
	    "application/vnd.openxmlformats-officedocument.presentationml.presentation" => \&tp_any,
	    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => \&tp_any,
	    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => \&tp_any,
	    "application/epub+zip" => \&tp_ebook,
	    "application/vnd.ms-powerpoint" => \&tp_any
	    );

    $meta{"mtime"}   = ( stat($fn) )[9];
    $meta{"hash"}    = $md5_f;
    $type =~ s/;.*//;
    $type = $mime_handler{$type}($self,\%meta)
	    while $mime_handler{$type};

    print STDERR " -> $type\n";



    $meta{"Image"}   = '<img src="?type=thumb&send=#hash#">';
    ( $meta{"PopFile"}, $meta{"Class"} ) =
      ( $self->pdf_class_file( $fn, \$meta{"Text"}, $meta{"hash"},undef ) );

    $meta{"keys"} = join( ' ', keys(%meta) );
# die Dumper(\%meta)." DEBUG";
    foreach ( keys %meta ) {
        $self->ins_e( $idx, $_, $meta{$_} );
    }
    #my $thumb = eval { $self->pdf_thumb($fn)};
    #my $ico   = eval { $self->pdf_icon($fn)};
    # $dh->do("commit");
    #$meta{"thumb"} = \$thumb;
    #$meta{"ico"}   = \$ico;
    return $idx, \%meta;

    sub tp_any
    {
	    my $self=shift;
	    my $meta=shift;
	    my $i = $self->{"file"};
	    # Output will generally be created in the local_storage (and kept)
            my $of=$Docconf::config->{local_storage}."/". $meta->{"hash"};
	    $self->{"file"} = $of."/".basename($i).".pdf";
	    do_unopdf($i,$self->{file});
	    my $type = do_file($self->{file});
	    return $type;
    }
    sub tp_ebook
    {
	    my $self=shift;
	    my $meta=shift;
	    my $i = $self->{"file"};
	    # Output will generally be created in the local_storage (and kept)
            my $of=$Docconf::config->{local_storage}."/". $meta->{"hash"};
	    $self->{"file"} = $of."/".basename($i).".pdf";
	    do_calibrepdf($i,$self->{file});
	    my $type = do_file($self->{file});
	    return $type;
    }
    sub tp_gzip
    {
	    my $self=shift;
	    my $i=$self->{"file"};
	    $self->{"fh"} = File::Temp->new(SUFFIX => '.pdf');
	    $self->{"file"} = $self->{"fh"}->filename;
	    do_ungzip($i,$self->{file});

	    my $type=do_file($self->{file});
	    return $type;
    }
    sub tp_pdf
    {
	my $self=shift;
	my $meta=shift;
	    my $t = $self->pdf_text( $self->{"file"}, $meta->{"md5"} );
	    if ($t) {
		$t =~ s/[ \t]+/ /g;
		$self->ins_e( $self->{"idx"}, "Text", $t );
		# short version
		$t =~ m/^\s*(([^\n]*\n){24}).*/s;
		my $c = $1 || "";
		$self->ins_e( $self->{"idx"}, "Content", $c );
		$meta->{"Text"}    = $t;
		$meta->{"Content"} = $c;
		$meta->{"pdfinfo"} = $self->pdf_info($fn);
	    }
      my $l=length($t) || "-FAILURE-";
      return "FINISH ($l)";
    }

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
}

sub pdf_totext {
    my $self = shift;
    my $fn   = shift;
    print STDERR " pdf_totext $fn\n" if $debug >1;

    $fn=abs_path($fn);
    $fn =~ s/\.ocr\.pdf$/.pdf/;
    my $ocrpdf=$fn;
    $ocrpdf =~ s/\.pdf$/.ocr.pdf/;
    die "No read: $fn" unless ( -r $fn || -r $ocrpdf );

    undef $ocrpdf if $ocrpdf eq $fn;
    if ( -r $ocrpdf )
    {
	$fn=$ocrpdf;
    }
    $txt = do_pdftotext($fn);
    return $txt if length($txt) > 100;
    return $txt if (-r $ocrpdf);

    return $self->ocrpdf($fn,$ocrpdf);
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

    my $dir=dirname($fn);
    
    $ofn =~ s/\.pdf$/.txt/;
    $ofn = tempname() unless -w $dir;

    return $self->pdf_totext($fn,$ofn);
}

sub pdf_thumb {
    my $self = shift;
    my $fn   = shift;
    my $pn   = ( shift || 1 ) - 1;
    $fn .= ".pdf" if (-f $fn.".pdf"); 
    my $png = do_convert_thumb($fn,$pn);
    return undef unless length($png);
    return ( "image/png", $png );
}

sub pdf_icon {
    my $self = shift;
    my $fn   = shift ;
    my $pn   = ( shift || 1 ) - 1;
    my $rot  = shift;
    my $tmp= tmpnam();

    $fn .= ".pdf" if (-f $fn.".pdf"); 
    my $png = do_convert_icon($fn,$pn);
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
	$rv=$self->pdf_class_file($r->{"file"},\$r->{"txt"},$r->{"md5"},undef);
	$l=length($r->{"txt"});
        print STDERR "Tx: $r->{idx} $r->{md5} ($l)  -> $rv\n";
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
	my $rv = $self->pop_call('classify',$tmp_doc);
	unlink $tmp_doc;
	next if ($r->{lst} eq $rv);
	
        print STDERR "Tx: $r->{idx} $r->{lst}   -> $rv\n";
    }
}
sub set_classes {
    my $self = shift;
    my $all_t =
    q{select tagname,group_concat(substr(value,1,10000)) txt  from tagname natural join tags natural join metadata where tag="Text"  group by tagname};

   # delete all buckets first ....
   my $rv=$self->pop_call( 'get_buckets');
   print STDERR "cln: $tg -> $rv\n";

    foreach (@$rv) {
	$rv=$self->pop_call('delete_bucket', $_);
	print STDERR "Del: $_ ->$rv\n";
    }
    my $all_s = $self->{"dh"}->prepare($all_t);
    $all_s->execute;
    while ( my $r = $all_s->fetchrow_hashref() ) {
        my @res = $self->set_class_content(lc($r->{"tagname"}),\$r->{"txt"});
    }
}
sub set_class_content
{
  my $self=shift;
   my ($tg,$rtxt) =@_;
   $rv=$self->pop_call( 'create_bucket', to_bucketname($tg));
   print STDERR "TG: $tg -> $rv\n";
    my ( $fh, $tmp_doc ) = tempfile(
	'popfileinXXXXXXX',
	SUFFIX => ".msg",
	UNLINK => 1,
	DIR    => $temp_dir
    );
    print $fh $$rtxt;
    close($fh);
    print STDERR " Add: $tg ($ln) -> ";
    $rv=$self->pop_call( 'add_message_to_bucket', to_bucketname($tg), $tmp_doc);
    my $ln=length($$rtxt);
    print STDERR "$rv\n";
    unlink($tmp_doc);
}
   

{
    my $pop_xml;

    $pop_xml = "http://localhost:".
		qx{awk '/xmlrpc_port/{printf "%s",\$2}' popuser/popfile.cfg}.
		"/RPC2";
	    #$pop_xml = "http://localhost:8180/RPC2";
    my $pop_cnt=0;

    sub pop_call {
       my $self=shift;
       my $op=shift;
       my $sk=$self->pop_session();
	my $r=XMLRPC::Lite->proxy($pop_xml)
	  ->call( "POPFile/API.$op",$sk,@_ );
	return  $r ->result;
    }

    sub pop_session {
        my $self=shift;
        return $self->{"sk"} if $self->{"sk"};
        $self->{"sk"} =
          XMLRPC::Lite->proxy($pop_xml)
          ->call( 'POPFile/API.get_session_key', 'admin', '' )->result;
print STDERR "POP Session: $self->{sk}\n";
	# Check buckets in popfile
        # ensure that at least a single bucket other than unclassified is available
        my $bucket_list=$self->pop_call('get_buckets');
	$self->pop_call('create_bucket', 'default')
		unless(scalar(@$bucket_list));
        return $self->{"sk"};
    }
    sub to_bucketname
    {
	my $bn=lc(shift);
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
	my ( $fn,$md5,$rtxt ) = @_;
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

    print "T:$md5, $tx" if ($debug >2);
    close($fh);
    return $tmp_doc;
}
sub db_prep {
	my ($self,$name,$sql)=@_;
	$self->{$name}=$self->{"dh"}->prepare($sql)
		unless $self->{$name};
	return $self->{$name};
    }

sub pdf_class_md5
{
    my $self = shift;
    my $md5  = shift;
    my $class= shift;  # undef returns class else set class
    my $gt_info=$self->db_prep("get_info",
                q{ select file,substr(value,1,10000) txt from hash natural join file natural join metadata where md5=? and tag="Text"});

    my $r  = $self->{"dh"}->selectrow_hashref($gt_info,undef,$md5);
    return $self->pdf_class_file($r->{"file"},\$r->{"txt"},$md5,$class);
    
}
sub pdf_class_file {
    my $self = shift;
    my $fn   = shift;  #optional file-name
    my $rtxt = shift;  # text to classify
    my $md5  = shift;
    my $class= shift;  # undef returns class else set class

    my $rv;
    my $ln;
   
    my $tmp_doc = get_popfile_r( $fn,$md5,$rtxt);
    my $op="handle_message";
    my $dbop = "insert into tags (idx,tagid) 
		       select idx,tagid from hash,tagname where md5=? and tagname =?";
    my $db_op=$self->db_prep("add_tag",$dbop);

    if ( $class && $class =~ s/^-// )
    {
	$rv=$self->pop_call("remove_message_from_bucket",$class,$tmp_doc);
	my $dbop = "delete from tags where idx=(select idx from hash where md5=?) and 
				 tagid = (select tagid from tagname where tagname = ?)";
	$db_op=$self->db_prep("rm_tag",$dbop);
    } elsif ($class) 
    {
	# Set&create  specific class
	my $b=to_bucketname($class);
	$rv=$self->pop_call("create_bucket",$b);

	$rv=$self->pop_call("add_message_to_bucket",$b,$tmp_doc);

	my $dbop = "insert or ignore into tagname (tagname) values(?)";
	$self->db_prep("add_class",$dbop)->execute($class);
    } else 
    {
	# ask for class
	my ( $fh_out, $tmp_out ) = tempfile(
	    'popfileinXXXXXXX',
	    SUFFIX => ".out",
	    UNLINK => 1,
	    DIR    => $temp_dir
	);
	$rv=$self->pop_call('handle_message',$tmp_doc,$tmp_out);
	$class=$rv;
	die "Ups: $class" unless $class;
        while (<$fh_out>) {
            ( $ln = $1, last ) if m/X-POPFile-Link:\s*(.*?)\s*$/;
        }

         print STDERR "$r\nLink: $ln\n";
	close($rh_out);
	unlink($tmp_out);
	
	my $dbop = "insert or ignore into tagname (tagname) values(?)";
	$self->db_prep("add_class",$dbop)->execute($class);
	
    }
    close($fh_out);
    $db_op->execute($md5,$class);
    unlink($tmp_doc);
    printf STDERR "Class: $rv\n";

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
sub do_convert_ocr
{
	my ($in,$outim)=@_;
	    @cmd=(qw{convert -density 150 }, $in , qw {-trim -quality 70 -flatten -sharpen 0x1.0},$outim);
	    $msg .= "CMD: ".join(" ",@cmd,"\n");
            $fail += ( system( @cmd) ? 1 : 0);
	return $fail;
}
sub do_convert_thumb
{
    my ($fn,$pn)=@_;
    $fn .= "[$pn]";
    my @cmd = ( $convert, "'$fn'", qw{-trim -normalize -thumbnail 400 png:-} );
    print STDERR "X:" . join( " ", @cmd ) . "\n";
    my $png = qx{@cmd};
    return $png;
}
sub do_convert_icon
{
  my ($fn,$pn)=@_;
    my $tmpdir = File::Temp->newdir("/var/tmp/ocrpdf__XXXXXX");
    # my @cmd = ( $convert, "'${fn}[$pn]'", qw{-trim -normalize -thumbnail 100} );
    my $out=$tmpdir."/out";
    my @cmd = ( $pdftocairo, qw{-scale-to  100 -jpeg -singlefile -f },$pn,"-l",$pn,"'$fn'" , $out);
    # push @cmd, "-rotate", $rot if $rot;
    # push @cmd, "png:-";
    print STDERR "X:" . join( " ", @cmd ) . "\n";
    my $png = qx{@cmd};
    $out .= ".jpg" if -r $out.".jpg";
    print STDERR "L:" .length($png) . "\n" if $main::debug>1;
    $out="icon/noimg.jpg" unless -f $out;
    die "Failed cairo... " unless -f $out;
    $png = slurp($out);
    unlink ($out);
    rmdir($tmpdir);
    return $png;
}
#convert single pdf-page to ocr-pdfpage
sub do_tesseract
{
     my ($image,$outpage)=@_;
     my $msg;
	    @cmd = ($tesseract,  $image,$outpage, qw{ -l deu+eng+equ -psm 1 pdf});
	    $msg .= "CMD: ".join(" ",@cmd,"\n");
	    print STDERR "$msg";
	    $outpage .= ".pdf";
            $fail += ( system( @cmd) ? 1 : 0) unless -f $outpage;
	    print STDERR "Done $outpage\n";
	return $fail;
}

#split pdf into separate jpgs ($page) prefix
sub do_pdftocairo
{
    my ($inpdf,$pages)=@_;

    my $tmpdir = File::Temp->newdir("/var/tmp/ocrpdf__XXXXXX");
    symlink ($inpdf,"$tmpdir/in.pdf");
    my @cmd=(qw{pdftocairo -r 300 -jpeg}, "$tmpdir/in.pdf",$pages);
    print STDERR "CMD: ".join(" ",@cmd,"\n");
    my $fail += ( system( @cmd) ? 1 : 0);
    unlink("$tmpdir/in.pdf");
    rmdir($tmpdir) or die "DIr: $!";
    return $fail;
}
sub do_pdfunite
{
    my ($outpdf,@cpages)=@_;
    @cmd = (qw{ pdfunite }, @cpages, $outpdf); 
    #pdfunite croaks if only a single page is united
    @cmd = (qw{ cp },@cpages,$outpdf)
	if ( scalar(@cpages) == 1 );
    print STDERR "CMD: ".join(" ",@cmd,"\n");
    $fail += ( system( @cmd) ? 1 : 0) unless -f $outpdf;
    # die "Failure generating $outpdf" unless -f $outpdf;
return $fail
}
sub do_pdftotext
{
    my ($tmp)=@_;
    # symlink($outpdf,$tmp);
    @cmd=($pdftotext,$tmp,"-");
    
    print STDERR "CMD: ".join(" ",@cmd,"\n");
    my $txt=qx( @cmd );
return $txt;
}
sub do_calibrepdf
{
  my ($in,$out)=@_;
	    $in = abs_path($in);
	    $out = abs_path($out);
	    print STDERR "convert: $in\n";
	    main::lock();
	    qx|ebook-convert "$in" "$out"|;
	    main::unlock();
	    die "failed: calibre: ebook-convert $in $out" unless -f $out;
return
}
sub do_unopdf
{
  my ($in,$out)=@_;
	    $in = abs_path($in);
	    $out = abs_path($out);
	    print STDERR "convert: $in\n";
	    main::lock();
	    qx|unoconv -o "$out" "$in"|;
	    main::unlock();
	    die "failed: -o $out $in" unless -f $out;
return
}

sub do_file
{
  my ($in)=@_;
	    chomp(my $type=qx|file -b --mime-type "$in"|);
  return $type;
}
sub do_ungzip
{
  my ($in,$out)=@_;
  qx|gzip -dc $i > "$out"|;
  return;
}
sub do_pdftotext
{
   my ($in)=@_;
    my $tmp= tmpnam().".pdf";
    symlink($in,$tmp);
    @cmd=($pdftotext,$tmp,"-");
    my $txt=qx( @cmd );
    unlink $tmp unless $debug >2;
return $txt;
}

1;
