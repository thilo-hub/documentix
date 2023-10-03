package dbaccess;
use Carp;
use XMLRPC::Lite;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
use File::Basename;
use Documentix::Cache;
use Documentix::Converter;
use Mojo::Asset::File;
use Documentix::Magic qw{magic};
use Documentix::ld_r;
use Date::Parse;
use Cwd 'abs_path';
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Encode qw{encode decode};

my $dbversion = "1";

my $jobid=$$;
my $debug = 2;
my $ph;

my $cache;
my $error_file= Mojo::Asset::File->new(path => "../public/icon/Keys-icon.png") ;
my $error_pdf= Mojo::Asset::File->new(path => "../public/Error.pdf") ;
my $lcl;
sub new {
    my $class  = shift;
    my $dh = Documentix::db::dh();

    print STDERR "New pdf conn: $dh\n" if $debug > 0;
    my $self = bless { dh => $dh, dbname => $d_name }, $class;

    $cache = Documentix::Cache->new();;
    my $q = "select cast(file as text) file,value Mime from (select * from hash natural join metadata  where md5=? and tag='Mime') natural join file";
    $ph=$dh->prepare_cached($q);
    $lcl=$Documentix::config->{local_storage};
    # Check db version and run maintenance if (major) version is too small

    $dh->do(q{begin exclusive transaction});
    my $dbver = $dh->selectrow_hashref(q{select value from config where var = 'dbversion'});
    unless (defined($dbver->{value}) && $dbver->{value} >= $dbversion) {
	    dbupgrade($dh);
	    $dh->do(q{insert or replace into config (var,value) values("dbversion",?)},undef,$dbversion);
    }
    $dh->do(q{commit});

    return $self;
}


# Retp
# input either hash or idxY
# return mime-type and path
sub getFilePath {
    my ( $self,$hash,$type ) = @_;

    # die "Bad init $$ - $jobid" unless $jobid == $$;

    my $dh = $self->{"dh"};
    die "Bad input"  unless $hash =~ m/^[0-9a-f]{32}$/;

    $ph->execute($hash);
    while( my $ra = $ph->fetchrow_hashref ) {
	next unless -r $ra->{"file"};
	$ph->finish();

	$ra->{"hash"} = $hash;
	return converter($type,$ra);
    }
    return undef;
}

#Only raw / pdf or icon is supported
sub converter
{
	my ($totype,$ra)=@_;
	my $cv = {
		"raw" => sub { return Mojo::Asset::File->new(path=>$ra->{"file"}) },
		"pdf" => \&get_bestpdf,
		"ico" => \&get_icon,
	};
	my $c=$cv->{$totype};
	return   undef  unless $c;
	return &$c($ra);
}

#
# Look for the best pdf file
# in a number of places
#
sub find_pdf
{
	my ($ra)=shift;
	
	#croak "Wrong file-type: $ra->{Mime}" unless $ra->{Mime} =~ m|application/pdf|;

	my ($name,$path) = fileparse($ra->{file},qw{.pdf .ocr.pdf});

	my $lcl=get_store($ra->{hash},0);
	# search path
	foreach $ext (qw{ .ocr.pdf .pdf },"") {
		foreach( $lcl.$name.$ext ,$path.$name.$ext ) {
			return $_ if -r $_;
		}
	}
	return undef;
}	
sub get_bestpdf
{
	my ($ra)=shift;
	my $pdf=find_pdf($ra);
	return undef unless $pdf;
	return Mojo::Asset::File->new(path => $pdf);
}

sub get_icon{
	 my $ra=shift;
	my $pdf=find_pdf($ra);
	return undef unless $pdf;
	$ra->{pdf}=$pdf;
	my ( $m, $res ) = $cache->get_cache( $ra->{file}, "$ra->{hash}-ico", \&Converter::mk_ico,$self,$ra );
	return Mojo::Asset::Memory->new()->add_chunk($res) if (length($res));
	return undef;
 }

 # Install file basis in DB and schedule indexing of it
 sub insert_file {
	 my ($self,$dgst,$ob,$tags)=@_;
	 my $type = magic($ob);
	 require doclib::pdfidx;
	 return undef unless pdfidx::mime_handler($type);
	 my $dh=$self->{dh};
	 my $add_file = $dh->prepare_cached(q{insert or ignore into file (md5,file,host) values(?,?,"ts2new")});
	 my $add_meta = $dh->prepare_cached(q{insert or ignore into metadata(idx,tag,value) values((select idx from hash where md5=?),?,?)});

	 # Create minimal DB entry such that it shows in view
	 $add_file->execute($dgst,$ob);
	 $add_meta->execute($dgst,"Mime",$type);
	 $add_meta->execute($dgst,"Content","ProCessIng=Loading...");
	 $add_meta->execute($dgst,"mtime",0);
	 return Documentix::Task::Processor::schedule_loader($dgst,$ob,$tags);
}




# passed in name is used for tagging
# content  is in asset
sub load_asset {
	my ($self,$app,$asset,$name,$mtime) = @_;

        $name = "Unknown" unless $name;
	my $root_dir = abs_path($Documentix::config->{root_dir});
	unless ( $asset ) {
		# create an asset
		# resolve potential dangers
		$name = abs_path($name);
		# name

		return unless -r $name; # give up
		$asset = Mojo::Asset::File->new(path => $name);

		return unless $name =~ s|^$root_dir/*||;  # Only inside OK
	}
	$name=decode("UTF-8",$name);
	my $dh = $self->{"dh"};


	print STDERR "New File: $name\n";

	 my $md5 = Digest::MD5->new;
	 $dgst = $md5->add($asset->slurp)->hexdigest;

	 # Check db if content exist
	 $dh->do("begin transaction");
	 my $add_hash = $dh->prepare_cached(q{insert or ignore into hash (md5) values(?)});
	 my $rv = $add_hash->execute($dgst);

	 #TODO: shall we mandate CamelCase for tasg ?
	 my @taglist=split("/",lc($name));
	 $name=pop @taglist;  # remove basename
$DB::single = 1;
	 if ( $rv == 0E0 ) {
		 # return know info
		 my $rv=item($self,$dgst);
		 $rv->[0]->{newtags} = \@taglist
		 	if @taglist;

		 $dh->do("commit");
		 return "Known", @$rv ;
	 }
	 $name =~ m|([^/]*)(\.[^\.]*)$|;
	 my $file = $1;
	 my $ext  = $2;

	 # Locate storage place
	 $dgst =~ /^(..)/;
	 my $ob=$Documentix::config->{local_storage}."/$1";
	 mkdir $ob unless -d $ob;
	 $ob .= "/$dgst";
	 mkdir $ob unless -d $ob;
	 my $wdir = $ob;
	 $ob .= "/$name";
	
	 # If file is in doc-area - do not copy it over
	 unless (abs_path($asset->path) =~ /^$root_dir/ ||
	         abs_path($asset->path) eq abs_path($ob)) {
		$asset->move_to($ob);
		utime($mtime,$mtime,$ob);
	}

	 my $id = $self->insert_file($dgst,$asset->path,\@taglist);
	 $dh->do("commit");
	 return "Loading",{ md5 => $dgst,
		  doc => $file,
		  doct=> $ext,
		  tg  => $id,
		  pg  => '?',
		  tip => 'ProCessIng="Reading"',
		  dt  => ld_r::pr_time($mtime),
		  sz  => conv_size($asset->size),
	  };
  }

sub conv_size
{

	my $s=shift;
	return sprintf("%.1f Gb",$s/2**30) if $s > 2**30;
	return sprintf("%.1f Mb",$s/2**20) if $s > 2**20;
	return sprintf("%.1f kb",$s/2**10);
}

sub item
{
	my ($self,$md5)=@_;
	my $dh = $self->{"dh"};
	my $get=$dh->prepare_cached(qq{
	select  md5,
		group_concat(tagname) tg,
		cast (coalesce(content,'ProCessIng') as text) tip ,
		pdfinfo,
		file doc,
		archive,
		mtime,
		idx
	from hash natural join file
		  natural outer left join tags natural outer left join tagname
		  natural outer left join m_content
		  natural outer left join m_pdfinfo
		  natural outer left join m_archive
		  natural outer left join mtime
	where
		md5=?
	limit 1
	});
	
	my @md5_l=($md5);
	my @res=();
	my %added;
	while( @md5_l ) {
		my $md5=shift @md5_l;
		next if $added{$md5}++;
		$get->execute($md5);

		my $hash_ref = $get->fetchall_hashref( "md5" );
		# use Data::Dumper; warn Dumper($hash_ref);
		$hash_ref=$hash_ref->{$md5};
		 if ($hash_ref->{archive})
		 {
			 push @md5_l,split(/,/,$hash_ref->{archive});
			 next;
		 }
		 delete $hash_ref->{archive};
		 $hash_ref->{doc} =~ s|^.*/([^/]*)(\.[^\.]+)$|$1|;
		 $hash_ref->{tg} = "" unless defined $hash_ref->{tg};
		 $hash_ref->{doct} = $2;
		 $hash_ref->{doc} =~ s|%20| |g;
		 #$hash_ref->{doc} = decode('UTF-8',$hash_ref->{doc});
		 #$hash_ref->{doc} = "---".$hash_ref->{doc};

		  $hash_ref->{dt}  = ld_r::pr_time($hash_ref->{mtime})
		  	if $hash_ref->{mtime};
		 delete $hash_ref->{mtime};
		 $hash_ref->{dt} = ld_r::pr_time(str2time($1)) if  $hash_ref->{pdfinfo} =~ m|<td>ModDate</td><td>\s+(.*?)</td>|;
		 $hash_ref->{pg} =$1 if  $hash_ref->{pdfinfo} =~ m|<td>Pages</td><td>\s+(.*?)</td>|;
		 $hash_ref->{sz} =conv_size($1) if  $hash_ref->{pdfinfo} =~ m|<td>File size</td><td>\s+(\d+) bytes</td>|;
		 delete $hash_ref->{pdfinfo};

		 $hash_ref->{tg} = ($3?$3:"Working...") if  $hash_ref->{tip} && $hash_ref->{tip} =~ s/^(ProCessIng)(=(.*))?$/$1/;
		 push @res,$hash_ref;
	 }
	 return \@res;
 }

sub get_store {
    my $digest=shift;
    my $md = shift || 0;
    my $wdir = $lcl;
    mkdir $wdir or die "No dir: $wdir" if $md && ! -d $wdir;
    $wdir  = abs_path($wdir);
    $digest =~ m/^(..)/;
    $wdir .= "/$1";
    mkdir $wdir or die "No dir: $wdir" if $md && ! -d $wdir;

    $wdir .= "/$digest";
    mkdir $wdir or die "No dir: $wdir" if $md && ! -d $wdir;
    return $wdir."/";
}

#
# Return zip archive having the taged files in it
# deleted files are only exported if the tag is "deleted"
#
sub export_files {
    my ( $self,$tag ) = @_;
    # For the moment just return the files tagged
    #  select 'mkdir -p "'||dir||'" ; cp "'||file||'" "'||dir||'/.";' 'export'
    my $exp_query = $self->{dh}->prepare_cached(qq{
		select file filename,dir zipName
		from (
			select idx,"ExportDocs/"||group_concat(tagname,"/") dir  from (
				select idx from tags where
					tagid = (select tagid from tagname where tagname = ?1 )
				) natural join tags natural join tagname
			group by idx order by tagname
		) natural join hash natural join file
	    });

    $exp_query->execute($tag);
    {
    my $zip=Archive::Zip->new;
    my @r=();
    while( my $ra = $exp_query->fetchrow_hashref ) {
	    next if ($ra->{dir} =~ m|/deleted/| && $tag ne "deleted");
	    my $oname =$ra->{filename};
	    $oname =~ s,^.*/,/,;
	    $ra->{zipName}.= $oname;
	    $zip->addFile($ra);
	    push @r,$ra;
    }
    $DB::single=1;
    my $asset = Mojo::Asset::File->new();
    unless ( $zip->writeToFileHandle($asset->handle,0) == AZ_OK ) {
             die "whoops!";
         }
    $asset->handle->flush;
    return $asset;
    }
}
sub dbupgrade
{
    my $dh=shift;
    require doclib::pdfidx;
    # First the pdftotext had a UTF-* bug
    # Re-do all pdftotext conversions
    $DB::single=1;
    my $ins =  $dh->prepare(q{update metadata set value=?3 where tag = ?2 and idx = cast(?1 as integer)});

    my $getf = $dh->prepare(q{select idx,md5 hash,cast( file as blob) file   from hash natural join file
	order  by md5});
    $getf->execute();
    print STDERR "Re convert pdftotext\n";
    my $pmd="";;
    while(($r=$getf->fetchrow_hashref) ){
	next if $r->{hash} eq $pmd;
	next unless -r $r->{file};
	$pmd=$r->{hash};
print STDERR $r->{file}."\n";
	my $pdf=find_pdf($r);
	next unless $pdf =~ /\.pdf$/;
	my $txt = pdfidx::do_pdftotext($pdf);
	my $c   = pdfidx::summary(\$txt);
	$ins->execute($r->{idx}+0,"Text",encode("UTF-8",$txt));
	$ins->execute($r->{idx}+0,"Content",encode("UTF-8",$c));
    }
}

sub addqr {
	my ($self,$id,$md5) = @_;
	my $sel = $self->{dh}->prepare_cached(qq{ insert or replace into doclabel (doclabel,idx) select ?,idx from hash where md5=?});
	$sel->execute($id,$md5);
}
sub lkup {
	my ($self,$id) = @_;
	my $sel = $self->{dh}->prepare_cached(qq{ select md5 from docid where doclabel=cast( ? as text) limit 1});
        $sel->execute($id);
	my $res="";
        while( my $ra = $sel->fetchrow_hashref ) {
		$res = $ra->{md5};
	}
	return $res;
}
sub dbmaintenance1 {
	my ($self) = @_;
	my $snowball=1;
	my @ops = (
		qq{begin exclusive transaction},
		qq{ drop table text},
		qq{ drop view vtext},
		qq{ drop TRIGGER metadata_au},
		qq{ drop TRIGGER metadata_ad},
		qq{ drop TRIGGER metadata_ai},
		qq{ CREATE TRIGGER metadata_au AFTER UPDATE ON metadata when old.tag = "Text" BEGIN
			INSERT INTO "text"("text", rowid, content) VALUES('delete', old.idx,old.value); 
			INSERT INTO "text"(rowid,content) values(new.idx,new.value); 
		END},
		qq{
		CREATE TRIGGER metadata_ad AFTER DELETE ON metadata when old.tag = "Text" BEGIN
			INSERT INTO "text"("text", rowid, content) VALUES('delete', old.idx,old.value);  
		end},
		qq{
		CREATE TRIGGER metadata_ai AFTER INSERT ON metadata when new.tag = "Text" BEGIN
			INSERT INTO "text"(rowid,content) values(new.idx,new.value); 
		end},
		qq{ CREATE VIEW 'vtext'(docid,content)  as select idx ,value from metadata where tag = 'Text'},
	   ($snowball ?
		   qq{ CREATE VIRTUAL TABLE text using fts5(docid,content,  content='vtext', content_rowid='docid', tokenize = 'snowball german english')}
	   :
		   qq{ CREATE VIRTUAL TABLE text using fts5(docid,content,  content='vtext', content_rowid='docid', tokenize = 'porter')}
	   ),
		qq{ insert into text(rowid,content) select * from vtext where content is not NULL},
		qq{ delete from cache_lst},
		qq{ CREATE TABLE IF NOT EXISTS doclabel (idx INT, doclabel primary key unique)},
		qq{ drop view joindocs },

		   qq{commit}
	   );
	foreach(@ops) {
		print STDERR "EX: $_\n";
		 $self->{dh}->do($_);
	}
}


1;
