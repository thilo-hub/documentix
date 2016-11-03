package cache;

use parent DBI;
use DBI qw(:sql_types);
print STDERR ">>> cache.pm\n";

my $db_con;

sub new {
    my $dbn    = "SQLite";
    my $d_name = "/tmp/ncache.db";
    my $user   = "";
    my $pass   = "";
    my $class  = shift;
    return $db_con if $db_con;
    my $dh = DBI->connect( "dbi:$dbn:$d_name", $user, $pass )
      || die "Err database connection $!";
    print STDERR "New db conn: $dh\n";
    my $self = bless { dh => $dh, dbname => $d_name }, $class;
    # $self->{"setup_db"} = \&setup_db;
    $self->setup_db();
    $self->{"dh1"} = $dh;
    setup_db($self);
    $db_con = $self;
    return $self;
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
q{create table if not exists cache (type text,item text,idx integer,data blob,date integer, unique (item,idx))},
);
    foreach (@slist) {

        #print STDERR "DO: $_\n";
        $dh->do($_);
    }

}
sub get_cache {
    my ( $self, $item, $idx, $callback ) = @_;
    my $dh = $self->{"dh1"};
    my $q  = $dh->selectrow_arrayref(
        "select data,date,type from cache where item=? and idx=?",
        undef, $item, $idx );

    my ( $type, $data ) = $callback->( $item, $idx, @$q[1] );
    return ( @$q[2], @$q[0] ) if @$q[0] && !$data;
    return ( "text/text", "ERROR" ) unless $data;
    $dh->do("begin exclusive transaction");
    my $ins_d = $dh->prepare(
	q{insert or replace into cache (date,item,idx,data,type) values(?,?,?,?,?)}
    );
    my $date = time();
    $ins_d->bind_param( 1, $date, SQL_INTEGER );
    $ins_d->bind_param( 2, $item );
    $ins_d->bind_param( 3, $idx );
    $ins_d->bind_param( 4, $data, SQL_BLOB );
    $ins_d->bind_param( 5, $type );
    $ins_d->execute;
    $dh->do("commit");
    return ( $type, $data );
}

1;
