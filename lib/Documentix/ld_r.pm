package ld_r;

use strict;
use warnings;
use Cwd 'abs_path';
use POSIX;
use JSON;
use Sys::Hostname;
use Date::Parse;
use Encode qw{encode decode};
use Documentix::db;;
use Documentix::search;

print STDERR ">>> ld_r.pm\n" if $Documentix::config->{debug} > 2;

my $entries = $Documentix::config->{results_per_page};
#How many tags are shown 
my $maxtags=60;

my $myhost = hostname();

my $ANY = "*ANY*";

sub new {
    my $class  = shift;

    my $self = {};
    $self->{pd} = pdfidx->new(0,$Documentix::config);
    $self->{dh} = Documentix::db::dh;
    return bless $self, $class;
}

sub setup_db {
    my $dh = shift;
    $dh->do(
q{ create table if not exists cache_lst ( qidx integer primary key autoincrement,
			query text unique, nresults integer, last_used integer )}
    );
    $dh->do(
q{ create table if not exists cache_q ( qidx integer, idx integer, cast(snippet as text) text, unique(qidx,idx))}
    );

    $dh->do(
        q{
		CREATE TRIGGER if not exists cache_del before delete on cache_lst begin delete
			from cache_q where cache_q.qidx = old.qidx ;
		end;
		}
    );
}

# qidx,idx,rowid,snippet from cache_q_tmp
sub ldres {
    my $self = shift;
    my $dh   = $self->{"dh"};

    my ( $class, $idx0, $ppage, $search ) = @_;
    $search =~ s/\s+$// if defined($search);
    $search =~ s/^\s+// if defined($search);

    my ( $hd, $res ) = ( "", "" );

    undef $search if $search && $search =~ /^\s*$/;
    $idx0  = 1        unless $idx0;
    $ppage = $entries unless $ppage;

    $class =~ s/:\d+$// if $class;
    undef $class if defined($class) && $class eq $ANY;

    # search results are in cache_q(idx)
    my $idx = search( $search );

    #Filter tags & dates
    my $subsel = "";


    my ( $classes, $ndata, $get_res );
    my @sargs=();
    if ($idx) {
	# its a search result
	#
	#TODO: remove "deleted" tags
	#Maybe: an entry w/o tag would not show w/o the left join
	# TODO: check if order by date is better than order by rank
	# $get_res=qq{ select fileinfo.*,snippet  from cache_q natural join fileinfo where qidx=? order by cast(mtime as int) desc limit ? offset ? };
	$get_res=qq{ select *  from cache_q natural join hash natural join ftime natural join pdfinfo where qidx=? };
        push @sargs,$idx;

	# TODO: only if idx=0 first page
	# get tags in result set
	$ndata = qq{select nresults from cache_lst where qidx=?};
    $ndata   = $dh->prepare_cached($ndata);
    $ndata -> execute($idx);

	if ($idx0 eq 1){
	    $classes=q{select tagname,count(*) count  from tags natural join tagname where idx in (select idx  from cache_q where qidx=?) group by tagid order by count desc limit ?};
	    my $sel_t=$dh->prepare_cached($classes);
	    $sel_t->execute($idx,$maxtags);
	    $classes = $sel_t->fetchall_arrayref({});
	}
	#
	# get display list
    }
    else {
	# Return all
	$get_res=qq{ select *,cast(Content as text) snippet  from hash natural join Content natural join ftime natural join pdfinfo};


	if ($idx0 eq 1){
	    $classes = qq{ select tagname,count(*) count from $subsel tags natural join tagname group by tagid order by 2 desc limit ?};
	    print STDERR "Classes:  $classes\n";
	    my $sel_t=$dh->prepare_cached($classes);
	    $sel_t->execute($maxtags);
	    $classes = $sel_t->fetchall_arrayref({});
	}
	$ndata = qq{ select count(*) from $subsel hash };
    $ndata   = $dh->prepare_cached($ndata);
    $ndata -> execute();
    }
    $get_res .= " order by cast(mtime as int) desc";
    # class list
    if ( $class ) {
       $get_res =~ s/from/from (select idx  from tagname natural join tags where tagname = ? limit ? offset ?) natural join/;
       unshift @sargs,$class;
    } else {
	$get_res .= " limit ? offset ?";
    }

    # Assemble final query
    push @sargs,$ppage,int($idx0-1);

    $get_res=qq{ select idx,md5,mtime dt,pdfinfo,cast(file as blob) file,tags,cast(snippet as text) snippet  from ($get_res) natural left join taglist natural left join file group by idx order by dt desc };

    # total count
    # get number of results
    my $hh=$ndata;
    $ndata   = $hh->fetchrow_array();
    $hh->finish;

    #  Add selection of slice wanted

    $get_res = $dh->prepare_cached($get_res);
    $get_res->execute(@sargs);

    my $out = $get_res->fetchall_arrayref({});
    # Loop over query results and create hash to be returned
    foreach ( @$out ) {
	if ( my $mpdf = $_->{"pdfinfo"} ){
		$_->{sz}= conv_size($1) if $mpdf =~ /File size\s*<\/td><td>\s*(\d+)/;
		$_->{pg}= $1 if $mpdf =~ /Pages\s*<\/td><td>\s*(\d+)\s*<\/td>/;
		# $_->{dt}= str2time($1) if ( $mpdf =~ /CreationDate\s*<\/td><td>\s*(.*?)\s*<\/td>/) unless $_->{dt};
		delete $_->{"pdfinfo"};
	}
	$_->{dt} = pr_time($_->{dt});
	my $f=$_->{file}; delete $_->{file};
	next unless $f;
	$f =~ s|^.*/||;
	$f =~ s|\.([^\.]*)$||;
	$_->{doct} = $1;
	utf8::decode($f);
	$_->{doc}  = $f;
	$_->{doc}  =~ s/%20/ /g;
	$_->{doc}  =~ s/%2F/\//g; #Not sure if best. The filename uses %xx and the doc-name is then problematic?

	$_->{tip} = $_->{snippet}; delete $_->{"snippet"};
	$_->{tip} =~ s/["']/&quot;/g;
	$_->{tip} =~ s/\n/<br>/g;
	$_->{tg} = $_->{tags}|| ""; delete $_->{"tags"};
    }
    my $msg = "results: $ndata<br>";
    $msg .= "qidx: $idx<br>" if $idx;
    my $m = {
	nresults => int($ndata),                        # max number of items
	idx      => int($idx0),                         # first item in response
	pageno   => int( ( $idx0 - 1 ) / $ppage ) + 1,
	nitems   => int($ppage),

	# dates => $dater,
	query => $search,

	classes => $classes,
	msg     => $msg,
	items   => $out,
    };
    return $m;
    $out = JSON->new->pretty->encode($m);

    return $out;
}

sub reocr
{
	my ($self,$app,$md5)=@_;
	$DB::single = 1;
	my $doclib=$self->{pd};
	my $fn=$doclib->pdf_filename($md5);
	return $doclib->pdf_totext($fn,$md5,$app->minion);
}

sub conv_size
{

    my $s=shift;
    return sprintf("%.1f Gb",$s/2**30) if $s > 2**30;
    return sprintf("%.1f Mb",$s/2**20) if $s > 2**20;
    return sprintf("%.1f kb",$s/2**10);
}

#
# print formated short time string depending on how long ago
sub pr_time {
	my $t   = shift;
	$t=0 unless defined($t) && $t =~ /^\d+$/;
	my $dt = time() - $t;
	my @str = ( "%a %H:%M",  "last %a",         "%b-%d",             "%b %Y" );
	my @off = ( 24 * 60 * 60, 7 * 24 * 60 * 60, 180 * 24 * 60 * 60 );
	foreach (@off) {
		last if $dt < $_;
		shift @str;
	}
	return strftime( $str[0], localtime($t) );
}

1;
