package dbaccess;
use XMLRPC::Lite;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
use File::Basename;
use MyApp::Docconf;

use parent DBI;
use DBI qw(:sql_types);

my $debug = 2;


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
    return $self;
}


# Retp
# input either hash or idxY
# return mime-type and path
sub getFilePath {
	my ( $self,$hash,$type ) = @_;

    my $dh    = $self->{"dh"};
    die "Bad input"  unless $hash =~ m/^[0-9a-f]{32}$/;

    my $q = "select file,value Mime from file natural join hash natural join metadata  where md5=? and tag='Mime'";
    # my $q = "select file from file where md5=? ";
    my $ph=$dh->prepare_cached($q);

    $ph->execute($hash);


    #my $fn = $dh->selectcol_arrayref( $q, undef, $hash );


    while( my $ra = $ph->fetchrow_hashref ) {
	next unless -r $ra->{"file"};
	$ph->finish();
	return $ra  if $type eq "raw"; # shortcut

	# Not raw - 
	return converter($type,$ra);
    }
    return {};
    die "DB outdated";
}
sub converter
{
	my ($totype,$ra)=@_;
	my $cv = {
		"raw" => sub { return $ra; },
		"pdf" => \&get_bestpdf,
		"ico" => \&get_icon,

	};
	my $c=$cv->{$totype};
	return   { file=>"icon/Keys-icon.png" } unless $c;
	return &$c($ra);
}
sub get_bestpdf
{
	my ($ra)=shift;

	my ($name,$path,$suffix) = fileparse($ra->{file},qw{ocr.pdf pdf});
	foreach( $path.$name."ocr.pdf",$path.$name.$suffix ) {
		return {file => $_} if -r $_;
	}
	return  { file=>"public/icon/Keys-icon.png" };
}
 sub get_icon{ 
	 my $ra=shift;
	 return  { file=>"public/icon/Keys-icon.png" };
 }



#
# Return hash of meta(s)
# input either hash or idxY
#
sub getMeta {
	my ($self,$hash,$tag) = @_;
	my $meta={ content => "No content yet" };
	return $meta;
}
	
1;
