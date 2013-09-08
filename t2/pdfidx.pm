package pdfidx;
use XMLRPC::Lite;


use parent DBI;
use DBI qw(:sql_types);
# use threads;
# use threads::shared;

my $get_f;

sub new {
my $dbn="SQLite";
my $d_name="/var/db/pdf/doc_db.db";
my $user="";
my $pass="";
    my $class = shift;
    my $dh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass )
      || die "Err database connection $!";

    $dh->{"setup_db"} = \&setup_db;
    my $self = bless { dh => $dh }, $class;
    setup_db($self);
    $get_f=$dh->prepare("select idx,md5 from file natural join hash  where file=?");
    return $self;
    }
sub setup_db
{
    my $self = shift;
    my $dh   = $self->{"dh"};

    $dh->do(q{create table if not exists hash ( idx integer primary key autoincrement, md5 text unique )});
    $dh->do(q{create table if not exists file ( md5 text primary key, file text unique)});
    $dh->do(q{create table if not exists data ( idx integer primary key , 
	     thumb text, ico text, html text) });
    $dh->do(q{create table if not exists ocr ( idx integer, text text)});
    $dh->do(q{create table if not exists metadata ( idx integer, tag text, value text, unique ( idx,tag) )});
    $dh->do(q{create table if not exists cache (item text,idx integer,data blob,date integer,
		unique (item,idx)
	)});

}



sub tfun
{
    my $self = shift;
    my $md5   = shift;
    my $dh   = $self->{"dh"};
    my $meta;

    $meta->{"IDS"}= $dh->selectcol_arrayref(q{select md5 from metadata natural join hash where tag="mtime" and value > ?},undef,time()-4*24*3600);
	
    $meta->{"list"}="Hello {Docname}\n";
    my $tpl=slurp("-");


    my %ref;
    my $idx="0000";
    while( $tpl =~ s/{\*([A-Z0-9a-z]+)}(.*?){\*}/RPT>$2</s)
    {
	    $ref{"XX_$1"}=$2;
    }
    # while( $tpl =~ s/{([A-Z0-9_a-z]*)([^{}]*)}/$n="${idx}_$1"; $ref{$n}=$2;$idx++; "#$n#"/gse ) {}
    $ref{"tpl"}=$tpl;
    return \%ref;




    $meta->{"out"}=expand_templ($dh,$tpl,\$meta,$md5);
    return $meta;
}
sub get_file
{
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ($md5)=@_;
    return $md5 unless $md5 =~ m/^[0-9a-f]{32}$/;
    my $fn=$dh->selectrow_array("select file from file where md5=?",undef,$md5);
    return $fn;
}
sub get_meta
{
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ($typ,$fn)=@_;
    my $idx=$dh->selectrow_array("select value from hash natural join metadata where md5=? and tag = ?",undef,$fn,$typ);
    return $idx;
}
sub get_cont
{
    my $self = shift;
    my $dh   = $self->{"dh"};
    my ($typ,$fn)=@_;
    my $idx=$dh->selectrow_array("select idx from hash where md5=?",undef,$fn);
    return unless $idx;
    my $gt=$dh->prepare("select $typ from data where idx=?");
    my $res=$dh->selectrow_array($gt,undef,$idx);

    return $res;

}
sub pdf_info($)
{
       my $fn=shift;
       my $res=qx{pdfinfo \"$fn\"};
       $res =~ s|:\s|</td><td>|mg;
       $res =~ s|\n|</td></tr>\n<tr><td>|gs;
       $res =~ s|^(.*)$|<table><tr><td>$1</td></tr></table>|s;
       return $res;
}
sub expand_templ
{
   my $dh=shift;
    my $tpl=shift;
    my $meta=shift;
    my $md5=shift;
   sub get_content
   {
	   my $db=shift;
	   my $var=shift;
	   my $md5=shift;
	   print STDERR "Expand: $var / $md5\n";

	   if ( $md5 && ! $$db->{$md5} )
	   {
		   print STDERR "Fetch: $md5\n";
		   my $res=$dh->selectall_hashref(
			       q{select idx,tag,value from file 
				natural join hash natural join metadata 
				    where md5=?},"tag",undef,$md5);
		   $$db->{$md5}->{$_}=$res->{$_}->{"value"} 
		   	foreach(keys %$res);
			$$db->{$md5}->{"KEYS"}=
				join(' ',keys ($$db->{$md5}));
	   }
	   warn "R:$res: M:$md5:".ref($res);
	   my $res = $$db->{$md5};
	   if ( ref($res) eq "ARRAY" )
	   {
		   my $out="";
		   my $exp=$$db->{$var};
		   warn "$exp";
		   foreach(@$res)
		   {
			   my $t=$exp;
			   $t =~ s/{(.*?)}/{$1_$_}/g;
			   $out .= $t;
		   }
		   $res=$out;
		   return $res;
	   }
	   if ( ref($res) == "HASH" )
	   {
		   $res=$res->{$var};
	   }
	   return $res unless ref($res);
	   die "R:$res:".ref($res);
	   $res=$$db->{$var} unless $res;
	   return "{ $var }" ;
   }
   while($tpl =~ s/{([a-zA-Z0-9]+)(_([a-zA-Z0-9]+))?}/get_content($meta,$1,$3)/ges )
   	{}
   return $tpl;
}

sub index_pdf
{
    my $self = shift;
    my $dh   = $self->{"dh"};
    my $fn=shift;


    my $md5_f=qx{md5 -n \"$fn\"};
    $md5_f =~ s/\s.*$//s;
    $dh->prepare("insert or replace into file (md5,file) values(?,?)")
       ->execute($md5_f,$fn);

    my ($idx)=$dh->selectrow_array("select idx from hash where md5=?",undef,$md5_f);

    return if $idx;
    print STDERR "Loading: $fn\n";
    $dh->do("begin transaction");
    $dh->prepare("insert into hash(md5) values(?)")
        ->execute($md5_f);

    $idx=$dh->last_insert_id("","","","");

    my $thumb=pdf_thumb($fn);
    my $ico=pdf_icon($fn);
    my $ins_d=$dh->prepare("insert into data (idx,thumb,ico) values(?,?,?)");
    $ins_d->bind_param(1, $idx, SQL_INTEGER);
    $ins_d->bind_param(2, $thumb, SQL_BLOB);
    $ins_d->bind_param(3, $ico, SQL_BLOB);
    $ins_d->execute();
    my %meta;
    $meta{"Docname"}=$fn;;
    $meta{"Docname"}=~ s/^.*\///s;
    $meta{"Text"}=pdf_text($fn,$md5_f);
    $meta{"Text"}=~  m/^\s*(([^\n]*\n){24}).*/s;
    $meta{"Content"}=$1;
    $meta{"mtime"}=(stat($fn))[9];
    $meta{"hash"}=$md5_f;
    $meta{"pdfinfo"}=pdf_info($fn);
    $meta{"Image"}='<img src="?type=thumb&send=#hash#">';
    $meta{"Class"}=pdf_class($fn,$meta{"Text"},$meta{"hash"});

    $meta{"keys"}=join(' ',keys(%meta));
    foreach( keys %meta )
    {
	$dh->prepare(q{insert or replace into metadata (idx,tag,value) 
		    values(?,?,?)}) ->execute($idx,$_,$meta{$_});
    }

    # load and fill file-template
    my $tpl=slurp("/home/thilo/public_html/fl/t2/templ_doc.html");
    #my $tpl=slurp("template_pdf.html");
    $tpl=expand_templ($dh,$tpl,\%meta);
    $tpl = sprintf "Content-Type: text/html; charset=utf-8\nContent-Length: %d\n\n%s",length($tpl), $tpl;
    $dh->prepare(q{update data set html=? where idx=? })
	   ->execute($tpl,$idx);
    $dh->do("commit");
}

sub pdf_text
{ 
    my $fn=shift;
    my $md5=shift;
    my $txt;
    # return "--not--available--";
    # split pdf into page
    my $ofn=$fn;
    $ofn =~ s/\.pdf$/.txt/;
    return slurp($ofn) if ( -f $ofn );

    my $ocr_db='/home/thilo/public_html/fl/t2/ocr.db';
    if ( -f $ocr_db )
    {
	    my $dh = DBI->connect( "dbi:SQLite:$ocr_db", undef,undef)
	      || die "Err database connection $!";
	    $txt=$dh->selectrow_array("select text from ocr where md5=?",undef,$md5);
	    return $txt if $txt;
    }
    $txt = qx/pdftotext \"$fn\" -/;
    undef $txt if length($txt) < 100;
    return $txt if $txt;
    mkdir("/tmp/pages_$$") or die "Bad temp-dir";
    system("pdftoppm -r 300 -gray \"$fn\" \"/tmp/pages_$$/page-\"");
    foreach( glob("/tmp/pages_$$/page-*") )
    {
	print STDERR "P: $_\n";
	system("convert -trim \"$_\" \"$_\".tif");
	system("tesseract -l deu+eng \"$_.tif\"  \"$_\" ");
	$txt .= slurp("$_.txt");
    }
    system("mv /tmp/pages_$$ /tmp/delme.$$ && rm -rf /tmp/delme.$$&");
    return $txt;
}
sub pdf_thumb
{ 
    my $fn=shift;
    my $cmd=" pdftoppm -png  -singlefile  -scale-to 400 \"$fn\" | "
    	     . "convert -trim -contrast - png:- ";
    my $png = qx{ pdftoppm -png  -singlefile  -scale-to 400 \"$fn\" | 
    		   convert -trim -contrast - png:- };
    open(F,">/tmp/t.png"); print F $png; close F;
    return sprintf "Content-Type: image/png\nContent-Length: %d\n\n%s",length($png), $png;
    return $png;
}
sub pdf_icon
{ 
    my $fn=shift;
    my $ico =  qx{convert -contrast -thumbnail 200x100 \"$fn\" png:-};
    open(F,">/tmp/i.png"); print F $ico; close F;
    return sprintf "Content-Type: image/png\nContent-Length: %d\n\n%s",length($ico), $ico;
    return $ico;
}
sub pdf_class
{ 
    my $fn=shift;
    my $txt=shift;
    my $md5=shift;
my $sk = XMLRPC::Lite ->proxy('http://localhost:8081/RPC2')
	-> call('POPFile/API.get_session_key','admin', '')
	-> result;
   my $tmp_doc="/tmp/$$.txt";
	open (my $fh,">$tmp_doc");
	my $f=$fn;
	$f =~ s/^.*\///;
	print $fh "Subject:  $f\n";
	print $fh "From:  Docusys\n";
	print $fh "To:  Filesystem\n";
	print $fh "File:  $fn\n";
	print $fh "Message-ID: $md5\n";
	print $fh "\n";
	print $fh "$xinfo";
	# print $fh "$p\n";
	print $fh $txt;
	# print "T:$tf:$msg\n";
	close($fh);

my $res=XMLRPC::Lite ->proxy('http://localhost:8081/RPC2')
	-> call('POPFile/API.classify',$sk,$tmp_doc)
	-> result;

	XMLRPC::Lite ->proxy('http://localhost:8081/RPC2')
	    -> call('POPFile/API.release_session_key',$sk);
    return $res;
    }
sub slurp { local $/; open(my $fh,"<".shift) or return "File ?";  return <$fh> }
sub pdf_process
{
	my $self=shift;
	my ($fn,$op,$tmpdir,$outf)=@_;
	my $texfn="file.tex";

	my $tex=q{
	\batchmode
	\documentclass[a4paper,]{article}
	\usepackage[utf8]{inputenc}
	\usepackage{pdfpages}

	\begin{document}
	%PAGES%
	\end{document}
	};

	my $ol="";
	foreach(split(/,/,$op))
	{
	  next if s/D$// ; # delete
	  next unless /\d/;
	  my $att;
	  $att="angle=90" if s/R$//;
	  $att="angle=180" if s/U$//;
	  $att="angle=270" if s/L$//;
	  $top .= "\\includepdfmerge[$att]{in.pdf,$_}\n";
	}
	$tex =~ s/%PAGES%/$top/;
	unlink("$tmpdir/$texfn") if -f "$tmpdir/$texfn";
	open(F,">$tmpdir/$texfn")  or die "Cannot open: $tmpdir/$texfn" ;
	print F $tex;
	close(F);

	 use Cwd 'abs_path';
         my $pdf_fmt = abs_path("pdflatex.fmt");

	unlink("$tmpdir/in.pdf") if -f "$tmpdir/in.pdf";
	symlink $fn,"$tmpdir/in.pdf" or die "Failed symln: $fn $tmpdir/in.pdf: $!";
	system("cd $tmpdir; /usr/pkg/bin/pdflatex -fmt=$pdf_fmt $texfn >&2");
	unlink("$tmpdir/out.pdf") if -f "$tmpdir/out.pdf";
	rename("$tmpdir/file.pdf","$tmpdir/out.pdf");

#	copy($pdftmp,"$outf") or die "Copy failed: $!";
}
sub get_cache
{
	my ($self,$item,$idx,$callback)=@_;
	my $dh   = $self->{"dh"};
	my $q=$dh->selectrow_arrayref("select data,date from cache where item=? and idx=?",
					undef,$item,$idx);

	my $data=$callback->($item,$idx,@$q[1]);
	return @$q[0] if @$q[0]  && !$data ;
	return "Content-Type: text/text\n\nERROR\n" unless $data;

	my $ins_d=$dh->prepare(q{insert or replace into cache (date,item,idx,data) values(?,?,?,?)});
	my $date=time();
	$ins_d->bind_param(1, $date, SQL_INTEGER);
	$ins_d->bind_param(2, $item);
	$ins_d->bind_param(3, $idx, SQL_INTEGER);
	$ins_d->bind_param(4, $data, SQL_BLOB);
	$ins_d->execute;
	return $data;
}


		1;
