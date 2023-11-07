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
use Documentix::db qw{dh};

my $dbversion = "6";

my $jobid=$$;
my $debug = 2;
my $ph;
use Sys::Hostname;
my $thisHost = hostname();

my $cache;
my $error_file= Mojo::Asset::File->new(path => "../public/icon/Keys-icon.png") ;
my $error_pdf= Mojo::Asset::File->new(path => "../public/Error.pdf") ;
my $lcl;
sub new {
    my $class  = shift;
    my $dh = dh();
    $thisHost = hostname();

    print STDERR "New pdf conn: $dh\n" if $debug > 0;
    my $self = bless { dh => $dh, dbname => $d_name }, $class;

    $cache = Documentix::Cache->new();;
    my $q = "select cast(file as text) file,value Mime from (select * from hash natural join metadata  where md5=? and tag='Mime') natural join file";
    $ph=$dh->prepare_cached($q);
    $lcl=$Documentix::config->{local_storage};
    # Check db version and run maintenance if (major) version is too small

    $dh->do(q{begin exclusive transaction});
    my $text=$dh->selectrow_hashref(q{select * from sqlite_schema where name='text'});
    if ( $Documentix::config->{tokenizer} && $text->{sql} !~ m/tokenize = '$Documentix::config->{tokenizer}'/) {
	    # tokenizer is changes... recreate...
	    $text->{sql} =~ s/tokenize\s*=\s*'[^']*'/tokenize = '$Documentix::config->{tokenizer}'/;
	    $dh->do(qq{drop table text});
	    $dh->do($text->{sql});
    }
    my $dbver = $dh->selectrow_hashref(q{select value from config where var = 'dbversion'});
    unless (defined($dbver->{value}) && $dbver->{value} >= $dbversion) {
	    $self->dbupgrade($dh,$dbver->{value});
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
	 my ($self,$dgst,$ob,$tags,$origFile)=@_;
	 my $type = magic($ob);
	 require doclib::pdfidx;
	 return undef unless pdfidx::mime_handler($type);
	 my $dh=$self->{dh};
	 my $add_file = $dh->prepare_cached(q{insert or ignore into file (md5,file,host) values(?,?,?)});
	 my $add_meta = $dh->prepare_cached(q{insert or ignore into metadata(idx,tag,value) values((select idx from hash where md5=?),?,?)});

	 # Create minimal DB entry such that it shows in view
	 $add_file->execute($dgst,$ob,$thisHost);
	 $add_meta->execute($dgst,"Mime",$type);
	 $add_meta->execute($dgst,"Content","ProCessIng=Loading...");
	 $add_meta->execute($dgst,"mtime",0);

	 $add_meta->execute($dgst,"Original",$origFile)
		if $origFile;
	 return Documentix::Task::Processor::schedule_loader($dgst,$ob,$tags);
}




# passed in name is used for tagging
# content  is in asset
sub load_asset {
	my ($self,$app,$asset,$name,$mtime,$ignoreTags) = @_;

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

         # Remove path component from tag list
	 $name =~ s/^\Q$ignoreTags\E\///
	 	if $ignoreTags;
	 #TODO: shall we mandate CamelCase for tasg ?
	 my $isUpdateOf = $2 if $name =~ s|(fileUpdate/)([0-9a-f]{32})/|$1|;
	 my @taglist=split("/",$name);
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

	 my $id = $self->insert_file($dgst,$asset->path,\@taglist,$isUpdateOf);
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
			 # next;
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

		 $hash_ref->{tg} = ($3?$3:"Working...") if !$hash_ref->{tg} =~ m|deleted| &&  $hash_ref->{tip} && $hash_ref->{tip} =~ s/^(ProCessIng)(=(.*))?$/$1/;
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
sub addqr {
	my ($self,$id,$md5) = @_;
	my $sel = $self->{dh}->prepare_cached(qq{ insert or replace into doclabel (doclabel,idx) select ?,idx from hash where md5=?});
	$sel->execute($id,$md5);
}
sub lkup {
	my ($self,$id) = @_;
	my $sel = $self->{dh}->prepare_cached(qq{ select * from doclabel natural join idxfile  where doclabel=cast( ? as text) limit 1});
        $sel->execute($id);
	my $res=undef;
        while( my $ra = $sel->fetchrow_hashref ) {
		$res = $ra;
	}
	return $res;
}

####################################

sub dbupgrade
{
    my $self = shift;
    my $dh=shift;
    my $oldversion = shift;
    require doclib::pdfidx;
    # First the pdftotext had a UTF-* bug
    # Re-do all pdftotext conversions
    print STDERR "Begin database migration...";
    $DB::single=1;

    
    if ( $oldversion < 2) {
	    my $ins =  $dh->prepare(q{update metadata set value=?3 where tag = ?2 and idx = cast(?1 as integer)});
	    my $getf = $dh->prepare(q{select idx,md5 hash,cast( file as blob) file   from hash natural join file
		order  by md5 });
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
    if ( $oldversion < 6) {
	my @ops = (
		# This should replaced by the sql init file
		# which is already non destructiv to exiting content
		qq{ drop TRIGGER if exists results_fill;},
		qq{ drop TRIGGER if exists new_search;},
		qq{ drop TRIGGER if exists cache_fetch;},
		qq{ drop TRIGGER if exists cache_fill;},
		qq{ drop TRIGGER if exists cache_new;},
		qq{ drop TRIGGER if exists cache_hit;},
		qq{ drop TRIGGER if exists cache_fill_h;},
		qq{ drop TRIGGER if exists cache_fill_t;},
		qq{ drop view if exists  cache_q_stat;},
		qq{ drop view if exists  mylog_cache_lst;},
		qq{ drop table if exists  cache_lst;},
		qq{ drop table if exists  cache_q;},
		## Update search to be trigger only
		#TODO: Cahnge search to use it
		qq{ CREATE TABLE cache_q ( qidx integer, idx integer, snippet text, rank float, primary key (qidx,idx));},
		qq{ CREATE TABLE if not exists cache_lst ( qidx integer primary key autoincrement,
					      query text unique, nresults integer, hits integer, last_used integer DEFAULT (unixepoch()));},
	        qq{ CREATE TRIGGER if not exists cache_del before delete on cache_lst begin delete from cache_q where cache_q.qidx = old.qidx ; end;
		},
			##  debug
		qq{ CREATE TABLE if not exists mylog (idx,md5,refcnt,time default CURRENT_TIMESTAMP);},
		qq{ create view if not exists mylog_cache_lst as
			select mylog.* from cache_lst join mylog on(idx='q'||qidx) order by mylog.rowid;
		},
			##  list actual cache contents
		qq{ create view cache_q_stat(qidx,hits,nresults) as select qidx,count(*),sum(iif(snippet is null,0,1)) from cache_q group by qidx; },
			## a) insert new search and request no results (NULL)
			## b) insert new search and request n results (n>=0)
			## c) update search and request n results (n>=0)

			##  Disable/enable logging for debugging by commenting the mylog
		qq{ CREATE TRIGGER cache_new after insert on cache_lst when new.nresults is not null begin
			insert into mylog(idx,md5,refcnt) values('q'||new.qidx,'cache_new: ' || new.nresults,0);
			update cache_lst set hits = -1  where qidx = new.qidx;
		end;},
		##  setting the hit to -1 rebuilds the matched document cache
		qq{ CREATE TRIGGER cache_hit  after update of hits on cache_lst when  not new.hits >= 0 begin
			insert into mylog(idx,md5) values('q'||new.qidx,'cache_hits '||ifnull(old.hits,"NULL")|| ' -> ' || new.hits);
			insert or replace into cache_q(qidx,idx,rank) select new.qidx,docid,rank from text where text match new.query;
			update cache_lst set hits=hit,nresults = -1  from (select nresults nr,hits hit from cache_q_stat where qidx=new.qidx) where new.qidx = qidx;
		end;
		},
		##  setting the nresults to -1 reloads previous number of results ( or initially loads the results)
		##  increasing  nresults fetches more snippets from documents
		qq{ CREATE TRIGGER cache_fill after update of nresults on cache_lst when new.nresults < 0 or (new.nresults > old.nresults and new.hits > old.nresults) begin
			insert into mylog(idx,md5) values('q'||new.qidx,'cache_fill: '||ifnull(old.nresults,"NULL")|| ' -> ' || new.nresults);
			update cache_q set snippet=snip2 from (
				select idx idx2,snippet(text,1,'<b>','</b>','...',5) snip2
				from (select qidx,idx from cache_q where qidx=new.qidx and snippet is null
							   order by rank
							   limit iif(new.nresults < 0,old.nresults,new.nresults-old.nresults))  join text on(docid=idx)
				where text match new.query
				) where qidx=new.qidx and idx2 = idx;
			update cache_lst set nresults=nr from (select nresults nr from cache_q_stat where qidx=new.qidx) where new.qidx = qidx;
		end;

		}

	);
	foreach(@ops) {
		print STDERR "EX: $_\n";
		 $self->{dh}->do($_);
	}
    }

    $self->dbmaintenance1();
    $dh->do(q{insert or replace into config (var,value) values("dbversion",?)},undef,$dbversion);
}

sub dbmaintenance1 {
	my ($self) = @_;
	my $snowball=1;
	my @ops = (
		#  Callers response... qq{begin exclusive transaction},

		qq{ DROP TABLE if exists text},
		qq{ DROP VIEW if exists vtext},
		qq{ DROP VIEW if exists m_text},
		qq{ DROP VIEW if exists joindocs },
		qq{ DROP TRIGGER if exists metadata_au},
		qq{ DROP TRIGGER if exists metadata_ad},
		qq{ DROP TRIGGER if exists metadata_ai},

		qq{ CREATE TRIGGER metadata_au AFTER UPDATE ON metadata when old.tag = 'Text' BEGIN
			INSERT INTO "text"("text", rowid, content) VALUES('delete', old.idx,old.value);
			INSERT INTO "text"(rowid,content) values(new.idx,new.value);
			END},
		qq{ CREATE TRIGGER metadata_ad AFTER DELETE ON metadata when old.tag = 'Text' BEGIN
			INSERT INTO "text"("text", rowid, content) VALUES('delete', old.idx,old.value);
			end},
		qq{ CREATE TRIGGER metadata_ai AFTER INSERT ON metadata when new.tag = 'Text' BEGIN
			INSERT INTO "text"(rowid,content) values(new.idx,new.value);
			insert into cache_q (qidx,idx,snippet,rank) 
				select qidx,docid,snippet(text,1,'<b>','</b>','...',6) snip,rank   
					from cache_lst,text where text match query and docid = new.idx; 
			end},

		qq{ CREATE VIEW m_text(docid,content)  as select idx ,value from metadata where tag = 'Text'},

	       ($snowball ?
		   qq{ CREATE VIRTUAL TABLE text using fts5(docid unindexed,content,  content='m_text', content_rowid='docid', tokenize = 'snowball german english')}
	       :
		   qq{ CREATE VIRTUAL TABLE text using fts5(docid unindexed,content,  content='m_text', content_rowid='docid', tokenize = 'porter')}
	       ),
		qq{ INSERT into text(text) values('rebuild')},
		qq{ DELETE from cache_lst},
		qq{ CREATE TABLE IF NOT EXISTS doclabel (idx INT, doclabel primary key unique)},

		#  Callers response... qq{commit}
	   );
	foreach(@ops) {
		print STDERR "EX: $_\n";
		 $self->{dh}->do($_);
	}
}



sub dbmaintenance
{
	my $self=shift;
	printf STDERR  "dbmaintenance\n";
	dh->do("begin exclusive transaction");
	dh->do(qq{insert into text(text) values('rebuild')});
	dh->do(qq{drop table if exists text_tmp});
	dh->do(q{delete from cache_lst});
	dh->do(q{delete from cache_q});
	dh->do(q{
		update config set value=max(idx) from hash where var="max_idx";
		});
	dh->do(q{commit });
	return "Done";
}


1;
