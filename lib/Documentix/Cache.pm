package Documentix::Cache;

use DBI qw(:sql_types);
use Documentix::db;
print STDERR ">>> cache.pm\n" if $Documentix::config->{debug} > 2;


sub new {
    my $class  = shift;

    my $dh = $Documentix::db::cachedh;
    my $self = bless { dh => $dh, dbname => $d_name }, $class;

    $self->setup_db();
    setup_db($self);
    return $self;
}

sub setup_db {
    my $self = shift;
    my $dh   = $self->{"dh"};

    $dh->sqlite_busy_timeout(10000);
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
}

sub get_cache {
    my ( $self, $item, $idx, $callback,$p1,$fromtype ) = @_;
    my $ref = "$idx";
    $self->{"fetch"}->execute($ref);
    my $q = $self->{"fetch"}->fetch;

    my ( $type, $data ) = $callback->( $p1,$item, $idx, @$q[0],$fromtype );
    return ( @$q[1], @$q[2] ) if @$q[2] && !$data;
    return ( "text/text", "ERROR" ) unless $data;

    my $ins_d = $self->{dh}->prepare_cached(
        "insert or replace into cache (ref,date,type,data) values(?,?,?,?)");
      
    my $date = time();
    $ins_d->bind_param( 1, $ref );
    $ins_d->bind_param( 2, $date, SQL_INTEGER );
    $ins_d->bind_param( 3, $type );
    $ins_d->bind_param( 4, $data, SQL_BLOB );
    $ins_d->execute;
    return ( $type, $data );
}

sub rm_cache {
 my ($self, $md5 ) = @_;
 $self->{"dh"}->do(q{delete from cache  where ref like ?},undef,"$md5%");
}
1;
