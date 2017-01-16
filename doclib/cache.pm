package cache;

use parent DBI;
use DBI qw(:sql_types);
print STDERR ">>> cache.pm\n" if $Docconf::config->{debug} > 2;

my $db_con;

sub new {
    my $dbn    = $Docconf::config->{cache_db_provider};
    my $d_name = $Docconf::config->{cache_db};
    my $user   = $Docconf::config->{cache_db_user};
    my $pass   = $Docconf::config->{cache_db_pass};
    my $class  = shift;

    # return $db_con if $db_con;
    my $dh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass )
      || die "Err database connection $!";
    print STDERR "New cache conn: $dh\n" if $Docconf::config->{debug} > 0;
    my $self = bless { dh => $dh, dbname => $d_name }, $class;

    # $self->{"setup_db"} = \&setup_db;
    $self->setup_db();
    setup_db($self);
    $db_con = $self;
    return $self;
}

sub setup_db {
    my $self = shift;
    my $dh   = $self->{"dh"};

    $dh->sqlite_busy_timeout(60000);
    my @slist = (
q{create table if not exists cache (ref primary key unique,date,type text,data blob)},
        q{pragma journal_mode=wal},
    );
    foreach (@slist) {

        #print STDERR "DO: $_\n";
        $dh->do($_) or die "Failed:$_";
    }
    $self->{"fetch"} =
      $self->{dh}->prepare("select date,type,data from cache where ref=?")
      or die "Fail";
    $self->{"put"} =
      $self->{dh}->prepare(
        "insert or replace into cache (ref,date,type,data) values(?,?,?,?)")
      or die "Fail";
}

sub get_cache {
    my ( $self, $item, $idx, $callback ) = @_;
    my $ref = "$idx-$item";
    $self->{"fetch"}->execute($ref);
    my $q = $self->{"fetch"}->fetch;

    my ( $type, $data ) = $callback->( $item, $idx, @$q[0] );
    return ( @$q[1], @$q[2] ) if @$q[2] && !$data;
    return ( "text/text", "ERROR" ) unless $data;

    my $ins_d = $self->{"put"};

    my $date = time();
    $ins_d->bind_param( 1, $ref );
    $ins_d->bind_param( 2, $date, SQL_INTEGER );
    $ins_d->bind_param( 3, $type );
    $ins_d->bind_param( 4, $data, SQL_BLOB );
    $ins_d->execute;
    return ( $type, $data );
}

1;
