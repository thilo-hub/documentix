package dbaccess;
use Carp;
use XMLRPC::Lite;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
use File::Basename;
use Documentix::Docconf;
use doclib::cache;
use Documentix::Converter;
use Mojo::Asset;
#use File::MimeInfo;
use File::MimeInfo::Magic;
use Documentix::ld_r;
use Date::Parse;


use parent DBI;
use DBI qw(:sql_types);

my $debug = 2;
my $ph;

my $cache;
my $error_file= Mojo::Asset::File->new(path => "../public/icon/Keys-icon.png") ;
my $error_pdf= Mojo::Asset::File->new(path => "../public/Error.pdf") ;
sub new {
    my $class  = shift;

    my $dbn    = $Docconf::config->{database_provider};
    my $d_name = $Docconf::config->{database};
    my $user   = $Docconf::config->{database_user};
    my $pass   = $Docconf::config->{database_pass};

    my $dh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass ,{sqlite_unicode => 1})
      || die "Err database connection $!";
    $dh->sqlite_busy_timeout(60000);
    if ( 0 ) {
        $dh->sqlite_enable_load_extension(1);
        $dh->sqlite_load_extension( "fts5stemmer.so" ) or die "Load extension failed";
    }
    $dh->do(q{pragma journal_mode=wal});

    print STDERR "New pdf conn: $dh\n" if $debug > 0;
    my $self = bless { dh => $dh, dbname => $d_name }, $class;
    #$self->set_debug(undef);
    #$self->{"setup_db"} = \&setup_db;
    #$self->{"dh1"}      = $dh;
    # trace_db($dh) if  $Docconf::config->{debug} > 3;
    # setup_db($self) unless $chldno;
    #$self->{"cache"}  
    $cache = cache->new();
    my $q = "select cast(file as blob) file,value Mime from (select * from hash natural join metadata  where md5=? and tag='Mime') natural join file";
    $ph=$dh->prepare_cached($q);
    return $self;
}


# Retp
# input either hash or idxY
# return mime-type and path
sub getFilePath {
    my ( $self,$hash,$type ) = @_;

    my $dh = $self->{"dh"};
    die "Bad input"  unless $hash =~ m/^[0-9a-f]{32}$/;

    # my $q = "select cast(file as blob) file,value Mime from (select * from hash natural join metadata  where md5=? and tag='Mime') natural join file";
    # my $ph=$dh->prepare_cached($q);

    $ph->execute($hash);
    while( my $ra = $ph->fetchrow_hashref ) {
	next unless -r $ra->{"file"};
	$ph->finish();

	$ra->{"hash"} = $hash;
	return converter($type,$ra);
    }
    return undef;
}
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
sub get_bestpdf
{
	my ($ra)=shift;
	
	#croak "Wrong file-type: $ra->{Mime}" unless $ra->{Mime} =~ m|application/pdf|;

	my ($name,$path,$suffix) = fileparse($ra->{file},qw{ocr.pdf pdf});
	# search path
	foreach( $path.$name.".ocr.pdf",$path.$name.$suffix ) {
		return Mojo::Asset::File->new(path => $_)  if -r $_;
	}
	return undef;
}
 sub get_icon{ 
	 my $ra=shift;
$DB::single = 1;
	 my ( $m, $res ) = $cache->get_cache( $ra->{"file"}, "$ra->{hash}-ico", \&Converter::mk_ico,$self );
	 
	 return Mojo::Asset::Memory->new()->add_chunk($res);
 }

 #return 
use Digest::MD5 qw(md5 md5_hex md5_base64);
 sub load_file {
	my ($self,$app,$asset,$name) = @_;
	my $dh = $self->{"dh"};
   $DB::single = 1;
	 my $md5 = Digest::MD5->new;
	 $dgst = $md5->add($asset->slurp)->hexdigest;

	 # Check db if content exist
	 my $add_hash = $dh->prepare_cached(q{insert or ignore into hash (md5) values(?)});
	 my $rv = $add_hash->execute($dgst);
	 if ( $rv == 0E0 ) {
		 # return know info
		 return "Known",item($self,$dgst);
	 }
	 $name =~ s/%20/ /g; # 
	 $name =~ m|([^/]*)(\.[^\.]*)$|;
	 my $file = $1;
	 my $ext  = $2;
	 $dgst =~ /^(..)/;

	 # Locate storage place
	 my $ob="uploads/$1";
	 mkdir $ob unless -d $ob;
	 $ob .= "/$dgst";
	 mkdir $ob unless -d $ob;
	 my $wdir = $ob;
	 $ob .= "/$name";
	 $asset->move_to($ob);
	 $fh= $asset->handle();
         my $type = mimetype($ob);
	 $add_file = $dh->prepare_cached(q{insert into file (md5,file,host) values(?,?,"ts2new")});
	 $add_file->execute($dgst,$ob);
	 my $id = $app->minion->enqueue(loader => [$dgst,$ob,$type,$wdir] => {priority => 5});


	 return "Loading",{ md5 => $dgst,
		  doc => $file,
		  doct=> $ext,
		  tg  => 'processing',
		  pg  => '?',
		  tip => 'processing='. $id,
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
		coalesce(content,'processing') tip,
		pdfinfo,
		file doc,
		idx
	from hash natural join file
		  natural outer left join tags natural outer left join tagname
		  natural outer left join m_content
		  natural outer left join m_pdfinfo
	where 
		md5=?
	limit 1
	});
	
	# my $get=$dh->prepare_cached(qq{ select md5,group_concat(tagname,",")  tg,content.value tip,file doc,pdfinfo,idx from fileinfo natural join metadata content natural join tags natural join tagname  where md5=? and content.tag = 'Content' limit 1});
	$get->execute($md5);
	my $hash_ref = $get->fetchall_hashref( "md5" );
	 use Data::Dumper; warn Dumper($hash_ref);
	$hash_ref=$hash_ref->{$md5};
	 $hash_ref->{doc} =~ s|^.*/([^/]*)(\.[^\.]+)$|$1|;
	 $hash_ref->{tg} = "";
	 $hash_ref->{doct} = $2;
	 $hash_ref->{doc} =~ s|%20| |g;

	 $hash_ref->{dt} = ld_r::pr_time(str2time($1)) if  $hash_ref->{pdfinfo} =~ m|<td>ModDate</td><td>\s+(.*?)</td>|;
	 $hash_ref->{pg} =$1 if  $hash_ref->{pdfinfo} =~ m|<td>Pages</td><td>\s+(.*?)</td>|;
	 $hash_ref->{sz} =conv_size($1) if  $hash_ref->{pdfinfo} =~ m|<td>File size</td><td>\s+(\d+) bytes</td>|;
	 delete $hash_ref->{pdfinfo};
	 return $hash_ref;
 }




1;
