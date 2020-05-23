package dbaccess;
use Carp;
use XMLRPC::Lite;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
use File::Basename;
use MyApp::Docconf;
use doclib::cache;
use MyApp::Converter;
use Mojo::Asset;

use parent DBI;
use DBI qw(:sql_types);

my $debug = 2;
my $ph;

my $cache;
my $error_file= Mojo::Asset::File->new(path => "public/icon/Keys-icon.png") ;
my $error_pdf= Mojo::Asset::File->new(path => "public/Error.pdf") ;
sub new {
    my $class  = shift;

    my $dbn    = $Docconf::config->{database_provider};
    my $d_name = $Docconf::config->{database};
    my $user   = $Docconf::config->{database_user};
    my $pass   = $Docconf::config->{database_pass};

    my $dh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass )
      || die "Err database connection $!";
    print STDERR "New pdf conn: $dh\n" if $debug > 0;
    my $self = bless { dh => $dh, dbname => $d_name }, $class;
    #$self->set_debug(undef);
    #$self->{"setup_db"} = \&setup_db;
    #$self->{"dh1"}      = $dh;
    # trace_db($dh) if  $Docconf::config->{debug} > 3;
    # setup_db($self) unless $chldno;
    #$self->{"cache"}  
    $cache = cache->new();
    my $q = "select file,value Mime from (select * from hash natural join metadata  where md5=? and tag='Mime') natural join file";
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

    # my $q = "select file,value Mime from (select * from hash natural join metadata  where md5=? and tag='Mime') natural join file";
    # my $ph=$dh->prepare_cached($q);

    $ph->execute($hash);
    while( my $ra = $ph->fetchrow_hashref ) {
	next unless -r $ra->{"file"};
	$ph->finish();

	$ra->{"hash"} = $hash;
	return converter($type,$ra);
    }
    return $error_pdf;
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
	return   $error_file  unless $c;
	return   { file=>"icon/Keys-icon.png" } unless $c;
	return &$c($ra);
}
sub get_bestpdf
{
	my ($ra)=shift;
	
	croak "Wrong file-type: $ra->{Mime}" unless $ra->{Mime} =~ m|application/pdf|;

	my ($name,$path,$suffix) = fileparse($ra->{file},qw{ocr.pdf pdf});
	# search path
	foreach( $path.$name."ocr.pdf",$path.$name.$suffix ) {
		return Mojo::Asset::File->new(path => $_)  if -r $_;
	}
	return $error_pdf;
}
 sub get_icon{ 
	 my $ra=shift;
	 my ( $m, $res ) = $cache->get_cache( $ra->{"file"}, "$ra->{hash}-ico", \&Converter::mk_ico,$self );
	 
	 return Mojo::Asset::Memory->new()->add_chunk($res);
 }

1;
