package dbaccess;
use XMLRPC::Lite;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
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
sub getFilePath {
	my ( $self,$hash,$type ) = @_;

    my $dh    = $self->{"dh"};
    die "Bad input"  unless $hash =~ m/^[0-9a-f]{32}$/;

    my $q = "select file from file where md5=?";
    my $ph=$dh->prepare_cached($q);

    $ph->execute($hash);


    #my $fn = $dh->selectcol_arrayref( $q, undef, $hash );


    while( my $ra = $ph->fetchrow_arrayref ) {
	next unless -r $$ra[0];
	$ph->finish();
	return { file => $$ra[0]}  if $type eq "raw";

	# Not raw - 
	if ( $type eq "pdf" ) {
	}
    }
    return {};
    die "DB outdated";
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
