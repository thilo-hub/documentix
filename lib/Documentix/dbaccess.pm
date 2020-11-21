package dbaccess;
use Carp;
use XMLRPC::Lite;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
use File::Basename;
use Documentix::Cache;
use Documentix::Converter;
use Mojo::Asset;
use Documentix::Magic qw{magic};
use Documentix::ld_r;
use Date::Parse;
use Cwd 'abs_path';
use Digest::MD5 qw(md5 md5_hex md5_base64);


my $debug = 2;
my $ph;

my $cache;
my $error_file= Mojo::Asset::File->new(path => "../public/icon/Keys-icon.png") ;
my $error_pdf= Mojo::Asset::File->new(path => "../public/Error.pdf") ;
my $lcl;
sub new {
    my $class  = shift;
    my $dh = $Documentix::db::dh;

    print STDERR "New pdf conn: $dh\n" if $debug > 0;
    my $self = bless { dh => $dh, dbname => $d_name }, $class;

    $cache = Documentix::Cache->new();;
    my $q = "select cast(file as blob) file,value Mime from (select * from hash natural join metadata  where md5=? and tag='Mime') natural join file";
    $ph=$dh->prepare_cached($q);
    $lcl=$Documentix::config->{local_storage};

    return $self;
}


# Retp
# input either hash or idxY
# return mime-type and path
sub getFilePath {
    my ( $self,$hash,$type ) = @_;

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

	my ($name,$path) = fileparse($ra->{file});

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
	return Mojo::Asset::Memory->new()->add_chunk($res);
 }

 # Install file basis in DB and schedule indexing of it
 sub insert_file {
	 my ($self,$dgst,$ob,$tags)=@_;
	 my $type = magic($ob);
	 my $dh=$self->{dh};
	 my $add_file = $dh->prepare_cached(q{insert into file (md5,file,host) values(?,?,"ts2new")});
	 my $add_meta = $dh->prepare_cached(q{insert into metadata(idx,tag,value) values((select idx from hash where md5=?),?,?)});

	 # Create minimal DB entry such that it shows in view
	 $add_file->execute($dgst,$ob);
	 $add_meta->execute($dgst,"Mime",$type);
	 $add_meta->execute($dgst,"Content","ProCessIng");
	 $add_meta->execute($dgst,"mtime",0);
	 return Documentix::Task::Processor::schedule_loader($dgst,$ob,$tags);
}


 
 sub load_file {
	my ($self,$app,$asset,$name) = @_;
	my $root_dir = abs_path($Documentix::config->{root_dir});
	my $dh = $self->{"dh"};
   	 $name = "SomeFile" unless $name;
         #chec if local file 
         if ( $asset->size == 0 && ($name =~ /^$Documentix::config->{root_dir}/) && -r $name ) {
		$asset = Mojo::Asset::File->new(path => $name);
		$name =~ s|^$Documentix::config->{root_dir}/*||;
		print STDERR "Local file: $name\n";
	 }
	 my $md5 = Digest::MD5->new;
	 $dgst = $md5->add($asset->slurp)->hexdigest;

	 # Check db if content exist
	 my $add_hash = $dh->prepare_cached(q{insert or ignore into hash (md5) values(?)});
	 my $rv = $add_hash->execute($dgst);
	 my @taglist=split("/",lc($name));
	 $name=pop @taglist;  # remove basename
   $DB::single = 1;
	 if ( $rv == 0E0 ) {
		 # return know info
		 my $rv=item($self,$dgst);
		 $rv->[0]->{newtags} = \@taglist 
		 	if @taglist;

		 return "Known", @$rv ;
	 }
	 $name =~ s/%20/ /g; # 
	 $name =~ m|([^/]*)(\.[^\.]*)$|;
	 my $file = $1;
	 my $ext  = $2;
	 $dgst =~ /^(..)/;

	 # Locate storage place
	 my $ob=$Documentix::config->{local_storage}."/$1";
	 mkdir $ob unless -d $ob;
	 $ob .= "/$dgst";
	 mkdir $ob unless -d $ob;
	 my $wdir = $ob;
	 $ob .= "/$name";
	
	 # If file is in doc-area - do not copy it over
	 $asset->move_to($ob)
		 unless (abs_path($asset->path) =~ /^$root_dir/);

	 my $id = $self->insert_file($dgst,$asset->path,\@taglist);
	 return "Loading",{ md5 => $dgst,
		  doc => $file,
		  doct=> $ext,
		  tg  => 'processing',
		  pg  => '?',
		  tip => 'ProCessIng='. $id,
		  dt  => ld_r::pr_time(time()),
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
	warn "MD5: $md5";
	my $get=$dh->prepare_cached(qq{
	select  md5,
		group_concat(tagname) tg,
		coalesce(content,'ProCessIng') tip,
		pdfinfo,
		file doc,
		archive,
		idx
	from hash natural join file
		  natural outer left join tags natural outer left join tagname
		  natural outer left join m_content
		  natural outer left join m_pdfinfo
		  natural outer left join m_archive
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

		 $hash_ref->{dt} = ld_r::pr_time(str2time($1)) if  $hash_ref->{pdfinfo} =~ m|<td>ModDate</td><td>\s+(.*?)</td>|;
		 $hash_ref->{pg} =$1 if  $hash_ref->{pdfinfo} =~ m|<td>Pages</td><td>\s+(.*?)</td>|;
		 $hash_ref->{sz} =conv_size($1) if  $hash_ref->{pdfinfo} =~ m|<td>File size</td><td>\s+(\d+) bytes</td>|;
		 delete $hash_ref->{pdfinfo};

		 $hash_ref->{tg} = "processing" unless  $hash_ref->{tip} && $hash_ref->{tip} ne  "ProCessIng";
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



1;


1;
